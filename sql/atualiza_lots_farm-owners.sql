-- Idempotent schema patch. Keep this migration replayable so legacy databases
-- that were marked as migrated before these columns existed can self-heal.
ALTER TABLE lots
ADD COLUMN IF NOT EXISTS losts INTEGER NOT NULL DEFAULT 0
    CHECK (losts >= 0);

ALTER TABLE lots
ADD COLUMN IF NOT EXISTS cost DOUBLE PRECISION NOT NULL DEFAULT 0
    CHECK (cost >= 0);

ALTER TABLE farm_owners
ADD COLUMN IF NOT EXISTS first_acess BOOLEAN NOT NULL DEFAULT TRUE;
