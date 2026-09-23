import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.apply_sql import (
    apply_sql_files,
    assert_safe_baseline_query,
    assert_safe_sql,
    baseline_is_applied,
    configure_service_role,
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


class ServiceRoleCursor:
    """Cursor double for validating service-role hardening SQL."""

    def __init__(self, role_state=(False, False, False, False, False)):
        """Initialize the fake with the administrative flags of an existing role."""
        self.role_state = role_state
        self.last_query = ""
        self.executed = []

    def execute(self, query, params=None):
        """Record SQL commands instead of sending them to PostgreSQL."""
        self.last_query = query
        self.executed.append((query, params))

    def fetchone(self):
        """Return role flags for the pg_roles lookup."""
        if "SELECT rolsuper" in self.last_query:
            return self.role_state
        return None

    def fetchall(self):
        """Return no inherited role memberships by default."""
        return []


class ApplySqlTest(unittest.TestCase):
    def _set_env(self) -> None:
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
            self._set_env()
            cfg = load_config(root)
            self.assertEqual(cfg["database"]["sql_path"], "sql")
            self.assertEqual(cfg["database"]["version_schema_file"], "versionamento.sql")
            self.assertEqual(cfg["database"]["execution_order"], ["versionamento.sql"])

    def test_repository_config_uses_safe_execution_modes(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self._set_env()
        cfg = load_config(root)
        entries = sql_entries(root, cfg)
        self.assertEqual(
            [(path.name, mode, baseline_query is not None) for path, mode, baseline_query in entries],
            [
                ("banco_ouros_fisico.sql", "on_change", False),
                ("procedures_tips.sql", "on_change", False),
                ("reconcile_farm_owners_first_access.sql", "on_change", False),
                ("funcoes_consumo_metas.sql", "on_change", False),
                ("atualiza_updated_at_analytics.sql", "on_change", False),
                ("analytics_sync_user.sql", "on_change", False),
                ("keycloak_user_link.sql", "on_change", False),
                ("ms_auth_service.sql", "on_change", False),
                ("triggers_logs.sql", "on_change", False),
                ("atualiza_lots_farm-owners.sql", "once", False),
                ("atualiza_farms-chicken-left.sql", "once", False),
                ("atualiza_farm-owners-campos-opcionais.sql", "once", False),
                ("dataload_inicial.sql", "once", True),
                ("atualiza_consumo_mensal.sql", "never", False),
                ("views_galinhas_consumo.sql", "on_change", False),
                ("dataload_lots_farm-owners.sql", "never", False),
                ("atualiza_password.sql", "once", False),
                ("midas-user.sql", "on_change", False),
                ("midas-resource-import.sql", "on_change", False),
            ],
        )

        legacy_mutating_modes = {
            path.name: mode
            for path, mode, _baseline in entries
            if path.name in {
                "atualiza_lots_farm-owners.sql",
                "atualiza_farms-chicken-left.sql",
                "atualiza_consumo_mensal.sql",
            }
        }
        self.assertTrue(all(mode in {"once", "never"} for mode in legacy_mutating_modes.values()))

    def test_seed_baseline_skips_when_application_data_exists(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self._set_env()
        cfg = load_config(root)
        entries = sql_entries(root, cfg)
        dataload_baseline = next(
            baseline_query
            for path, _mode, baseline_query in entries
            if path.name == "dataload_inicial.sql"
        )
        for table in (
            "addresses",
            "enterprises",
            "farms",
            "farm_owners",
            "company_employees",
            "adms",
        ):
            self.assertIn(f"FROM {table}", dataload_baseline)
        self.assertNotIn("20000000001", dataload_baseline)

    def test_all_automatic_repository_sql_is_non_destructive(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self._set_env()
        cfg = load_config(root)
        for path, mode, _baseline_query in sql_entries(root, cfg):
            if mode == "never":
                continue
            with self.subTest(path=path.name, mode=mode):
                assert_safe_sql(path.read_text(encoding="utf-8"), path.name)

    def test_first_access_repair_migration_is_safe_and_idempotent(self) -> None:
        """Keep the legacy typo repair eligible for automatic reconciliation."""
        root = Path(__file__).resolve().parents[1]
        content = (root / "sql" / "reconcile_farm_owners_first_access.sql").read_text(
            encoding="utf-8"
        )
        assert_safe_sql(content, "reconcile_farm_owners_first_access.sql")
        self.assertIn("RENAME COLUMN first_acess TO first_access", content)
        self.assertNotIn("DROP COLUMN", content)
        self.assertNotRegex(content, r"(?i)\bUPDATE\b")

    def test_destructive_automatic_sql_is_rejected(self) -> None:
        unsafe = [
            "UPDATE farms SET chickens_now = 0;",
            "DELETE FROM farms WHERE id = 1;",
            "TRUNCATE farms;",
            "MERGE INTO farms USING other ON TRUE WHEN MATCHED THEN DELETE;",
            "INSERT INTO farms(id) VALUES (1) ON CONFLICT (id) DO UPDATE SET name = 'x';",
            "DROP TABLE farms;",
            "DROP VIEW midas.lots;",
            "ALTER TABLE lots DROP COLUMN cost;",
        ]
        for statement in unsafe:
            with self.subTest(sql=statement):
                with self.assertRaisesRegex(RuntimeError, "SQL inseguro bloqueado"):
                    assert_safe_sql(statement, "unsafe.sql")

    def test_trigger_event_keywords_are_not_mistaken_for_update_statements(self) -> None:
        assert_safe_sql(
            "CREATE TRIGGER t AFTER INSERT OR UPDATE OR DELETE ON farms FOR EACH ROW EXECUTE FUNCTION f();",
            "trigger.sql",
        )

    def test_baseline_requires_select_only(self) -> None:
        assert_safe_baseline_query("SELECT EXISTS (SELECT 1 FROM farms)", "seed.sql")
        with self.assertRaisesRegex(RuntimeError, "deve ser SELECT"):
            assert_safe_baseline_query("UPDATE farms SET chickens_now = 0", "seed.sql")

    def test_service_role_hardening_does_not_require_superuser(self) -> None:
        """Keep safe role hardening compatible with a non-superuser bootstrap."""
        cursor = ServiceRoleCursor()
        configure_service_role(cursor, "app", "analytics_sync_ro", 3)
        commands = "\n".join(query for query, _params in cursor.executed)
        self.assertIn("NOINHERIT", commands)
        self.assertIn("NOCREATEDB", commands)
        self.assertIn("NOCREATEROLE", commands)
        self.assertNotIn("NOSUPERUSER", commands)
        self.assertNotIn("NOREPLICATION", commands)
        self.assertNotIn("NOBYPASSRLS", commands)

    def test_service_role_rejects_existing_admin_privileges(self) -> None:
        """Fail closed instead of silently accepting an administrative service role."""
        cursor = ServiceRoleCursor((True, False, False, False, False))
        with self.assertRaisesRegex(RuntimeError, "privilegios administrativos"):
            configure_service_role(cursor, "app", "analytics_sync_ro", 3)

    def test_midas_role_uses_restricted_search_path(self) -> None:
        """Keep Midas service access constrained to the Midas views and pg_catalog."""
        cursor = ServiceRoleCursor()
        configure_service_role(
            cursor,
            "app",
            "midas_ro",
            5,
            search_path="midas, pg_catalog",
        )
        commands = "\n".join(query for query, _params in cursor.executed)
        self.assertIn("search_path = midas, pg_catalog", commands)

    def test_importer_role_remains_no_login(self) -> None:
        """Keep the importer as a group role that cannot authenticate directly."""
        cursor = ServiceRoleCursor()
        configure_service_role(
            cursor,
            "app",
            "midas_importer",
            5,
            search_path="midas, pg_catalog",
            login=False,
        )
        commands = "\n".join(query for query, _params in cursor.executed)
        self.assertIn("NOLOGIN", commands)

    def test_owner_migrations_do_not_manage_roles(self) -> None:
        """Keep role creation out of SQL executed by the application owner."""
        root = Path(__file__).resolve().parents[1]
        for name in ("midas-user.sql", "midas-resource-import.sql"):
            content = (root / "sql" / name).read_text(encoding="utf-8")
            with self.subTest(name=name):
                self.assertNotRegex(content, r"(?i)\b(?:CREATE|ALTER)\s+ROLE\b")

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
                    baseline_is_applied(cursor, "SELECT TRUE", "seed.sql")

    def test_empty_execution_order_is_rejected(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self._set_env()
        cfg = load_config(root)
        cfg["database"]["execution_order"] = []
        with self.assertRaisesRegex(RuntimeError, "Nenhum script SQL"):
            sql_entries(root, cfg)


if __name__ == "__main__":
    unittest.main()
