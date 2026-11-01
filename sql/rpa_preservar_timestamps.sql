-- Rebuild views that depend on registration_date before changing its type.
DROP VIEW IF EXISTS chickens_per_liter;
DROP VIEW IF EXISTS chickens_per_kwh;
DROP VIEW IF EXISTS integrated_consumption;
DROP VIEW IF EXISTS midas.water_registries;
DROP VIEW IF EXISTS midas.energy_registries;

ALTER TABLE water_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP
    USING registration_date::TIMESTAMP;

ALTER TABLE energy_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP
    USING registration_date::TIMESTAMP;

CREATE VIEW midas.water_registries AS
SELECT * FROM public.water_registries;

CREATE VIEW midas.energy_registries AS
SELECT * FROM public.energy_registries;

REVOKE ALL PRIVILEGES ON TABLE midas.water_registries, midas.energy_registries FROM PUBLIC;
GRANT SELECT ON TABLE midas.water_registries, midas.energy_registries TO midas_ro;

CREATE VIEW chickens_per_liter AS
SELECT
    f.id AS id_farm,
    ROUND(
        SUM(w.end_hydrometer - w.start_hydrometer)
            / NULLIF(f.chickens_now, 0),
        2
    ) AS chickens_per_liter
FROM farms f
JOIN water_registries w ON w.id_farm = f.id
WHERE w.registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND w.registration_date < DATE_TRUNC('month', CURRENT_DATE)
GROUP BY f.id, f.chickens_now;

CREATE VIEW chickens_per_kwh AS
SELECT
    f.id AS id_farm,
    ROUND(
        SUM(e.energy_consumption)
            / NULLIF(f.chickens_now, 0),
        2
    ) AS chickens_per_kwh
FROM farms f
JOIN energy_registries e ON e.id_farm = f.id
WHERE e.registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND e.registration_date < DATE_TRUNC('month', CURRENT_DATE)
GROUP BY f.id, f.chickens_now;

CREATE VIEW integrated_consumption AS
WITH water_totals AS (
    SELECT
        id_farm,
        SUM(end_hydrometer - start_hydrometer) AS liters_consumed
    FROM water_registries
    WHERE registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND registration_date < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY id_farm
), energy_totals AS (
    SELECT
        id_farm,
        SUM(energy_consumption) AS energy_consumed
    FROM energy_registries
    WHERE registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND registration_date < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY id_farm
), consumption_totals AS (
    SELECT
        f.id AS id_farm,
        f.chickens_now,
        w.liters_consumed,
        e.energy_consumed
    FROM farms f
    JOIN water_totals w ON w.id_farm = f.id
    JOIN energy_totals e ON e.id_farm = f.id
)
SELECT
    id_farm,
    ROUND(
        (liters_consumed / NULLIF(chickens_now, 0) * 0.7)
        + (energy_consumed / NULLIF(chickens_now, 0) * 0.3),
        2
    ) AS cgi
FROM consumption_totals;

REVOKE ALL PRIVILEGES ON TABLE
    chickens_per_liter,
    chickens_per_kwh,
    integrated_consumption
FROM PUBLIC;
