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
