#!/usr/bin/env python3
import hashlib
import os
import re
import subprocess
from pathlib import Path

import psycopg2
import yaml
from dotenv import load_dotenv


ENV_RE = re.compile(r"\$\{([A-Z0-9_]+)\}")


def qident(name: str) -> str:
    """Quote a PostgreSQL identifier safely."""
    return '"' + name.replace('"', '""') + '"'


def load_config(root: Path) -> dict:
    """Load config.yaml and resolve required environment placeholders."""
    raw = (root / "config.yaml").read_text(encoding="utf-8")

    def replace(match):
        """Resolve one environment placeholder and reject blank values."""
        value = os.getenv(match.group(1))
        if value is None or not value.strip():
            raise RuntimeError(f"Variavel de ambiente obrigatoria ausente: {match.group(1)}")
        return value

    def expand(value):
        """Recursively expand environment placeholders in parsed YAML values."""
        if isinstance(value, str):
            return ENV_RE.sub(replace, value)
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        return value

    return expand(yaml.safe_load(raw))


def git_value(root: Path, *args: str) -> str:
    """Run a Git command and return its output or 'unknown' on failure."""
    res = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)
    return res.stdout.strip() if res.returncode == 0 else "unknown"


def connect(cfg: dict, dbname: str, user: str, password: str):
    """Open a PostgreSQL connection using the repository configuration."""
    db = cfg["database"]
    return psycopg2.connect(host=db["host"], port=db["port"], dbname=dbname, user=user, password=password)


def ensure_database(cfg: dict) -> None:
    """Create the application role and database when they do not exist."""
    db = cfg["database"]
    boot = db["bootstrap"]
    owner = db["owner"]
    conn = connect(cfg, boot["db"], boot["user"], boot["password"])
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (owner["user"],))
            if cur.fetchone() is None:
                cur.execute(f"CREATE ROLE {qident(owner['user'])} LOGIN PASSWORD %s", (owner["password"],))
                print("[CREATE] usuario proprietário")
            else:
                print("[SKIP] usuario proprietário: já existe")

            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db["name"],))
            if cur.fetchone() is None:
                cur.execute(f"CREATE DATABASE {qident(db['name'])} OWNER {qident(owner['user'])}")
                print("[CREATE] banco de dados")
            else:
                print("[SKIP] banco de dados: já existe")
    finally:
        conn.close()


def ensure_version_table(cur, root: Path, cfg: dict) -> None:
    """Execute the versioning schema required by the SQL runner."""
    db = cfg["database"]
    path = root / db["sql_path"] / db["version_schema_file"]
    if not path.is_file():
        raise FileNotFoundError(f"SQL de versionamento nao encontrado: {path}")
    cur.execute(path.read_text(encoding="utf-8"))


def sql_entries(root: Path, cfg: dict) -> list[tuple[Path, str, str | None]]:
    """Validate configured SQL entries and return path, mode, and baseline query."""
    db = cfg["database"]
    sql_dir = root / db["sql_path"]
    if not db["execution_order"]:
        raise RuntimeError("Nenhum script SQL foi configurado em database.execution_order.")

    entries, seen = [], set()
    for item in db["execution_order"]:
        if isinstance(item, str):
            name, mode, baseline_query = item, "on_change", None
        elif isinstance(item, dict):
            name = item.get("file")
            mode = item.get("mode", "on_change")
            baseline_query = item.get("baseline_query")
        else:
            name, mode, baseline_query = None, None, None

        if not isinstance(name, str) or not name or mode not in {"always", "on_change", "once", "never"}:
            raise ValueError("Cada script exige file e mode valido (always, on_change, once ou never).")
        if baseline_query is not None and (mode != "once" or not isinstance(baseline_query, str) or not baseline_query.strip()):
            raise ValueError(f"baseline_query so pode ser usado em scripts mode once: {name}")

        path = Path(name)
        identity = path.as_posix()
        if path.is_absolute() or ".." in path.parts or path.suffix != ".sql" or identity in seen:
            raise ValueError(f"Script SQL invalido ou duplicado: {name}")
        seen.add(identity)
        path = sql_dir / path
        if not path.is_file():
            raise FileNotFoundError(f"SQL nao encontrado: {path}")
        entries.append((path, mode, baseline_query))
    return entries


def record_script(cur, identity: str, checksum: str, commit_id: str) -> None:
    """Persist or refresh the execution record for one SQL script."""
    cur.execute(
        "INSERT INTO controle_scripts_sql (arquivo, checksum, commit_id) "
        "VALUES (%s, %s, %s) ON CONFLICT (arquivo) DO UPDATE SET "
        "checksum = EXCLUDED.checksum, commit_id = EXCLUDED.commit_id, executado_em = NOW()",
        (identity, checksum, commit_id),
    )


def baseline_is_applied(cur, baseline_query: str, identity: str) -> bool:
    """Run a baseline query and require exactly one PostgreSQL boolean result."""
    cur.execute(baseline_query)
    baseline = cur.fetchone()
    column_count = len(cur.description or ())
    if baseline is None or column_count != 1 or len(baseline) != 1 or not isinstance(baseline[0], bool):
        raise RuntimeError(
            f"baseline_query invalida para {identity}: esperado exatamente uma coluna BOOLEAN"
        )
    return baseline[0] is True


def apply_sql_files(root: Path, cfg: dict, cur, commit_id: str) -> None:
    """Apply configured SQL files according to mode, checksum, and baseline state."""
    cur.execute("SELECT pg_advisory_xact_lock(84729341)")
    cur.execute("CREATE TABLE IF NOT EXISTS controle_scripts_sql ("
                "arquivo TEXT PRIMARY KEY, checksum VARCHAR(64) NOT NULL, "
                "commit_id VARCHAR(64) NOT NULL, executado_em TIMESTAMPTZ NOT NULL DEFAULT NOW())")

    for path, mode, baseline_query in sql_entries(root, cfg):
        identity = path.relative_to(root / cfg["database"]["sql_path"]).as_posix()
        content = path.read_text(encoding="utf-8")
        checksum = hashlib.sha256(content.encode("utf-8")).hexdigest()

        if mode == "never":
            print(f"[SKIP] {identity}: modo never")
            continue

        cur.execute("SELECT checksum FROM controle_scripts_sql WHERE arquivo = %s", (identity,))
        row = cur.fetchone()

        if mode == "once" and row:
            print(f"[SKIP] {identity}: modo once")
            continue

        if mode == "once" and not row and baseline_query:
            if baseline_is_applied(cur, baseline_query, identity):
                print(f"[BASELINE] {identity}: dados existentes detectados; registrando sem reexecutar")
                record_script(cur, identity, checksum, commit_id)
                continue

        if mode == "on_change" and row and row[0] == checksum:
            print(f"[SKIP] {identity}: sem alteracoes")
            continue

        reason = "modo always" if mode == "always" else "modo once" if mode == "once" else "arquivo novo" if not row else "conteudo alterado"
        print(f"[RUN] {identity}: {reason}")
        cur.execute(content)
        record_script(cur, identity, checksum, commit_id)


def main() -> None:
    """Bootstrap the database, apply SQL entries, and record the repository commit."""
    root = Path(__file__).resolve().parents[1]
    load_dotenv(root / ".env")
    cfg = load_config(root)
    db = cfg["database"]
    table = db["version_table"]
    commit_id = os.getenv("GITHUB_SHA") or git_value(root, "rev-parse", "HEAD")
    commit_msg = os.getenv("GITHUB_COMMIT_MESSAGE") or git_value(root, "log", "-1", "--pretty=%B")
    if commit_id == "unknown":
        raise RuntimeError("Nao foi possivel identificar o commit atual.")
    ensure_database(cfg)
    conn = connect(cfg, db["name"], db["owner"]["user"], db["owner"]["password"])
    try:
        with conn:
            with conn.cursor() as cur:
                ensure_version_table(cur, root, cfg)
                apply_sql_files(root, cfg, cur, commit_id)
                cur.execute(
                    f"INSERT INTO {qident(table)} (commit_id, comentario_commit) VALUES (%s, %s)",
                    (commit_id, commit_msg),
                )
        print(f"SQL aplicado no banco {db['name']} e versao registrada para commit {commit_id}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
