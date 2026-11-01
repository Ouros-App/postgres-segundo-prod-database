-- Preserve existing farm-goal links, then remove both redundant columns.
CREATE SCHEMA IF NOT EXISTS midas;
DROP VIEW IF EXISTS midas.farms;
DROP VIEW IF EXISTS midas.state_goals;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'state_goals'
          AND column_name = 'id_farm'
    ) THEN
        INSERT INTO farm_goals (id_farm, id_goal)
        SELECT id_farm, id
        FROM state_goals
        WHERE id_farm IS NOT NULL
        ON CONFLICT (id_farm, id_goal) DO NOTHING;
    END IF;
END;
$$;

ALTER TABLE state_goals DROP COLUMN IF EXISTS id_farm;
ALTER TABLE farms DROP COLUMN IF EXISTS place;

-- Keep the legacy Midas capacity field while exposing the new farms shape.
CREATE VIEW midas.farms AS
SELECT
    id,
    name,
    area_property,
    region,
    NULL::INTEGER AS poultry_capacity,
    chickens_now,
    foto_url,
    id_address,
    id_enterprise,
    updated_at
FROM public.farms;

CREATE VIEW midas.state_goals AS
SELECT * FROM public.state_goals;

REVOKE ALL PRIVILEGES ON TABLE midas.farms, midas.state_goals FROM PUBLIC;
GRANT SELECT ON TABLE midas.farms, midas.state_goals TO midas_ro;
