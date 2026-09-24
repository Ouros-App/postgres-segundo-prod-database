CREATE OR REPLACE PROCEDURE create_tip(
    IN p_tip TEXT,
    IN p_id_farm INTEGER,
    IN p_id_category INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tip_id INTEGER;
BEGIN
    INSERT INTO tips (tip)
    VALUES (p_tip)
    RETURNING id INTO v_tip_id;

    INSERT INTO farms_tips (id_farm, id_tip)
    VALUES (p_id_farm, v_tip_id)
    ON CONFLICT (id_farm, id_tip) DO NOTHING;

    INSERT INTO tip_categories (id_tip, id_category)
    VALUES (v_tip_id, p_id_category)
    ON CONFLICT (id_tip, id_category) DO NOTHING;
END;
$$;

CREATE OR REPLACE PROCEDURE create_state_goal(
    IN p_title VARCHAR(50),
    IN p_description TEXT,
    IN p_type VARCHAR(50),
    IN p_status VARCHAR(40),
    IN p_target_value NUMERIC,
    IN p_date_creation TIMESTAMP,
    IN p_date_end TIMESTAMP,
    IN p_id_farm INTEGER,
    IN p_id_region INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_goal_id INTEGER;
BEGIN
    INSERT INTO state_goals (
        title,
        description,
        type,
        status,
        target_value,
        date_creation,
        date_end
    )
    VALUES (
        p_title,
        p_description,
        p_type,
        p_status,
        p_target_value,
        p_date_creation,
        p_date_end
    )
    RETURNING id INTO v_goal_id;

    INSERT INTO farm_goals (id_farm, id_goal)
    VALUES (p_id_farm, v_goal_id)
    ON CONFLICT (id_farm, id_goal) DO NOTHING;

    INSERT INTO state_goal_regions (id_goal, id_region)
    VALUES (v_goal_id, p_id_region)
    ON CONFLICT (id_goal, id_region) DO NOTHING;
END;
$$;
