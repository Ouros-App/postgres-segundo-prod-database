DROP PROCEDURE IF EXISTS create_tip(TEXT, INTEGER, INTEGER);

CREATE OR REPLACE PROCEDURE create_tip(
    IN p_tip TEXT,
    IN p_id_farm INTEGER,
    IN p_id_category INTEGER,
    INOUT p_tip_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO tips (tip)
    VALUES (p_tip)
    RETURNING id INTO p_tip_id;

    INSERT INTO farms_tips (id_farm, id_tip)
    VALUES (p_id_farm, p_tip_id)
    ON CONFLICT (id_farm, id_tip) DO NOTHING;

    IF p_id_category IS NOT NULL THEN
        INSERT INTO tip_categories (id_tip, id_category)
        VALUES (p_tip_id, p_id_category)
        ON CONFLICT (id_tip, id_category) DO NOTHING;
    END IF;
END;
$$;

DROP PROCEDURE IF EXISTS create_state_goal(VARCHAR, TEXT, VARCHAR, VARCHAR, NUMERIC, TIMESTAMP, TIMESTAMP, INTEGER, INTEGER);

CREATE OR REPLACE PROCEDURE create_state_goal(
    IN p_title VARCHAR(50),
    IN p_description TEXT,
    IN p_type VARCHAR(50),
    IN p_status VARCHAR(40),
    IN p_target_value NUMERIC,
    IN p_date_creation TIMESTAMP,
    IN p_date_end TIMESTAMP,
    IN p_id_farm INTEGER,
    IN p_region VARCHAR(50),
    INOUT p_goal_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_region_id INTEGER;
BEGIN
    INSERT INTO state_goals (
        title,
        description,
        type,
        status,
        target_value,
        date_creation,
        date_end,
        id_farm
    )
    VALUES (
        p_title,
        p_description,
        p_type,
        p_status,
        p_target_value,
        p_date_creation,
        p_date_end,
        p_id_farm
    )
    RETURNING id INTO p_goal_id;

    INSERT INTO farm_goals (id_farm, id_goal)
    VALUES (p_id_farm, p_goal_id)
    ON CONFLICT (id_farm, id_goal) DO NOTHING;

    IF p_region IS NOT NULL AND btrim(p_region) <> '' THEN
        INSERT INTO regions_goals (region, id_goal)
        VALUES (p_region, p_goal_id)
        RETURNING id INTO v_region_id;

        INSERT INTO state_goal_regions (id_goal, id_region)
        VALUES (p_goal_id, v_region_id)
        ON CONFLICT (id_goal, id_region) DO NOTHING;
    END IF;
END;
$$;
