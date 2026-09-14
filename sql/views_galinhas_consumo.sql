CREATE OR REPLACE VIEW chickens_per_liter AS
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

CREATE OR REPLACE VIEW chickens_per_kwh AS
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

CREATE OR REPLACE VIEW integrated_consumption AS
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
