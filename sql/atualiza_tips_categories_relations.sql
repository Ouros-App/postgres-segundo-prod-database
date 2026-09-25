DROP VIEW IF EXISTS midas.tips;
DROP VIEW IF EXISTS midas.categories;

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

ALTER TABLE tips DROP COLUMN IF EXISTS id_farm;
ALTER TABLE categories DROP COLUMN IF EXISTS id_tip;
