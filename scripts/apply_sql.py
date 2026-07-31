#!/usr/bin/env python3
import os
import re
import subprocess
from pathlib import Path

import psycopg2
import yaml
from dotenv import load_dotenv


ENV_RE = re.compile(r"\$\{([A-Z0-9_]+)\}")


def qident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def load_config(root: Path) -> dict:
    raw = (root / "config.yaml").read_text(encoding="utf-8")
    raw = ENV_RE.sub(lambda m: os.getenv(m.group(1), ""), raw)
    return yaml.safe_load(raw)


def git_value(root: Path, *args: str) -> str:
    res = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)
    return res.stdout.strip() if res.returncode == 0 else "unknown"


def connect(cfg: dict, dbname: str, user: str, password: str):
    db = cfg["database"]
    return psycopg2.connect(host=db["host"], port=db["port"], dbname=dbname, user=user, password=password)


def ensure_database(cfg: dict) -> None:
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
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db["name"],))
            if cur.fetchone() is None:
                cur.execute(f"CREATE DATABASE {qident(db['name'])} OWNER {qident(owner['user'])}")
    finally:
        conn.close()


def ensure_version_table(cur, root: Path, cfg: dict) -> None:
    db = cfg["database"]
    path = root / db["sql_path"] / db["version_schema_file"]
    if not path.is_file():
        raise FileNotFoundError(f"SQL de versionamento nao encontrado: {path}")
    cur.execute(path.read_text(encoding="utf-8"))


def next_version(cur, table: str) -> int:
    cur.execute(f"SELECT COALESCE(MAX(versao), 0) + 1 FROM {qident(table)}")
    return int(cur.fetchone()[0])


def apply_sql_files(root: Path, cfg: dict, cur) -> None:
    db = cfg["database"]
    sql_dir = root / db["sql_path"]
    for name in db["execution_order"]:
        path = sql_dir / name
        if not path.is_file():
            raise FileNotFoundError(f"SQL nao encontrado: {path}")
        cur.execute(path.read_text(encoding="utf-8"))


def main() -> None:
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
                apply_sql_files(root, cfg, cur)
                cur.execute(
                    f"INSERT INTO {qident(table)} (versao, commit_id, comentario_commit) VALUES (%s, %s, %s)",
                    (next_version(cur, table), commit_id, commit_msg),
                )
        print(f"SQL aplicado no banco {db['name']} e versao registrada para commit {commit_id}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
