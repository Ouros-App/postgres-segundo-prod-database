-- Migration aditiva e idempotente. Nao sobrescreve nem apaga dados existentes.
ALTER TABLE lots
ADD COLUMN IF NOT EXISTS losts INTEGER NOT NULL DEFAULT 0
    CHECK (losts >= 0);

ALTER TABLE lots
ADD COLUMN IF NOT EXISTS cost DOUBLE PRECISION NOT NULL DEFAULT 0
    CHECK (cost >= 0);

DO $$
BEGIN
    -- Banco legado que possui apenas o nome antigo: renomeia preservando os valores.
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
    END IF;

    -- Se as duas colunas existirem, mantemos ambas. O versionamento automatico
    -- nao escolhe qual valor do usuario deve prevalecer e nao apaga a coluna legada.
END $$;
