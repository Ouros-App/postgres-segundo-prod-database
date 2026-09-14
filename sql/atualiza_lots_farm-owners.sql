-- Idempotent schema patch. Keep this migration replayable so legacy databases
-- that were marked as migrated before these columns existed can self-heal.
ALTER TABLE lots
ADD COLUMN IF NOT EXISTS losts INTEGER NOT NULL DEFAULT 0
    CHECK (losts >= 0);

ALTER TABLE lots
ADD COLUMN IF NOT EXISTS cost DOUBLE PRECISION NOT NULL DEFAULT 0
    CHECK (cost >= 0);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_acess'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_access'
    ) THEN
        ALTER TABLE farm_owners RENAME COLUMN first_acess TO first_access;
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_acess'
    )
    AND EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_access'
    ) THEN
        UPDATE farm_owners
        SET first_access = first_acess
        WHERE first_access IS DISTINCT FROM first_acess;

        ALTER TABLE farm_owners DROP COLUMN first_acess;
    END IF;
END $$;
