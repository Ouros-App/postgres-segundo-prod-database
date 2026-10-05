-- Remove a capacidade de aves do cadastro de fazendas sem quebrar consumidores.
-- midas.farms preserva a coluna no contrato legado, mas passa a servi-la como NULL,
-- eliminando a dependencia da view sobre public.farms.poultry_capacity.
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
FROM public.farms;

-- A coluna legada em farms_log e mantida para preservar o historico existente.
ALTER TABLE farms DROP COLUMN IF EXISTS poultry_capacity;
