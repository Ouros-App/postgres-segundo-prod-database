import json
import io
import tempfile
import unittest
from contextlib import redirect_stderr
from datetime import date, datetime, timezone
from pathlib import Path

from scripts.rpa_pre_novo import (
    DatabaseConfig,
    MigrationReport,
    PendingData,
    RPAError,
    build_parser,
    country_code,
    goal_status,
    main,
    normalize_key,
    state_code,
    timestamp_value,
    validate_load_preflight,
)


class RpaPreNovoTests(unittest.TestCase):
    def test_state_name_and_code_are_normalized(self):
        self.assertEqual(state_code("São Paulo"), "SP")
        self.assertEqual(state_code("sp"), "SP")
        self.assertEqual(state_code("Minas Gerais - MG"), "MG")

    def test_unknown_state_is_pending(self):
        with self.assertRaises(PendingData) as caught:
            state_code("XX")
        self.assertEqual(caught.exception.reason, "unsupported_state")

    def test_country_and_goal_status_mappings(self):
        self.assertEqual(country_code("Brasil"), "BR")
        self.assertEqual(goal_status("NAO_INICIADA"), "Pendente")
        self.assertEqual(goal_status("Em andamento"), "Em andamento")
        with self.assertRaises(PendingData):
            goal_status("aguardando")

    def test_timestamp_preserves_datetime_and_converts_date_to_midnight(self):
        moment = datetime(2025, 3, 4, 18, 27, 9)
        self.assertEqual(timestamp_value(moment), moment)
        self.assertEqual(timestamp_value(date(2025, 3, 4)), datetime(2025, 3, 4))

    def test_timestamp_with_timezone_is_pending(self):
        with self.assertRaises(PendingData) as caught:
            timestamp_value(datetime(2025, 3, 4, tzinfo=timezone.utc))
        self.assertEqual(caught.exception.reason, "source_timestamp_has_timezone")

    def test_normalize_key_removes_accents_and_case(self):
        self.assertEqual(normalize_key("  NÃO   Iniciada "), "nao iniciada")

    def test_report_counts_statuses_and_limits_pending_details(self):
        report = MigrationReport("simulate", "pre", "legacy", "ouros", datetime.now(timezone.utc))
        report.add("loaded", "empresa", 10, "enterprises")
        report.add("pending", "empresa", 11, "enterprises", "missing_address")
        encoded = report.as_dict()
        self.assertEqual(encoded["totals"], {"loaded": 1, "pending": 1})
        self.assertEqual(encoded["pending_details"][0]["reason"], "missing_address")

    def test_preflight_requires_reports_for_same_databases_and_source(self):
        source_config = DatabaseConfig("legacy-db.internal", 5432, "legacy", "rpa", "pw")
        target_config = DatabaseConfig("ouros-db.internal", 5432, "ouros", "rpa", "pw")
        source_connection = {
            "host": "legacy-db.internal", "port": 5432, "database": "legacy", "schema": "public"
        }
        target_connection = {
            "host": "ouros-db.internal", "port": 5432, "database": "ouros", "schema": "public"
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            report_paths = {
                "diagnostic": Path(temp_dir) / "diagnostic.json",
                "simulation": Path(temp_dir) / "simulation.json",
                "reconciliation": Path(temp_dir) / "reconciliation.json",
            }
            for kind, path in report_paths.items():
                contents = {
                    "kind": kind,
                    "source_database": "legacy",
                    "target_database": "ouros",
                    "source_system": "pre",
                    "ready": True,
                    "source_connection": source_connection,
                    "target_connection": target_connection,
                }
                if kind == "simulation":
                    contents.update({"rolled_back": True, "reconciliation": {"ready": True}})
                if kind == "reconciliation":
                    contents["phase"] = "pre_load"
                path.write_text(json.dumps(contents), encoding="utf-8")
            validate_load_preflight(
                str(report_paths["diagnostic"]),
                str(report_paths["simulation"]),
                str(report_paths["reconciliation"]),
                "legacy", "ouros", "pre", source_config, target_config,
            )
            with self.assertRaises(RPAError):
                validate_load_preflight(
                    str(report_paths["diagnostic"]),
                    str(report_paths["simulation"]),
                    str(report_paths["reconciliation"]),
                    "other", "ouros", "pre", source_config, target_config,
                )

    def test_load_command_requires_explicit_confirmation_before_connections(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(main(["load"]), 2)

    def test_reconcile_parser_requires_a_phase(self):
        with redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                build_parser().parse_args(["reconcile"])


if __name__ == "__main__":
    unittest.main()
