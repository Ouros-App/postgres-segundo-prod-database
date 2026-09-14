WITH water_updates AS (
    SELECT
        id,
        start_hydrometer
            + (ARRAY[420, 450, 480, 510, 540, 570, 600, 630, 660, 690]::NUMERIC[])[
                (((ROW_NUMBER() OVER (ORDER BY id) - 1) % 10) + 1)::INTEGER
            ] AS new_end_hydrometer
    FROM water_registries
    WHERE registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
      AND registration_date < DATE_TRUNC('month', CURRENT_DATE)
)
UPDATE water_registries AS w
SET end_hydrometer = u.new_end_hydrometer
FROM water_updates AS u
WHERE w.id = u.id;

UPDATE energy_registries
SET energy_consumption = energy_consumption * 10
WHERE registration_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND registration_date < DATE_TRUNC('month', CURRENT_DATE)
  AND energy_consumption BETWEEN 100 AND 250;
