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

    def test_analytics_loader_adds_non_null_multiyear_data_across_brazilian_regions(self):
        dataload = (ROOT / "sql" / "dataload_analytics.sql").read_text(encoding="utf-8")

        self.assertNotRegex(dataload, r"(?i)\bNULL\b")

        farm_columns = re.findall(
            r"(?i)INSERT INTO public\.farms\s*\(([^)]*)\)",
            dataload,
        )
        self.assertTrue(farm_columns)
        self.assertTrue(all("foto_url" in columns.lower() for columns in farm_columns))
        self.assertRegex(dataload, r"seed\.chickens_now,\s*'',\s*seed\.address_id")
        self.assertNotIn("example.invalid", dataload)
        self.assertNotIn("Granja Analytics -", dataload)
        inserted_farm_names = re.findall(
            r"\('991\d{5}',\s*'[A-Z]{2}',\s*'[^']+',\s*'[^']+',\s*'([^']+)'",
            dataload,
        )
        self.assertEqual(len(inserted_farm_names), 15)
        self.assertTrue(all("Analytics" not in name for name in inserted_farm_names))

        states = set(
            re.findall(
                r"(?i)\(\s*'991\d{5}',\s*'([A-Z]{2})',\s*'[^']+',\s*'"
                r"(?:Norte|Nordeste|Centro-Oeste|Sudeste|Sul)'",
                dataload,
            )
        )
        self.assertEqual(len(states), 15)

        for region in ("Norte", "Nordeste", "Centro-Oeste", "Sudeste", "Sul"):
            self.assertIn(f"'{region}'", dataload)

        self.assertEqual(dataload.count("FROM generate_series(0, 35) AS months(month_index)"), 4)
        self.assertIn("date_trunc('month', CURRENT_DATE)", dataload)
        self.assertRegex(dataload, r"(?i)INSERT INTO public\.water_registries\s*\(")
        self.assertRegex(dataload, r"(?i)INSERT INTO public\.energy_registries\s*\(")
        self.assertRegex(dataload, r"(?i)INSERT INTO public\.lots\s*\([^)]*\blosts\b[^)]*\bcost\b")
        self.assertRegex(dataload, r"(?i)INSERT INTO public\.chicken_left\s*\(chickens_count,\s*exit_date,\s*id_farm\)")
        self.assertGreaterEqual(dataload.count("WHERE NOT EXISTS"), 6)

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
        self.assertNotRegex(goals.group(1), r"(?i)\bstatus\b")
        farm_goals = re.search(
            r"CREATE TABLE IF NOT EXISTS farm_goals\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )
        self.assertIsNotNone(farm_goals)
        self.assertRegex(farm_goals.group(1), r"(?i)\bstatus\s+VARCHAR\(40\)\s+NOT NULL\s+DEFAULT 'Pendente'")

        dataload = (ROOT / "sql" / "dataload_inicial.sql").read_text(encoding="utf-8")
        self.assertNotRegex(dataload, r"(?i)INSERT INTO farms\s*\([^)]*\bplace\b")
        self.assertNotRegex(
            dataload,
            r"(?i)INSERT INTO state_goals\s*\([^)]*\bid_farm\b",
        )
        self.assertNotRegex(
            dataload,
            r"(?i)INSERT INTO state_goals\s*\([^)]*\bstatus\b",
        )
        self.assertRegex(
            dataload,
            r"(?i)INSERT INTO farm_goals\s*\(id_farm,\s*id_goal,\s*status\)",
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

        progress_function = (ROOT / "sql" / "funcoes_consumo_metas.sql").read_text(encoding="utf-8")
        self.assertIn("SELECT fg.status", progress_function)
        self.assertNotIn("SELECT sg.status", progress_function)

    def test_tips_schema_includes_title_and_foto_url(self):
        schema = (ROOT / "sql" / "banco_ouros_fisico.sql").read_text(encoding="utf-8")
        tips_definition = re.search(
            r"CREATE TABLE IF NOT EXISTS tips\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )
        self.assertIsNotNone(tips_definition)
        self.assertRegex(tips_definition.group(1), r"(?i)\btitle\b")
        self.assertRegex(tips_definition.group(1), r"(?i)\bimage_url\b")
        self.assertRegex(tips_definition.group(1), r"(?i)\bfoto_url\b")

    def test_tips_catalog_and_cloudinary_migration(self):
        migration = (ROOT / "sql" / "atualiza_tips_estrutura_e_catalogo.sql").read_text(encoding="utf-8")
        dataload = (ROOT / "sql" / "dataload_inicial.sql").read_text(encoding="utf-8")

        # 32 tips present
        for sql_content in (migration, dataload):
            self.assertIn("Regulagem Diária e Ajuste de Altura das Linhas de Nipple", sql_content)
            self.assertIn("Calibração de Sensores e Redundância de Termostatos de Emergência", sql_content)
            self.assertIn("res.cloudinary.com/mpyey2bi/image/upload", sql_content)
            self.assertIn("tip_01.webp", sql_content)
            self.assertIn("tip_32.webp", sql_content)

        # Categories present
        for cat in ("Ambiência", "Controle de Umidade", "Ventilação Mínima", "Velocidade do Ar", "Sanitização de Tubulações"):
            self.assertIn(cat, migration)
            self.assertIn(cat, dataload)

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


    def test_notifications_schema_includes_event_id(self):
        schema = (ROOT / "sql" / "banco_ouros_fisico.sql").read_text(encoding="utf-8")
        notifications_definition = re.search(
            r"CREATE TABLE IF NOT EXISTS notifications\s*\((.*?)\n\);",
            schema,
            flags=re.IGNORECASE | re.DOTALL,
        )
        self.assertIsNotNone(notifications_definition)
        self.assertRegex(notifications_definition.group(1), r"(?i)\bevent_id\b")


if __name__ == "__main__":
    unittest.main()
