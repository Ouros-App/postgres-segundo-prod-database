-- Reconcile legacy typo in farm_owners.first_acess without deleting user data.
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
    ELSIF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_access'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'farm_owners'
          AND column_name = 'first_acess'
    ) THEN
        ALTER TABLE farm_owners
        ADD COLUMN first_access BOOLEAN NOT NULL DEFAULT TRUE;
    END IF;
END $$;
