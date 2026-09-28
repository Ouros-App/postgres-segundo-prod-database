# Catálogo do banco de dados

Este catálogo descreve o esquema PostgreSQL definido pelos arquivos SQL deste repositório na branch `feat/indices-registros`. É um dicionário do modelo, não um espelho de uma instância conectada. A carga `sql/dataload_inicial.sql` contém dados de demonstração para desenvolvimento e testes; ela não informa o conteúdo atual de produção.

## Convenções

- `PK`: chave primária; `FK`: chave estrangeira; `UQ`: valor único.
- `NULL` indica que a coluna aceita ausência de valor. Quando não indicado, confira a restrição no SQL: muitas colunas de negócio são `NOT NULL`.
- `updated_at TIMESTAMPTZ`: campo acrescentado por `atualiza_updated_at_analytics.sql`; recebe a data/hora da última alteração nas tabelas listadas abaixo.
- As colunas `id` das tabelas de negócio normalmente são `SERIAL` e geradas pelo banco.

## Entidades principais

| Tabela | Colunas e significado | Relações e observações |
|---|---|---|
| `addresses` | `id SERIAL PK` — identificador; `zip_code VARCHAR(50)` — CEP/código postal; `state VARCHAR(2)` — UF; `city VARCHAR(100)` — cidade; `number VARCHAR(50)` — número/complemento; `country VARCHAR(2)` — país. | Endereço referenciado por empresas e fazendas. A carga de demonstração usa principalmente endereços de São Paulo e registros fictícios “Não informado”. Tem `updated_at`. |
| `enterprises` | `id SERIAL PK`; `name VARCHAR(100)` — nome; `email VARCHAR(50)` — e-mail de contato; `document_number VARCHAR(14)` — documento empresarial; `telephone VARCHAR(13)` — telefone; `id_address INTEGER FK` — endereço. | `id_address → addresses.id`. A carga inclui 10 empresas de exemplo. |
| `farms` | `id SERIAL PK`; `name VARCHAR(100)` — nome; `area_property NUMERIC` — área; `region VARCHAR(50)` — região; `poultry_capacity INTEGER` — capacidade de aves; `place VARCHAR(50)` — localidade; `chickens_now INTEGER DEFAULT 0` — aves atuais; `foto_url TEXT NULL` — imagem; `id_address INTEGER FK`; `id_enterprise INTEGER FK`. | `id_address → addresses.id`; `id_enterprise → enterprises.id`. Tem `updated_at`. A carga inclui 20 granjas de demonstração. |
| `farm_owners` | `id SERIAL PK`; `name VARCHAR(100) NULL`; `password TEXT` — credencial armazenada; `email VARCHAR(50)`; `document_number VARCHAR(11) NULL`; `telephone VARCHAR(13) NULL`; `first_access BOOLEAN DEFAULT TRUE`; `foto_url TEXT NULL`; `id_farm INTEGER FK`; `keycloak_user_id UUID NULL` — vínculo opcional com identidade Keycloak. | `id_farm → farms.id`. Nome, documento e telefone foram tornados opcionais por migração. Índice único parcial em `keycloak_user_id` quando preenchido. A view `midas.farm_owners` omite `password` e `keycloak_user_id`. |
| `company_employees` | `id SERIAL PK`; `name VARCHAR(100)`; `document_number VARCHAR(11) UQ`; `email VARCHAR(50)`; `telephone VARCHAR(13)`; `password TEXT`; `id_enterprise INTEGER FK`; `keycloak_user_id UUID NULL`. | `id_enterprise → enterprises.id`. Índice único parcial em `keycloak_user_id`; a view `midas.company_employees` não expõe senha nem o vínculo Keycloak. |
| `adms` | `id SERIAL PK`; `email VARCHAR(50)`; `password TEXT`; `keycloak_user_id UUID NULL`. | Índice único parcial em `keycloak_user_id`; a view `midas.adms` expõe somente `id` e `email`. |

## Operação das granjas

| Tabela | Colunas e significado | Relações e observações |
|---|---|---|
| `lots` | `id SERIAL PK`; `received_chickens INTEGER` — aves recebidas; `delivered_chickens INTEGER` — aves entregues; `delivery_date DATE`; `losts INTEGER DEFAULT 0` — perdas; `cost DOUBLE PRECISION DEFAULT 0`; `id_enterprise INTEGER FK`; `id_farm INTEGER FK`. | `id_enterprise → enterprises.id`; `id_farm → farms.id`. Restrições impedem contagens/custo negativos e entrega maior que recebimento. Tem `updated_at`; alterações são copiadas para `lots_log`. |
| `chicken_left` | `id SERIAL PK`; `chickens_count INTEGER` — aves que saíram; `exit_date DATE`; `id_farm INTEGER FK`. | `id_farm → farms.id`. |
| `water_registries` | `id SERIAL PK`; `registration_date DATE`; `start_hydrometer NUMERIC` — leitura inicial; `end_hydrometer NUMERIC` — leitura final; `id_farm INTEGER FK`. | `id_farm → farms.id`; a leitura final deve ser maior ou igual à inicial. Tem `updated_at`. O consumo calculado é `end_hydrometer - start_hydrometer`. Índice adicional de importação usa fazenda, data e leituras como chave natural. |
| `energy_registries` | `id SERIAL PK`; `registration_date DATE`; `energy_consumption NUMERIC`; `id_farm INTEGER FK`. | `id_farm → farms.id`. Tem `updated_at`. Índice adicional de importação usa fazenda, data e consumo como chave natural. |

## Metas, dicas e avaliações

| Tabela | Colunas e significado | Relações e observações |
|---|---|---|
| `individual_goals` | `id SERIAL PK`; `description VARCHAR NULL`; `type VARCHAR(50)`; `status VARCHAR(50)`; `target_value NUMERIC`; `title VARCHAR(50)`; `id_farm INTEGER FK`. | `id_farm → farms.id`. Tem `updated_at`. A carga inclui 30 metas individuais de demonstração. |
| `state_goals` | `id SERIAL PK`; `description TEXT NULL`; `type VARCHAR(50)`; `status VARCHAR(40)`; `target_value NUMERIC`; `title VARCHAR(50)`; `date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP`; `date_end TIMESTAMP`; `id_farm INTEGER FK`. | `id_farm → farms.id`; `date_end >= date_creation`. Tem `updated_at`. O campo `id_farm` é obrigatório no esquema atual. |
| `regions_goals` | `id SERIAL PK`; `region VARCHAR(50)`; `id_goal INTEGER FK`. | `id_goal → state_goals.id`. Tem `updated_at`. |
| `farm_goals` | `id SERIAL PK`; `id_farm INTEGER FK`; `id_goal INTEGER FK`. | Liga fazendas a metas estaduais; combinação `(id_farm, id_goal)` é única. Tem `updated_at`. |
| `state_goal_regions` | `id SERIAL PK`; `id_goal INTEGER FK`; `id_region INTEGER FK`. | Liga metas a registros de região (`regions_goals`); combinação `(id_goal, id_region)` é única. Tem `updated_at`. |
| `tips` | `id SERIAL PK`; `tip TEXT` — texto da dica. | Tem `updated_at`. No modelo atual, não possui `id_farm`; a relação com fazendas está em `farms_tips`. |
| `categories` | `id SERIAL PK`; `category VARCHAR(50)` — nome da categoria. | Tem `updated_at`. No modelo atual, não possui `id_tip`; a relação com dicas está em `tip_categories`. |
| `tip_categories` | `id SERIAL PK`; `id_tip INTEGER FK`; `id_category INTEGER FK`. | Associação dica/categoria; `(id_tip, id_category)` é única. Tem `updated_at`. |
| `farms_tips` | `id SERIAL PK`; `id_farm INTEGER FK`; `id_tip INTEGER FK`. | Associação fazenda/dica; `(id_farm, id_tip)` é única. |
| `reviews` | `id SERIAL PK`; `comment TEXT`; `rating INTEGER`; `id_tip INTEGER FK`. | `id_tip → tips.id`; avaliação associada a uma dica. `rating` deve ser não negativo. Tem `updated_at`. A carga de demonstração inclui 60 avaliações. |

## Planos e pagamentos

| Tabela | Colunas e significado | Relações e observações |
|---|---|---|
| `plans` | `id SERIAL PK`; `title VARCHAR(100) UQ`; `duration_days INTEGER`; `description TEXT`; `price NUMERIC(10,2)`. | Duração e preço devem ser positivos. Tem `updated_at`. |
| `enterprise_plans` | `id SERIAL PK`; `id_enterprise INTEGER FK`; `id_plan INTEGER FK`. | Associa empresa e plano. Ambos usam `ON DELETE CASCADE`; `(id_enterprise, id_plan)` é único. Tem também UQ em `(id, id_enterprise)` para a FK composta de pagamentos. Tem `updated_at`. |
| `payments` | `id SERIAL PK`; `type VARCHAR(50)`; `value NUMERIC(10,2)`; `date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP`; `id_enterprise INTEGER`; `id_enterprise_plan INTEGER`. | FK composta `(id_enterprise_plan, id_enterprise) → enterprise_plans(id, id_enterprise)`. Valor deve ser positivo. Tem `updated_at`; alterações são copiadas para `payments_log`. |

## Histórico

Estas tabelas recebem uma cópia da linha após `INSERT`, `UPDATE` ou `DELETE`. Não possuem chave primária nem coluna de data do evento no esquema atual.

| Tabela | Colunas e significado |
|---|---|
| `farms_log` | `id INTEGER`; `name VARCHAR`; `area_property DOUBLE PRECISION`; `region VARCHAR`; `poulty_capacity INTEGER`; `place VARCHAR`; `chickens_now INTEGER`; `id_adress INTEGER`; `id_enterprise INTEGER`. `poulty_capacity` e `id_adress` são nomes legados/typos no log, preenchidos a partir de `poultry_capacity` e `id_address`. |
| `lots_log` | `id INTEGER`; `received_chickens INTEGER`; `delivered_chickens INTEGER`; `delivery_date DATE`; `losts INTEGER`; `cost DOUBLE PRECISION`; `id_enterprise INTEGER`; `id_farm INTEGER`. |
| `payments_log` | `id INTEGER`; `type VARCHAR`; `value DOUBLE PRECISION`; `date_creation TIMESTAMP`; `id_enterprise INTEGER`. |

## Controle de migrações e importação

| Tabela | Colunas e significado | Observações |
|---|---|---|
| `controle_versoes` | `id BIGINT IDENTITY PK`; `versao BIGINT IDENTITY UQ`; `commit_id VARCHAR(64)`; `comentario_commit TEXT`; `aplicado_em TIMESTAMP DEFAULT NOW()`. | Uma linha por execução bem-sucedida do executor. |
| `controle_scripts_sql` | `arquivo TEXT PK`; `checksum VARCHAR(64)`; `commit_id VARCHAR(64)`; `executado_em TIMESTAMPTZ DEFAULT NOW()`. | Criada pelo próprio `scripts/apply_sql.py`; acompanha a execução por arquivo. |
| `midas.resource_import_requests` | `request_id UUID PK`; `actor_user_type TEXT`; `actor_user_id BIGINT`; `source_type TEXT`; `source_name TEXT`; `payload_sha256 TEXT`; `status TEXT`; `received_count INTEGER`; `inserted_count INTEGER`; `skipped_duplicates INTEGER`; `rejected_count INTEGER`; `errors JSONB DEFAULT []`; `schema_version TEXT DEFAULT 'resource-import-v1'`; `created_at TIMESTAMPTZ`; `completed_at TIMESTAMPTZ`. | Guarda recibo/idempotência e resultado da importação histórica; valida status, hash e contagens. |
| `midas.importer_identities` | `database_role NAME PK`; `farm_owner_id BIGINT FK`. | Relaciona o role técnico autenticado ao proprietário da fazenda (`public.farm_owners.id`). |

## Colunas de atualização automática

`updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` é incluída em `addresses`, `enterprises`, `farms`, `lots`, `water_registries`, `energy_registries`, `plans`, `enterprise_plans`, `payments`, `individual_goals`, `state_goals`, `regions_goals`, `farm_goals`, `state_goal_regions`, `tips`, `categories`, `tip_categories` e `reviews`. Um trigger atualiza o valor antes de cada `UPDATE`.

## Views

- `chickens_per_liter`, `chickens_per_kwh` e `integrated_consumption`: indicadores de consumo do mês anterior por fazenda.
- `midas.*`: views de leitura para o role Midas. A maioria espelha tabelas públicas; as views de `farm_owners`, `company_employees` e `adms` omitem as senhas. `midas.tips` e `midas.categories` expõem apenas identificador e nome/texto.

## Carga de demonstração

`sql/dataload_inicial.sql` é configurado como `once` e contém dados sintéticos/de demonstração para endereços, empresas, fazendas, dicas, categorias, avaliações, proprietários, metas, leituras de água e energia, lotes e associações. Os comentários do arquivo indicam aproximadamente 500 registros. Essa carga não inclui linhas para todas as tabelas; em especial, não deve ser interpretada como fotografia do banco de produção. O executor registra um baseline e não injeta a carga se detectar dados de aplicação preexistentes.

## Índices de consulta desta branch

`sql/indices_consulta_registros.sql` declara três índices compostos: `farm_owners (id, password, email)`, `water_registries (id, start_hydrometer, end_hydrometer)` e `energy_registries (id, energy_consumption)`. Os três `id` já são chaves primárias. O catálogo registra a definição solicitada; a utilidade desses índices depende dos filtros e ordenações usados pelas consultas.

