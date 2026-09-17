#!/usr/bin/env python3
import hashlib
import os
import re
import subprocess
from pathlib import Path

import psycopg2
from psycopg2 import sql
import yaml
from dotenv import load_dotenv


ENV_RE = re.compile(r"\$\{([A-Z0-9_]+)\}")
SQL_BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
SQL_LINE_COMMENT_RE = re.compile(r"--[^\n]*")
UNSAFE_SQL_PATTERNS = (
    ("UPDATE", re.compile(r"\bUPDATE\s+(?:ONLY\s+)?\S+(?:\s+AS\s+\S+)?\s+SET\b", re.IGNORECASE)),
    ("DELETE", re.compile(r"\bDELETE\s+FROM\b", re.IGNORECASE)),
    ("TRUNCATE", re.compile(r"\bTRUNCATE\b", re.IGNORECASE)),
    ("MERGE", re.compile(r"\bMERGE\s+INTO\b", re.IGNORECASE)),
    ("UPSERT UPDATE", re.compile(r"\bON\s+CONFLICT\b[\s\S]*?\bDO\s+UPDATE\b", re.IGNORECASE)),
    ("DROP DATA OBJECT", re.compile(r"\bDROP\s+(?:DATABASE|SCHEMA|TABLE|VIEW)\b", re.IGNORECASE)),
    ("DROP COLUMN", re.compile(r"\bDROP\s+COLUMN\b", re.IGNORECASE)),
)
CORE_TABLES = (
    "addresses",
    "enterprises",
    "farms",
    "farm_owners",
    "company_employees",
    "water_registries",
    "energy_registries",
    "lots",
)


def qident(name: str) -> str:
    """Quote a PostgreSQL identifier safely."""
    return '"' + name.replace('"', '""') + '"'


def strip_sql_comments(content: str) -> str:
    """Remove SQL comments before applying the automatic-migration safety policy."""
    content = SQL_BLOCK_COMMENT_RE.sub(" ", content)
    return SQL_LINE_COMMENT_RE.sub(" ", content)


def assert_safe_sql(content: str, identity: str) -> None:
    """Reject automatic SQL that can overwrite or delete application data."""
    checked = strip_sql_comments(content)
    for label, pattern in UNSAFE_SQL_PATTERNS:
        if pattern.search(checked):
            raise RuntimeError(
                f"SQL inseguro bloqueado em {identity}: {label}. "
                "Migrations automaticas devem ser aditivas e preservar dados de usuarios."
            )


def assert_safe_baseline_query(query: str, identity: str) -> None:
    """Baseline checks are read-only SELECT statements."""
    checked = strip_sql_comments(query).strip()
    if not re.match(r"^SELECT\b", checked, flags=re.IGNORECASE):
        raise RuntimeError(f"baseline_query de {identity} deve ser SELECT read-only")
    assert_safe_sql(checked, f"baseline_query:{identity}")


def configure_transaction_safety(cur) -> None:
    """Prefer a failed deploy over long locks that make the application unavailable."""
    cur.execute("SET LOCAL lock_timeout = '5s'")
    cur.execute("SET LOCAL statement_timeout = '120s'")
    cur.execute("SET LOCAL idle_in_transaction_session_timeout = '60s'")


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


def expand_sql_secrets(content: str, cur) -> str:
    """Expand SQL placeholders as literals prepared with the active connection."""
    def replace(match):
        """Resolve one SQL placeholder as a connection-aware quoted literal."""
        name = match.group(1)
        value = os.getenv(name)
        if value is None:
            raise RuntimeError(f"Variavel de ambiente obrigatoria ausente no SQL: {name}")
        return sql.Literal(value).as_string(cur)

    return ENV_RE.sub(replace, content)


def git_value(root: Path, *args: str) -> str:
    """Run a Git command and return its output or 'unknown' on failure."""
    res = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)
    return res.stdout.strip() if res.returncode == 0 else "unknown"


def connect(cfg: dict, dbname: str, user: str, password: str):
    """Open a PostgreSQL connection using the repository configuration."""
    db = cfg["database"]
    return psycopg2.connect(host=db["host"], port=db["port"], dbname=dbname, user=user, password=password)


def configure_service_role(
    cur,
    db_name: str,
    role_name: str,
    connection_limit: int,
    password: str | None = None,
    search_path: str = "public, pg_catalog",
    login: bool | None = True,
) -> None:
    """Create and harden a service role without requiring bootstrap SUPERUSER."""
    role = qident(role_name)
    cur.execute(
        "SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls "
        "FROM pg_roles WHERE rolname = %s",
        (role_name,),
    )
    role_state = cur.fetchone()
    if role_state is None:
        cur.execute(f"CREATE ROLE {role} NOLOGIN")
        print(f"[CREATE] role de servico {role_name}")
    elif any(role_state):
        raise RuntimeError(
            f"Role de servico {role_name} possui privilegios administrativos; "
            "recusando alterar automaticamente sem SUPERUSER"
        )

    login_clause = "LOGIN " if login is True else "NOLOGIN " if login is False else ""
    cur.execute(
        f"ALTER ROLE {role} {login_clause}NOINHERIT NOCREATEDB "
        f"NOCREATEROLE CONNECTION LIMIT {connection_limit}"
    )
    if password:
        cur.execute(f"ALTER ROLE {role} PASSWORD %s", (password,))

    cur.execute(
        "SELECT parent_role.rolname "
        "FROM pg_auth_members membership "
        "JOIN pg_roles parent_role ON parent_role.oid = membership.roleid "
        "JOIN pg_roles member_role ON member_role.oid = membership.member "
        "WHERE member_role.rolname = %s",
        (role_name,),
    )
    for (parent_role,) in cur.fetchall():
        cur.execute(f"REVOKE {qident(parent_role)} FROM {role}")

    cur.execute(f"REVOKE ALL PRIVILEGES ON DATABASE {qident(db_name)} FROM {role}")
    cur.execute(f"GRANT CONNECT ON DATABASE {qident(db_name)} TO {role}")
    cur.execute(f"ALTER ROLE {role} SET default_transaction_read_only = on")
    cur.execute(f"ALTER ROLE {role} SET search_path = {search_path}")


def ensure_database(cfg: dict) -> None:
    """Create the application database and provision privileged service roles."""
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

            configure_service_role(cur, db["name"], "analytics_sync_ro", 3)
            configure_service_role(
                cur,
                db["name"],
                "midas_ro",
                5,
                search_path="midas, pg_catalog",
            )
            configure_service_role(
                cur,
                db["name"],
                "midas_importer",
                5,
                search_path="midas, pg_catalog",
                login=False,
            )

            auth_password = os.getenv("MS_AUTH_SERVICE_PASSWORD")
            configure_service_role(
                cur,
                db["name"],
                "ms_auth_service_ro",
                5,
                auth_password,
                login=True if auth_password else None,
            )
            if not auth_password:
                print(
                    "[WARN] MS_AUTH_SERVICE_PASSWORD ausente; "
                    "estado de login existente preservado (role novo permanece NOLOGIN)"
                )
    finally:
        conn.close()


def ensure_version_table(cur, root: Path, cfg: dict) -> None:
    """Execute the versioning schema required by the SQL runner."""
    db = cfg["database"]
    path = root / db["sql_path"] / db["version_schema_file"]
    if not path.is_file():
        raise FileNotFoundError(f"SQL de versionamento nao encontrado: {path}")
    content = path.read_text(encoding="utf-8")
    assert_safe_sql(content, db["version_schema_file"])
    cur.execute(content)


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
    """Run a read-only baseline query and require one boolean result."""
    assert_safe_baseline_query(baseline_query, identity)
    cur.execute(baseline_query)
    if cur.description is None:
        raise RuntimeError(
            f"baseline_query invalida para {identity}: esperado um result set BOOLEAN"
        )

    rows = cur.fetchmany(2)
    if len(rows) != 1:
        raise RuntimeError(
            f"baseline_query invalida para {identity}: esperado exatamente uma linha"
        )

    baseline = rows[0]
    if len(cur.description) != 1 or len(baseline) != 1 or not isinstance(baseline[0], bool):
        raise RuntimeError(
            f"baseline_query invalida para {identity}: esperado exatamente uma coluna BOOLEAN"
        )
    return baseline[0] is True


def validate_core_schema(cur) -> None:
    """Refuse to commit a migration batch if an application table disappeared."""
    missing = []
    for table in CORE_TABLES:
        cur.execute("SELECT to_regclass(%s)", (f"public.{table}",))
        if cur.fetchone()[0] is None:
            missing.append(table)
    if missing:
        raise RuntimeError(f"Schema invalido apos migrations; tabelas ausentes: {', '.join(missing)}")


def apply_sql_files(root: Path, cfg: dict, cur, commit_id: str) -> None:
    """Apply configured SQL files according to mode, checksum, and baseline state."""
    cur.execute("SELECT pg_advisory_xact_lock(84729341)")
    cur.execute("CREATE TABLE IF NOT EXISTS controle_scripts_sql ("
                "arquivo TEXT PRIMARY KEY, checksum VARCHAR(64) NOT NULL, "
                "commit_id VARCHAR(64) NOT NULL, executado_em TIMESTAMPTZ NOT NULL DEFAULT NOW())")

    for path, mode, baseline_query in sql_entries(root, cfg):
        identity = path.relative_to(root / cfg["database"]["sql_path"]).as_posix()

        if mode == "never":
            print(f"[SKIP] {identity}: modo never")
            continue

        cur.execute("SELECT checksum FROM controle_scripts_sql WHERE arquivo = %s", (identity,))
        row = cur.fetchone()

        if mode == "once" and row and not baseline_query:
            print(f"[SKIP] {identity}: modo once")
            continue

        raw_content = path.read_text(encoding="utf-8")
        assert_safe_sql(raw_content, identity)

        if mode == "once" and baseline_query:
            if baseline_is_applied(cur, baseline_query, identity):
                checksum = hashlib.sha256(raw_content.encode("utf-8")).hexdigest()
                print(f"[BASELINE] {identity}: dados existentes detectados; registrando sem reexecutar")
                record_script(cur, identity, checksum, commit_id)
                continue
            if row:
                print(f"[RECOVER] {identity}: historico existe, mas baseline esta ausente; reexecutando com banco vazio")

        content = expand_sql_secrets(raw_content, cur)
        checksum = hashlib.sha256(content.encode("utf-8")).hexdigest()

        if mode == "on_change" and row and row[0] == checksum:
            print(f"[SKIP] {identity}: sem alteracoes")
            continue

        reason = (
            "recuperacao de baseline"
            if mode == "once" and baseline_query and row
            else "modo always"
            if mode == "always"
            else "modo once"
            if mode == "once"
            else "arquivo novo"
            if not row
            else "conteudo alterado"
        )
        print(f"[RUN] {identity}: {reason}")
        cur.execute(content)
        record_script(cur, identity, checksum, commit_id)


def main() -> None:
    """Bootstrap the database, atomically apply safe SQL, and record the commit."""
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
                configure_transaction_safety(cur)
                ensure_version_table(cur, root, cfg)
                apply_sql_files(root, cfg, cur, commit_id)
                validate_core_schema(cur)
                cur.execute(
                    f"INSERT INTO {qident(table)} (commit_id, comentario_commit) VALUES (%s, %s)",
                    (commit_id, commit_msg),
                )
        print(f"SQL aplicado no banco {db['name']} e versao registrada para commit {commit_id}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
