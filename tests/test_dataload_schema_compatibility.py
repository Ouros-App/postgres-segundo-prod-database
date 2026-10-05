import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DataloadSchemaCompatibilityTests(unittest.TestCase):
    def test_farms_schema_and_seed_do_not_reference_removed_poultry_capacity(self):
        schema = (ROOT / "sql" / "banco_ouros_fisico.sql").read_text(encoding="utf-8")
        dataload = (ROOT / "sql" / "dataload_inicial.sql").read_text(encoding="utf-8")
        farms_definition = re.search(
            r"CREATE TABLE IF NOT EXISTS farms\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )

        self.assertIsNotNone(farms_definition)
        self.assertNotRegex(farms_definition.group(1), r"(?i)\bpoultry_capacity\b")
        self.assertNotRegex(dataload, r"(?i)\bpoultry_capacity\b")

    def test_removed_farm_and_state_goal_columns_have_no_active_dependencies(self):
        schema = (ROOT / "sql" / "banco_ouros_fisico.sql").read_text(encoding="utf-8")
        farms = re.search(
            r"CREATE TABLE IF NOT EXISTS farms\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )
        goals = re.search(
            r"CREATE TABLE IF NOT EXISTS state_goals\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )
        self.assertIsNotNone(farms)
        self.assertIsNotNone(goals)
        self.assertNotRegex(farms.group(1), r"(?i)\bplace\b")
        self.assertNotRegex(goals.group(1), r"(?i)\bid_farm\b")

        dataload = (ROOT / "sql" / "dataload_inicial.sql").read_text(encoding="utf-8")
        self.assertNotRegex(dataload, r"(?i)INSERT INTO farms\s*\([^)]*\bplace\b")
        self.assertNotRegex(
            dataload,
            r"(?i)INSERT INTO state_goals\s*\([^)]*\bid_farm\b",
        )
        state_goal_titles = set(
            re.findall(
                r"(?i)INSERT INTO state_goals\s*\([^)]*\)\s*VALUES\s*\([^\n]*?,\s*'([^']+)',\s*CURRENT_TIMESTAMP",
                dataload,
            )
        )
        farm_goal_titles = set(
            re.findall(
                r"(?i)INSERT INTO farm_goals\s*\([^\n]*state_goals WHERE title = '([^']+)'",
                dataload,
            )
        )
        self.assertTrue(state_goal_titles)
        self.assertLessEqual(
            state_goal_titles,
            farm_goal_titles,
            "Every seeded state goal must retain its farm association through farm_goals.",
        )

        for sql_file in ("triggers_logs.sql", "midas-user.sql", "remover_poultry_capacity_farms.sql"):
            content = (ROOT / "sql" / sql_file).read_text(encoding="utf-8")
            self.assertNotRegex(content, r"(?i)farm_row\.place|\bplace\s*,")

    def test_lots_postload_does_not_reference_removed_gain_column(self):
        schema = (ROOT / "sql" / "banco_ouros_fisico.sql").read_text(encoding="utf-8")
        postload = (ROOT / "sql" / "dataload_lots_farm-owners.sql").read_text(encoding="utf-8")

        self.assertIsNone(
            re.search(r"\bgain\b", schema, flags=re.IGNORECASE),
            "The current lots schema must not reintroduce the removed gain column.",
        )
        self.assertIsNone(
            re.search(r"\bgain\b", postload, flags=re.IGNORECASE),
            "The lots post-load must not reference the removed gain column.",
        )


if __name__ == "__main__":
    unittest.main()
