"""Behavioral tests against the disposable PostgreSQL used by CI."""

import datetime as dt
import os
import unittest
from pathlib import Path

import psycopg2


@unittest.skipUnless(
    os.getenv("STOCK_TIMELINE_INTEGRATION") == "1",
    "requires the disposable PostgreSQL integration database",
)
class FarmChickenStockTimelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.connection = psycopg2.connect(
            host=os.environ["POSTGRES_HOST"],
            port=os.environ["POSTGRES_PORT"],
            dbname=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
        )
        cls.cursor = cls.connection.cursor()
        cls.schema = "stock_timeline_integration"
        try:
            cls.cursor.execute(f"CREATE SCHEMA {cls.schema}")
            cls.cursor.execute(
                f"CREATE TABLE {cls.schema}.farms (id INTEGER PRIMARY KEY, name TEXT NOT NULL);"
                f"CREATE TABLE {cls.schema}.lots (id_farm INTEGER NOT NULL, delivery_date DATE, "
                "received_chickens INTEGER NOT NULL, delivered_chickens INTEGER NOT NULL, "
                "losts INTEGER NOT NULL);"
                f"CREATE TABLE {cls.schema}.chicken_left (id_farm INTEGER NOT NULL, "
                "exit_date DATE NOT NULL, chickens_count INTEGER NOT NULL);"
            )
            root = Path(__file__).resolve().parents[1]
            cls.definition = (root / "sql/farm_chicken_stock_timeline.sql").read_text(
                encoding="utf-8"
            ).replace("public.", f"{cls.schema}.")
            cls.cursor.execute(cls.definition)
        except Exception:
            cls.connection.rollback()
            cls.cursor.close()
            cls.connection.close()
            raise

    @classmethod
    def tearDownClass(cls):
        # The schema and all fixtures exist only inside this transaction.
        cls.connection.rollback()
        cls.cursor.close()
        cls.connection.close()

    def setUp(self):
        self.cursor.execute("SAVEPOINT stock_case")
        self.cursor.execute(
            f"INSERT INTO {self.schema}.farms VALUES (1, 'Granja A'), (2, 'Granja B')"
        )

    def tearDown(self):
        self.cursor.execute("ROLLBACK TO SAVEPOINT stock_case")
        self.cursor.execute("RELEASE SAVEPOINT stock_case")

    def timeline(self, farm=1, start=dt.date(2026, 10, 1), stock=1000, end=dt.date(2026, 10, 4)):
        self.cursor.execute(
            f"SELECT * FROM {self.schema}.farm_chicken_stock_timeline(%s, %s, %s, %s)",
            (farm, start, stock, end),
        )
        return self.cursor.fetchall()

    def test_daily_movements_boundaries_and_farm_isolation(self):
        self.cursor.executemany(
            f"INSERT INTO {self.schema}.lots VALUES (%s, %s, %s, %s, %s)",
            [
                (1, dt.date(2026, 10, 1), 900, 0, 0),  # already in the initial balance
                (1, dt.date(2026, 10, 2), 100, 20, 5),
                (1, dt.date(2026, 10, 2), 50, 10, 5),
                (1, dt.date(2026, 10, 4), 0, 200, 10),
                (1, dt.date(2026, 10, 5), 999, 0, 0),  # beyond the interval
                (1, None, 999, 0, 0),
                (2, dt.date(2026, 10, 2), 999, 0, 0),
            ],
        )
        self.cursor.executemany(
            f"INSERT INTO {self.schema}.chicken_left VALUES (%s, %s, %s)",
            [
                (1, dt.date(2026, 10, 1), 100),
                (1, dt.date(2026, 10, 2), 10),
                (1, dt.date(2026, 10, 4), 20),
                (1, dt.date(2026, 10, 5), 100),
                (2, dt.date(2026, 10, 2), 100),
            ],
        )
        self.assertEqual(
            self.timeline(),
            [
                (1, "Granja A", dt.date(2026, 10, 1), 0, 0, 1000),
                (1, "Granja A", dt.date(2026, 10, 2), 150, 50, 1100),
                (1, "Granja A", dt.date(2026, 10, 3), 0, 0, 1100),
                (1, "Granja A", dt.date(2026, 10, 4), 0, 230, 870),
            ],
        )

    def test_same_day_returns_only_initial_balance(self):
        self.assertEqual(
            self.timeline(end=dt.date(2026, 10, 1)),
            [(1, "Granja A", dt.date(2026, 10, 1), 0, 0, 1000)],
        )

    def test_invalid_parameters_and_missing_farm_return_no_rows(self):
        for arguments in (
            {"farm": 999}, {"farm": None}, {"start": None}, {"stock": None},
            {"stock": -1}, {"end": None}, {"end": dt.date(2026, 9, 30)},
        ):
            with self.subTest(arguments=arguments):
                self.assertEqual(self.timeline(**arguments), [])

    def test_negative_balance_is_preserved(self):
        self.cursor.execute(
            f"INSERT INTO {self.schema}.chicken_left VALUES (1, DATE '2026-10-02', 2000)"
        )
        self.assertEqual(self.timeline(end=dt.date(2026, 10, 2))[-1][-1], -1000)

    def test_large_daily_outputs_use_bigint_before_addition(self):
        self.cursor.execute(
            f"INSERT INTO {self.schema}.lots VALUES "
            "(1, DATE '2026-10-02', 2000000000, 1800000000, 1500000000)"
        )
        row = self.timeline(stock=2000000000, end=dt.date(2026, 10, 2))[-1]
        self.assertEqual(row[3:], (2000000000, 3300000000, 700000000))

    def test_reapply_preserves_the_result(self):
        before = self.timeline()
        self.cursor.execute(self.definition)
        self.assertEqual(self.timeline(), before)


if __name__ == "__main__":
    unittest.main()
