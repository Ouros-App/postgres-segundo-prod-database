ALTER TABLE tips
    ADD COLUMN IF NOT EXISTS title VARCHAR(150) NOT NULL DEFAULT 'Dica Operacional'
        CHECK (btrim(title) <> ''),
    ADD COLUMN IF NOT EXISTS foto_url TEXT;
