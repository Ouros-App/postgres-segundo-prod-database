DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'tips'
          AND column_name = 'id_farm'
    ) THEN
        INSERT INTO farms_tips (id_farm, id_tip)
        SELECT id_farm, id
        FROM tips
        ON CONFLICT (id_farm, id_tip) DO NOTHING;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'categories'
          AND column_name = 'id_tip'
    ) THEN
        INSERT INTO tip_categories (id_tip, id_category)
        SELECT id_tip, id
        FROM categories
        ON CONFLICT (id_tip, id_category) DO NOTHING;
    END IF;
END;
$$;

ALTER TABLE reviews
    DROP CONSTRAINT IF EXISTS reviews_id_tip_fkey,
    ADD CONSTRAINT reviews_id_tip_fkey
        FOREIGN KEY (id_tip) REFERENCES tips(id) ON DELETE CASCADE;

ALTER TABLE tip_categories
    DROP CONSTRAINT IF EXISTS tip_categories_id_tip_fkey,
    ADD CONSTRAINT tip_categories_id_tip_fkey
        FOREIGN KEY (id_tip) REFERENCES tips(id) ON DELETE CASCADE;

ALTER TABLE farms_tips
    DROP CONSTRAINT IF EXISTS farms_tips_id_tip_fkey,
    ADD CONSTRAINT farms_tips_id_tip_fkey
        FOREIGN KEY (id_tip) REFERENCES tips(id) ON DELETE CASCADE;

ALTER TABLE regions_goals
    DROP CONSTRAINT IF EXISTS regions_goals_id_goal_fkey,
    ADD CONSTRAINT regions_goals_id_goal_fkey
        FOREIGN KEY (id_goal) REFERENCES state_goals(id) ON DELETE CASCADE;

ALTER TABLE farm_goals
    DROP CONSTRAINT IF EXISTS farm_goals_id_goal_fkey,
    ADD CONSTRAINT farm_goals_id_goal_fkey
        FOREIGN KEY (id_goal) REFERENCES state_goals(id) ON DELETE CASCADE;

ALTER TABLE state_goal_regions
    DROP CONSTRAINT IF EXISTS state_goal_regions_id_goal_fkey,
    ADD CONSTRAINT state_goal_regions_id_goal_fkey
        FOREIGN KEY (id_goal) REFERENCES state_goals(id) ON DELETE CASCADE;
