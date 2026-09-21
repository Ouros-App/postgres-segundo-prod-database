CREATE OR REPLACE FUNCTION calculate_water_consumption(
    id_farm_comparation INTEGER
)
RETURNS NUMERIC
LANGUAGE SQL
STABLE
AS $$
    SELECT COALESCE((
        SELECT w.end_hydrometer - w.start_hydrometer
        FROM water_registries AS w
        WHERE w.id_farm = id_farm_comparation
        ORDER BY w.registration_date DESC
        LIMIT 1
    ), 0);
$$;

CREATE OR REPLACE FUNCTION calculate_goals_progress(
    p_id_farm INTEGER
)
RETURNS NUMERIC
LANGUAGE SQL
STABLE
AS $$
    WITH goals AS (
        SELECT ig.status
        FROM individual_goals ig
        WHERE ig.id_farm = p_id_farm

        UNION ALL

        SELECT sg.status
        FROM farm_goals fg
        JOIN state_goals sg ON sg.id = fg.id_goal
        WHERE fg.id_farm = p_id_farm
    )
    SELECT COALESCE(
        ROUND(
            AVG(
                CASE status
                    WHEN 'Concluída' THEN 100
                    WHEN 'Em andamento' THEN 50
                    WHEN 'Pendente' THEN 0
                    ELSE 0
                END
            ),
            2
        ),
        0
    )
    FROM goals;
$$;
