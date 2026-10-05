-- Remove a capacidade de aves do cadastro de fazendas sem quebrar consumidores.
-- A migration precisa funcionar tanto em bancos existentes quanto em bootstrap limpo.
CREATE SCHEMA IF NOT EXISTS midas;

-- Somente views legadas que ainda expõem poultry_capacity precisam ser ajustadas.
-- Views modernas de nove colunas já não dependem da coluna física e são preservadas
-- exatamente como estão.
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
        EXECUTE $view$
            CREATE OR REPLACE VIEW midas.farms AS
            SELECT
                id,
                name,
                area_property,
                region,
                NULL::INTEGER AS poultry_capacity,
                place,
                chickens_now,
                foto_url,
                id_address,
                id_enterprise
            FROM public.farms
        $view$;
    END IF;
END
$$;

-- A coluna legada em farms_log e mantida para preservar o historico existente.
ALTER TABLE farms DROP COLUMN IF EXISTS poultry_capacity;
