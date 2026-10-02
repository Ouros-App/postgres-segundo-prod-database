-- Remoção solicitada da capacidade de aves do cadastro de fazendas.
-- A coluna legada em farms_log é mantida para preservar o histórico existente.
ALTER TABLE farms DROP COLUMN IF EXISTS poultry_capacity;
