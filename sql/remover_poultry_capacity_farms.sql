-- Remove a capacidade de aves do cadastro de fazendas sem quebrar consumidores.
-- A migration precisa funcionar tanto em bancos existentes quanto em bootstrap limpo.
CREATE SCHEMA IF NOT EXISTS midas;

-- Views legadas que expõem poultry_capacity são recriadas pela migration de
-- compatibilidade seguinte, depois que as colunas antigas de farms forem removidas.
DO $$
BEGIN
    IF to_regclass('midas.farms') IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_schema = 'midas'
             AND table_name = 'farms'
             AND column_name = 'poultry_capacity'
       ) THEN
        DROP VIEW IF EXISTS midas.farms;
    END IF;
END
$$;

-- A coluna legada em farms_log e mantida para preservar o historico existente.
ALTER TABLE farms DROP COLUMN IF EXISTS poultry_capacity;
