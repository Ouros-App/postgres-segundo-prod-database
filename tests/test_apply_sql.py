import os
import re
import tempfile
import unittest
from pathlib import Path

from scripts.apply_sql import baseline_is_applied, load_config, sql_entries


class FakeCursor:
    def __init__(self, rows, description=(("applied",),)):
        self.rows = rows
        self.description = description

    def execute(self, _query):
        return None

    def fetchmany(self, size):
        return self.rows[:size]


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
            [(path.name, mode, baseline_query is not None) for path, mode, baseline_query in entries],
            [
                ("banco_ouros_fisico.sql", "on_change", False),
                ("atualiza_lots_farm-owners.sql", "once", False),
                ("dataload_inicial.sql", "once", True),
                ("dataload_lots_farm-owners.sql", "once", False),
                ("atualiza_password.sql", "once", False),
                ("midas-user.sql", "on_change", False),
                ("midas-resource-import.sql", "on_change", False),
            ],
        )
        dataload_baseline = next(
            baseline_query
            for path, _mode, baseline_query in entries
            if path.name == "dataload_inicial.sql"
        )
        expected_documents = {f"200000000{i:02d}" for i in range(1, 21)}
        actual_documents = set(re.findall(r"'((?:200000000)\d{2})'", dataload_baseline))
        self.assertEqual(actual_documents, expected_documents)

    def test_baseline_requires_exactly_one_boolean_row(self) -> None:
        self.assertTrue(baseline_is_applied(FakeCursor([(True,)]), "SELECT TRUE", "seed.sql"))
        self.assertFalse(baseline_is_applied(FakeCursor([(False,)]), "SELECT FALSE", "seed.sql"))

        invalid_cursors = [
            FakeCursor([]),
            FakeCursor([(True,), (False,)]),
            FakeCursor([("true",)]),
            FakeCursor([(True, False)], description=(("a",), ("b",))),
            FakeCursor([], description=None),
        ]
        for cursor in invalid_cursors:
            with self.subTest(rows=cursor.rows, description=cursor.description):
                with self.assertRaises(RuntimeError):
                    baseline_is_applied(cursor, "SELECT ...", "seed.sql")

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
