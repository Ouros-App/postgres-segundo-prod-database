import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.apply_sql import (
    apply_sql_files,
    baseline_is_applied,
    expand_sql_secrets,
    load_config,
    sql_entries,
)


class FakeCursor:
    def __init__(self, rows, description=(("applied",),)):
        self.rows = rows
        self.description = description

    def execute(self, _query):
        return None

    def fetchmany(self, size):
        return self.rows[:size]


class MigrationCursor:
    """Minimal cursor double for migration skip-path tests."""

    def __init__(self, row=None):
        self.row = row
        self.description = (("checksum",),)

    def execute(self, _query, _params=None):
        return None

    def fetchone(self):
        return self.row


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
        """Keep the repository migration order synchronized with config.yaml."""
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
                ("atualiza_updated_at_analytics.sql", "on_change", False),
                ("analytics_sync_user.sql", "on_change", False),
                ("keycloak_user_link.sql", "on_change", False),
                ("ms_auth_service.sql", "on_change", False),
                ("triggers_logs.sql", "on_change", False),
                ("atualiza_lots_farm-owners.sql", "on_change", False),
                ("atualiza_farms-chicken-left.sql", "on_change", False),
                ("dataload_inicial.sql", "once", True),
                ("atualiza_consumo_mensal.sql", "on_change", False),
                ("views_galinhas_consumo.sql", "on_change", False),
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

    def test_expand_sql_secrets_quotes_literals_with_active_cursor(self) -> None:
        """Delegate SQL literal quoting to psycopg2 using the active cursor."""
        cursor = object()
        os.environ["TEST_SQL_SECRET"] = "it's-safe"
        with patch("scripts.apply_sql.sql.Literal") as literal:
            literal.return_value.as_string.return_value = "'it''s-safe'"
            self.assertEqual(
                expand_sql_secrets("PASSWORD ${TEST_SQL_SECRET};", cursor),
                "PASSWORD 'it''s-safe';",
            )
            literal.assert_called_once_with("it's-safe")
            literal.return_value.as_string.assert_called_once_with(cursor)

    def test_expand_sql_secrets_preserves_unicode_for_connection_quoting(self) -> None:
        """Pass Unicode secrets intact to connection-aware SQL adaptation."""
        cursor = object()
        os.environ["TEST_SQL_UNICODE_SECRET"] = "密碼🔒á"
        with patch("scripts.apply_sql.sql.Literal") as literal:
            literal.return_value.as_string.return_value = "'密碼🔒á'"
            self.assertEqual(
                expand_sql_secrets("PASSWORD ${TEST_SQL_UNICODE_SECRET};", cursor),
                "PASSWORD '密碼🔒á';",
            )
            literal.assert_called_once_with("密碼🔒á")
            literal.return_value.as_string.assert_called_once_with(cursor)

    def test_expand_sql_secrets_rejects_missing_values(self) -> None:
        """Reject unresolved SQL secret placeholders."""
        os.environ.pop("MISSING_SQL_SECRET", None)
        with self.assertRaisesRegex(RuntimeError, "MISSING_SQL_SECRET"):
            expand_sql_secrets("PASSWORD ${MISSING_SQL_SECRET};", object())

    def test_never_mode_skips_before_secret_expansion(self) -> None:
        """A disabled migration must not require secrets it will never consume."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "sql").mkdir()
            (root / "sql" / "skip.sql").write_text(
                "PASSWORD ${MISSING_SQL_SECRET};", encoding="utf-8"
            )
            cfg = {
                "database": {
                    "sql_path": "sql",
                    "execution_order": [{"file": "skip.sql", "mode": "never"}],
                }
            }
            os.environ.pop("MISSING_SQL_SECRET", None)
            with patch("scripts.apply_sql.expand_sql_secrets", side_effect=AssertionError):
                apply_sql_files(root, cfg, MigrationCursor(), "commit")

    def test_recorded_once_mode_skips_before_secret_expansion(self) -> None:
        """An already-recorded once migration must not resolve unused secrets."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "sql").mkdir()
            (root / "sql" / "once.sql").write_text(
                "PASSWORD ${MISSING_SQL_SECRET};", encoding="utf-8"
            )
            cfg = {
                "database": {
                    "sql_path": "sql",
                    "execution_order": [{"file": "once.sql", "mode": "once"}],
                }
            }
            os.environ.pop("MISSING_SQL_SECRET", None)
            with patch("scripts.apply_sql.expand_sql_secrets", side_effect=AssertionError):
                apply_sql_files(root, cfg, MigrationCursor(("stored-checksum",)), "commit")

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
