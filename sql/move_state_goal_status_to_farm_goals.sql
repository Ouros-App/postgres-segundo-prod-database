-- Move goal progress from the shared state goal to each farm-goal association.
CREATE SCHEMA IF NOT EXISTS midas;
DROP VIEW IF EXISTS midas.state_goals;
DROP VIEW IF EXISTS midas.farm_goals;

ALTER TABLE farm_goals
    ADD COLUMN IF NOT EXISTS status VARCHAR(40);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'state_goals'
          AND column_name = 'status'
    ) THEN
        UPDATE farm_goals fg
        SET status = sg.status
        FROM state_goals sg
        WHERE sg.id = fg.id_goal
          AND fg.status IS NULL;
    END IF;
END;
$$;

UPDATE farm_goals
SET status = 'Pendente'
WHERE status IS NULL;

ALTER TABLE farm_goals
    ALTER COLUMN status SET DEFAULT 'Pendente',
    ALTER COLUMN status SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.farm_goals'::regclass
          AND conname = 'farm_goals_status_nonempty'
    ) THEN
        ALTER TABLE farm_goals
            ADD CONSTRAINT farm_goals_status_nonempty CHECK (length(status) > 0);
    END IF;
END;
$$;

ALTER TABLE state_goals DROP COLUMN IF EXISTS status;

CREATE VIEW midas.state_goals AS
SELECT * FROM public.state_goals;

CREATE VIEW midas.farm_goals AS
SELECT * FROM public.farm_goals;

REVOKE ALL PRIVILEGES ON TABLE midas.state_goals, midas.farm_goals FROM PUBLIC;
GRANT SELECT ON TABLE midas.state_goals, midas.farm_goals TO midas_ro;
