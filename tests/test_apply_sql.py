import os
import tempfile
import unittest
from pathlib import Path

from scripts.apply_sql import load_config, sql_entries


class ApplySqlTest(unittest.TestCase):
    def test_load_config_reads_sql_settings(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "config.yaml").write_text(
                "\n".join(
                    [
                        "database:",
                        "  host: ${POSTGRES_HOST}",
                        "  port: ${POSTGRES_PORT}",
                        "  name: ${POSTGRES_DB}",
                        "  bootstrap:",
                        "    db: ${POSTGRES_ROOT_DB}",
                        "    user: ${POSTGRES_ROOT_USER}",
                        "    password: ${POSTGRES_ROOT_PASSWORD}",
                        "  owner:",
                        "    user: ${POSTGRES_USER}",
                        "    password: ${POSTGRES_PASSWORD}",
                        "  sql_path: sql",
                        "  version_table: controle_versoes",
                        "  version_schema_file: versionamento.sql",
                        "  execution_order:",
                        "    - versionamento.sql",
                    ]
                ),
                encoding="utf-8",
            )
            os.environ.update(
                {
                    "POSTGRES_HOST": "localhost",
                    "POSTGRES_PORT": "5432",
                    "POSTGRES_DB": "app",
                    "POSTGRES_ROOT_DB": "root_db",
                    "POSTGRES_ROOT_USER": "ouros_root",
                    "POSTGRES_ROOT_PASSWORD": "root",
                    "POSTGRES_USER": "app",
                    "POSTGRES_PASSWORD": "app",
                }
            )
            cfg = load_config(root)
            self.assertEqual(cfg["database"]["sql_path"], "sql")
            self.assertEqual(cfg["database"]["version_schema_file"], "versionamento.sql")
            self.assertEqual(cfg["database"]["execution_order"], ["versionamento.sql"])

    def test_repository_config_executes_physical_schema(self) -> None:
        root = Path(__file__).resolve().parents[1]
        os.environ.update(
            {
                "POSTGRES_HOST": "localhost",
                "POSTGRES_PORT": "5432",
                "POSTGRES_DB": "app",
                "POSTGRES_ROOT_DB": "root_db",
                "POSTGRES_ROOT_USER": "ouros_root",
                "POSTGRES_ROOT_PASSWORD": "root",
                "POSTGRES_USER": "app",
                "POSTGRES_PASSWORD": "app",
            }
        )
        cfg = load_config(root)
        entries = sql_entries(root, cfg)
        self.assertEqual(
            [(path.name, mode) for path, mode in entries],
            [
                ("banco_ouros_fisico.sql", "on_change"),
                ("atualiza_lots_farm-owners.sql", "once"),
                ("dataload_inicial.sql", "on_change"),
                ("atualiza_password.sql", "once"),
                ("midas-user.sql", "on_change"),
            ],
        )

    def test_empty_execution_order_is_rejected(self) -> None:
        root = Path(__file__).resolve().parents[1]
        os.environ.update(
            {
                "POSTGRES_HOST": "localhost",
                "POSTGRES_PORT": "5432",
                "POSTGRES_DB": "app",
                "POSTGRES_ROOT_DB": "root_db",
                "POSTGRES_ROOT_USER": "ouros_root",
                "POSTGRES_ROOT_PASSWORD": "root",
                "POSTGRES_USER": "app",
                "POSTGRES_PASSWORD": "app",
            }
        )
        cfg = load_config(root)
        cfg["database"]["execution_order"] = []
        with self.assertRaisesRegex(RuntimeError, "Nenhum script SQL"):
            sql_entries(root, cfg)


if __name__ == "__main__":
    unittest.main()
