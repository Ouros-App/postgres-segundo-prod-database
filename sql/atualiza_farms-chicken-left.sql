ALTER TABLE farms
    ADD COLUMN IF NOT EXISTS chickens_now INTEGER NOT NULL DEFAULT 0
        CHECK (chickens_now >= 0),
    ADD COLUMN IF NOT EXISTS foto_url TEXT;

ALTER TABLE farm_owners
    ADD COLUMN IF NOT EXISTS foto_url TEXT;

DROP VIEW IF EXISTS midas.lots RESTRICT;

ALTER TABLE lots
    DROP COLUMN IF EXISTS date_birth,
    DROP COLUMN IF EXISTS gain;

CREATE TABLE IF NOT EXISTS chicken_left (
    id SERIAL PRIMARY KEY,
    chickens_count INTEGER NOT NULL
        CHECK (chickens_count > 0),
    exit_date DATE NOT NULL,
    id_farm INTEGER NOT NULL
        REFERENCES farms(id)
);

UPDATE farms
SET chickens_now = CASE name
    WHEN 'Granja para Produção de Ovos Caipiras - Atibaia' THEN 3200
    WHEN 'Sítio com 2 Granjas - São Pedro' THEN 4100
    WHEN 'Granja Automatizada para 220 Mil Aves - Cerquilho' THEN 2800
    WHEN 'Granja em Plena Produção - Cerquilho' THEN 5000
    WHEN 'Granja e Propriedade Rural de 6,16 Alqueires - Itapira' THEN 4600
    WHEN 'Granja Automatizada em Atividade - Itapira' THEN 5900
    WHEN 'Granja de Aves com 6 Alqueires - Amparo' THEN 5100
    WHEN 'Aviário 12 x 126 - Indaiatuba' THEN 6400
    WHEN 'Granja de Aves - Santo Antônio de Posse' THEN 5700
    WHEN 'Arrendamento de Aviário - Ibiúna' THEN 6800
    WHEN 'Granja de Frango Automatizada - Bragança Paulista' THEN 6200
    WHEN 'Granja Poedeira - Itapetininga' THEN 7300
    WHEN 'Sítio com Aviário Antigo - Serra Negra' THEN 6900
    WHEN 'Granja de Aves - São Carlos' THEN 7600
    WHEN 'Sítio Granja à Venda - Tatuí' THEN 7200
    WHEN 'Compro Granja de Postura Caipira - São Paulo' THEN 8200
    WHEN 'Sítio com Granjas de Frangos - Pereiras' THEN 7800
    WHEN 'Sítio com Duas Granjas de Frango de Corte - Guatapará' THEN 8600
    WHEN 'Granja Frango de Corte - São Paulo' THEN 8400
    WHEN 'Granja de Aves/Aviários — Registro Fictício - São Paulo' THEN 9300
    ELSE chickens_now
END
WHERE name IN (
    'Granja para Produção de Ovos Caipiras - Atibaia',
    'Sítio com 2 Granjas - São Pedro',
    'Granja Automatizada para 220 Mil Aves - Cerquilho',
    'Granja em Plena Produção - Cerquilho',
    'Granja e Propriedade Rural de 6,16 Alqueires - Itapira',
    'Granja Automatizada em Atividade - Itapira',
    'Granja de Aves com 6 Alqueires - Amparo',
    'Aviário 12 x 126 - Indaiatuba',
    'Granja de Aves - Santo Antônio de Posse',
    'Arrendamento de Aviário - Ibiúna',
    'Granja de Frango Automatizada - Bragança Paulista',
    'Granja Poedeira - Itapetininga',
    'Sítio com Aviário Antigo - Serra Negra',
    'Granja de Aves - São Carlos',
    'Sítio Granja à Venda - Tatuí',
    'Compro Granja de Postura Caipira - São Paulo',
    'Sítio com Granjas de Frangos - Pereiras',
    'Sítio com Duas Granjas de Frango de Corte - Guatapará',
    'Granja Frango de Corte - São Paulo',
    'Granja de Aves/Aviários — Registro Fictício - São Paulo'
);
