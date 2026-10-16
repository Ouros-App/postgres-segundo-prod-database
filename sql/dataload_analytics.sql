-- Carga complementar de dados sinteticos para desenvolvimento e analise.
-- Execute depois do esquema e da carga inicial em um ambiente de teste.
-- Cria fazendas em 15 UFs e 36 meses de agua, energia, lotes e saidas de aves.
-- Datas, consumos, custos e quantidades sao ficticios; unidades de custo em R$.
-- A carga pode ser repetida: cada linha e verificada por sua chave natural.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.enterprises
        WHERE email = 'export@guibon.com.br'
    ) THEN
        RAISE EXCEPTION 'Execute a carga inicial antes de dataload_analytics.sql.';
    END IF;
END;
$$;

-- Adiciona enderecos e fazendas em UFs alem de SP.
WITH seed_farms (
    zip_code,
    state,
    city,
    region,
    farm_name,
    area_property,
    chickens_now
) AS (
    VALUES
        ('99100101', 'PR', 'Cascavel', 'Sul', 'Granja Analytics - Cascavel', 62.5::NUMERIC, 12000),
        ('99100102', 'SC', 'Chapeco', 'Sul', 'Granja Analytics - Chapeco', 67.0::NUMERIC, 12750),
        ('99100103', 'RS', 'Passo Fundo', 'Sul', 'Granja Analytics - Passo Fundo', 71.5::NUMERIC, 13500),
        ('99100104', 'GO', 'Rio Verde', 'Centro-Oeste', 'Granja Analytics - Rio Verde', 76.0::NUMERIC, 14250),
        ('99100105', 'MT', 'Sorriso', 'Centro-Oeste', 'Granja Analytics - Sorriso', 80.5::NUMERIC, 15000),
        ('99100106', 'MS', 'Dourados', 'Centro-Oeste', 'Granja Analytics - Dourados', 85.0::NUMERIC, 15750),
        ('99100107', 'MG', 'Uberlandia', 'Sudeste', 'Granja Analytics - Uberlandia', 89.5::NUMERIC, 16500),
        ('99100108', 'ES', 'Linhares', 'Sudeste', 'Granja Analytics - Linhares', 94.0::NUMERIC, 17250),
        ('99100109', 'BA', 'Feira de Santana', 'Nordeste', 'Granja Analytics - Feira de Santana', 98.5::NUMERIC, 18000),
        ('99100110', 'PE', 'Garanhuns', 'Nordeste', 'Granja Analytics - Garanhuns', 103.0::NUMERIC, 18750),
        ('99100111', 'CE', 'Quixada', 'Nordeste', 'Granja Analytics - Quixada', 107.5::NUMERIC, 19500),
        ('99100112', 'PA', 'Maraba', 'Norte', 'Granja Analytics - Maraba', 112.0::NUMERIC, 20250),
        ('99100113', 'TO', 'Araguaina', 'Norte', 'Granja Analytics - Araguaina', 116.5::NUMERIC, 21000),
        ('99100114', 'RO', 'Ji-Parana', 'Norte', 'Granja Analytics - Ji-Parana', 121.0::NUMERIC, 21750),
        ('99100115', 'AM', 'Itacoatiara', 'Norte', 'Granja Analytics - Itacoatiara', 125.5::NUMERIC, 22500)
), inserted_addresses AS (
    INSERT INTO public.addresses (zip_code, state, city, number, country)
    SELECT
        seed.zip_code,
        seed.state,
        seed.city,
        'S/N',
        'BR'
    FROM seed_farms AS seed
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.addresses AS address
        WHERE address.zip_code = seed.zip_code
          AND address.state = seed.state
          AND address.city = seed.city
    )
    RETURNING id, zip_code
), resolved_addresses AS (
    SELECT
        seed.*,
        COALESCE(inserted_address.id, existing_address.id) AS address_id
    FROM seed_farms AS seed
    LEFT JOIN inserted_addresses AS inserted_address
      ON inserted_address.zip_code = seed.zip_code
    LEFT JOIN LATERAL (
        SELECT address.id
        FROM public.addresses AS address
        WHERE address.zip_code = seed.zip_code
          AND address.state = seed.state
          AND address.city = seed.city
        ORDER BY address.id DESC
        LIMIT 1
    ) AS existing_address
      ON TRUE
), enterprise AS (
    SELECT id
    FROM public.enterprises
    WHERE email = 'export@guibon.com.br'
    ORDER BY id DESC
    LIMIT 1
), inserted_farms AS (
    INSERT INTO public.farms (
        name,
        area_property,
        region,
        chickens_now,
        foto_url,
        id_address,
        id_enterprise
    )
    SELECT
        seed.farm_name,
        seed.area_property,
        seed.region,
        seed.chickens_now,
        'https://example.invalid/analytics/' || seed.zip_code || '.jpg',
        seed.address_id,
        enterprise.id
    FROM resolved_addresses AS seed
    CROSS JOIN enterprise
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.farms AS farm
        WHERE farm.name = seed.farm_name
    )
    RETURNING id
)
SELECT COUNT(*) AS inserted_farms
FROM inserted_farms;

-- Leituras de agua com medidores crescentes ao longo de 36 meses completos.
WITH months AS (
    SELECT
        month_index,
        (
            date_trunc('month', CURRENT_DATE)
            - (month_index + 1) * INTERVAL '1 month'
        )::DATE AS month_start
    FROM generate_series(0, 35) AS months(month_index)
), monthly_readings AS (
    SELECT
        farm.id AS id_farm,
        months.month_start + 14 AS registration_date,
        (
            10000
            + farm.id * 100
            + (35 - months.month_index) * (1200 + farm.id * 10)
        )::NUMERIC AS start_hydrometer,
        (
            120
            + farm.id * 3
            + months.month_index * 7
            + ((farm.id * months.month_index) % 19)
        )::NUMERIC AS water_usage
    FROM public.farms AS farm
    CROSS JOIN months
    WHERE farm.name LIKE 'Granja Analytics - %'
)
INSERT INTO public.water_registries (
    registration_date,
    start_hydrometer,
    end_hydrometer,
    id_farm
)
SELECT
    reading.registration_date::TIMESTAMP,
    reading.start_hydrometer,
    reading.start_hydrometer + reading.water_usage,
    reading.id_farm
FROM monthly_readings AS reading
WHERE NOT EXISTS (
    SELECT 1
    FROM public.water_registries AS existing
    WHERE existing.id_farm = reading.id_farm
      AND existing.registration_date = reading.registration_date::TIMESTAMP
);

-- Consumo de energia com variacao por fazenda e por mes.
WITH months AS (
    SELECT
        month_index,
        (
            date_trunc('month', CURRENT_DATE)
            - (month_index + 1) * INTERVAL '1 month'
        )::DATE AS month_start
    FROM generate_series(0, 35) AS months(month_index)
), monthly_readings AS (
    SELECT
        farm.id AS id_farm,
        months.month_start + 14 AS registration_date,
        (
            500
            + farm.id * 25
            + months.month_index * 37
            + ((farm.id * months.month_index) % 29) * 12
        )::NUMERIC AS energy_consumption
    FROM public.farms AS farm
    CROSS JOIN months
    WHERE farm.name LIKE 'Granja Analytics - %'
)
INSERT INTO public.energy_registries (
    registration_date,
    energy_consumption,
    id_farm
)
SELECT
    reading.registration_date::TIMESTAMP,
    reading.energy_consumption,
    reading.id_farm
FROM monthly_readings AS reading
WHERE NOT EXISTS (
    SELECT 1
    FROM public.energy_registries AS existing
    WHERE existing.id_farm = reading.id_farm
      AND existing.registration_date = reading.registration_date::TIMESTAMP
);

-- Lotes mensais com perdas e custos diferentes por fazenda e por periodo.
WITH months AS (
    SELECT
        month_index,
        (
            date_trunc('month', CURRENT_DATE)
            - (month_index + 1) * INTERVAL '1 month'
        )::DATE AS month_start
    FROM generate_series(0, 35) AS months(month_index)
), monthly_lots AS (
    SELECT
        farm.id AS id_farm,
        farm.id_enterprise,
        months.month_start + 20 AS delivery_date,
        1500 + farm.id * 31 + months.month_index * 13 AS received_chickens,
        5 + ((farm.id * 13 + months.month_index * 7) % 60) AS losts,
        (
            6000.00
            + (farm.id % 13) * 431.25
            + months.month_index * 207.50
            + ((farm.id * months.month_index) % 17) * 93.75
        )::DOUBLE PRECISION AS cost
    FROM public.farms AS farm
    CROSS JOIN months
    WHERE farm.name LIKE 'Granja Analytics - %'
)
INSERT INTO public.lots (
    received_chickens,
    delivered_chickens,
    delivery_date,
    id_enterprise,
    id_farm,
    losts,
    cost
)
SELECT
    lot.received_chickens,
    lot.received_chickens - lot.losts - 20,
    lot.delivery_date,
    lot.id_enterprise,
    lot.id_farm,
    lot.losts,
    lot.cost
FROM monthly_lots AS lot
WHERE NOT EXISTS (
    SELECT 1
    FROM public.lots AS existing
    WHERE existing.id_farm = lot.id_farm
      AND existing.delivery_date = lot.delivery_date
);

-- Saidas adicionais de aves, separadas das perdas ja registradas nos lotes.
WITH months AS (
    SELECT
        month_index,
        (
            date_trunc('month', CURRENT_DATE)
            - (month_index + 1) * INTERVAL '1 month'
        )::DATE AS month_start
    FROM generate_series(0, 35) AS months(month_index)
), monthly_exits AS (
    SELECT
        farm.id AS id_farm,
        months.month_start + 25 AS exit_date,
        10 + ((farm.id * 17 + months.month_index * 23) % 91) AS chickens_count
    FROM public.farms AS farm
    CROSS JOIN months
    WHERE farm.name LIKE 'Granja Analytics - %'
)
INSERT INTO public.chicken_left (chickens_count, exit_date, id_farm)
SELECT
    exit_record.chickens_count,
    exit_record.exit_date,
    exit_record.id_farm
FROM monthly_exits AS exit_record
WHERE NOT EXISTS (
    SELECT 1
    FROM public.chicken_left AS existing
    WHERE existing.id_farm = exit_record.id_farm
      AND existing.exit_date = exit_record.exit_date
);
