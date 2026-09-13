CREATE OR REPLACE VIEW chickens_per_liter AS
WITH water_totals AS (
    SELECT
        id_farm,
        DATE_TRUNC('month', registration_date)::DATE AS month,
        SUM(end_hydrometer - start_hydrometer) AS liters_consumed
    FROM water_registries
    GROUP BY id_farm, DATE_TRUNC('month', registration_date)
)
SELECT
    f.id AS id_farm,
    f.name AS farm_name,
    w.month,
    f.chickens_now,
    w.liters_consumed,
    f.chickens_now::NUMERIC / NULLIF(w.liters_consumed, 0) AS chickens_per_liter
FROM farms f
JOIN water_totals w ON w.id_farm = f.id;

CREATE OR REPLACE VIEW chickens_per_kwh AS
WITH energy_totals AS (
    SELECT
        id_farm,
        DATE_TRUNC('month', registration_date)::DATE AS month,
        SUM(energy_consumption) AS kwh_consumed
    FROM energy_registries
    GROUP BY id_farm, DATE_TRUNC('month', registration_date)
)
SELECT
    f.id AS id_farm,
    f.name AS farm_name,
    e.month,
    f.chickens_now,
    e.kwh_consumed,
    f.chickens_now::NUMERIC / NULLIF(e.kwh_consumed, 0) AS chickens_per_kwh
FROM farms f
JOIN energy_totals e ON e.id_farm = f.id;
