# Catálogo do banco de dados

Este catálogo descreve as tabelas e colunas definidas no esquema físico e nas migrações deste repositório. Para cada coluna, apresenta o tipo, a possibilidade de valor nulo, o significado e as regras declaradas no SQL. Os registros de demonstração estão em `sql/dataload_inicial.sql`; este documento não representa os dados atuais de uma instância de produção.

## Convenções

- `PRIMARY KEY` (PK): chave primária. `REFERENCES` (FK): vínculo com outra tabela. `UNIQUE` (UQ): unicidade de uma coluna ou combinação de colunas.
- `CHECK`: validação exigida pelo banco. `DEFAULT`: valor usado quando a inserção omite a coluna.
- A coluna **Aceita NULL?** considera tanto `NOT NULL` quanto a obrigatoriedade implícita das chaves primárias e de `SERIAL`.
- As descrições seguem `sql/catalogo_banco.sql`; tipos e regras vêm das definições e migrações do banco.
- `updated_at` e `keycloak_user_id` aparecem nas tabelas às quais são acrescentadas pelas migrações.

## Entidades principais

### `public.addresses`

Endereços de empresas e fazendas. A carga inicial contém endereços de demonstração.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do endereço. | `PRIMARY KEY` |
| `zip_code` | `VARCHAR(50)` | Não | CEP ou código postal do endereço. | `CHECK(length(zip_code) > 0)` |
| `state` | `VARCHAR(2)` | Não | Sigla do estado ou província. | `CHECK(length(state) = 2)` |
| `city` | `VARCHAR(100)` | Não | Cidade do endereço. | `CHECK(length(city) > 0)` |
| `number` | `VARCHAR(50)` | Não | Número, complemento ou indicação de ausência de número. | `CHECK(length(number) > 0)` |
| `country` | `VARCHAR(2)` | Não | Código de duas letras do país. | `CHECK(length(country) = 2)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.enterprises`

Empresas às quais fazendas, funcionários e planos podem estar associados.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da empresa. | `PRIMARY KEY` |
| `name` | `VARCHAR(100)` | Não | Nome da empresa. | `CHECK(length(name) > 0)` |
| `email` | `VARCHAR(50)` | Não | E-mail de contato cadastrado para a empresa. | `CHECK(length(email) > 0)` |
| `document_number` | `VARCHAR(14)` | Não | Documento empresarial, como CNPJ. | `CHECK(length(document_number) = 14)` |
| `telephone` | `VARCHAR(13)` | Não | Telefone de contato da empresa. | `CHECK(length(telephone) > 9)` |
| `id_address` | `INTEGER` | Não | Endereço da empresa; referencia addresses.id. | `REFERENCES addresses(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.farms`

Fazendas ou granjas cadastradas e seus dados de localização e capacidade.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da fazenda. | `PRIMARY KEY` |
| `name` | `VARCHAR(100)` | Não | Nome ou identificação da fazenda. | `CHECK(length(name) > 0)` |
| `area_property` | `NUMERIC` | Não | Área total da propriedade, em unidade definida pela aplicação. | `CHECK(area_property > 0)` |
| `region` | `VARCHAR(50)` | Não | Região geográfica usada pela aplicação. | `CHECK(btrim(region) <> '')` |
| `poultry_capacity` | `INTEGER` | Não | Capacidade de alojamento de aves. | `CHECK(poultry_capacity >= 0)` |
| `place` | `VARCHAR(50)` | Não | Localidade ou município informado para a fazenda. | `CHECK(length(place) > 0)` |
| `chickens_now` | `INTEGER` | Não | Quantidade atual de aves; padrão zero. | `DEFAULT 0 CHECK (chickens_now >= 0)` |
| `foto_url` | `TEXT` | Sim | URL da foto da fazenda, quando disponível. | — |
| `id_address` | `INTEGER` | Não | Endereço da fazenda; referencia addresses.id. | `REFERENCES addresses(id)` |
| `id_enterprise` | `INTEGER` | Não | Empresa associada; referencia enterprises.id. | `REFERENCES enterprises(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.farm_owners`

Produtores ou proprietários associados a uma fazenda.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do proprietário. | `PRIMARY KEY` |
| `name` | `VARCHAR(100)` | Sim | Nome do proprietário; pode estar ausente durante o cadastro. | `CHECK(length(name) > 0)` |
| `password` | `TEXT` | Não | Credencial de autenticação armazenada pela aplicação. | `CHECK(length(password) > 0)` |
| `email` | `VARCHAR(50)` | Não | E-mail de autenticação ou contato do proprietário. | `CHECK(length(email) > 0)` |
| `document_number` | `VARCHAR(11)` | Sim | Documento pessoal do proprietário; campo opcional. | `CHECK (length(document_number) = 11)` |
| `telephone` | `VARCHAR(13)` | Sim | Telefone do proprietário; campo opcional. | `CHECK(length(telephone) > 9)` |
| `first_access` | `BOOLEAN` | Não | Indica se o usuário ainda está no primeiro acesso. | `DEFAULT TRUE` |
| `foto_url` | `TEXT` | Sim | URL da foto do proprietário, quando disponível. | — |
| `id_farm` | `INTEGER` | Não | Fazenda associada; referencia farms.id. | `REFERENCES farms(id)` |
| `keycloak_user_id` | `UUID` | Sim | UUID opcional que associa o proprietário a um usuário Keycloak. | `UNIQUE quando não nulo (índice parcial)` |

### `public.company_employees`

Funcionários vinculados a uma empresa.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do funcionário. | `PRIMARY KEY` |
| `name` | `VARCHAR(100)` | Não | Nome do funcionário. | `CHECK(length(name) > 0)` |
| `document_number` | `VARCHAR(11)` | Não | Documento pessoal único do funcionário. | `UNIQUE CHECK (length(document_number) = 11)` |
| `email` | `VARCHAR(50)` | Não | E-mail de autenticação ou contato do funcionário. | `CHECK(length(email) > 0)` |
| `telephone` | `VARCHAR(13)` | Não | Telefone do funcionário. | `CHECK(length(telephone) > 9)` |
| `password` | `TEXT` | Não | Credencial de autenticação armazenada pela aplicação. | `CHECK(length(password) > 0)` |
| `id_enterprise` | `INTEGER` | Não | Empresa empregadora; referencia enterprises.id. | `REFERENCES enterprises(id)` |
| `keycloak_user_id` | `UUID` | Sim | UUID opcional que associa o funcionário a um usuário Keycloak. | `UNIQUE quando não nulo (índice parcial)` |

### `public.adms`

Contas administrativas da aplicação.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da conta administrativa. | `PRIMARY KEY` |
| `email` | `VARCHAR(50)` | Não | E-mail de autenticação ou contato do administrador. | `CHECK(length(email) > 0)` |
| `password` | `TEXT` | Não | Credencial de autenticação armazenada pela aplicação. | `CHECK(length(password) > 0)` |
| `keycloak_user_id` | `UUID` | Sim | UUID opcional que associa o administrador a um usuário Keycloak. | `UNIQUE quando não nulo (índice parcial)` |

## Operação das granjas

### `public.lots`

Lotes de aves recebidos e entregues por empresa e fazenda.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do lote. | `PRIMARY KEY` |
| `received_chickens` | `INTEGER` | Não | Quantidade de aves recebidas no lote. | `CHECK (received_chickens >= 0)` |
| `delivered_chickens` | `INTEGER` | Não | Quantidade de aves entregues no lote. | `CHECK (delivered_chickens >= 0)` |
| `delivery_date` | `DATE` | Não | Data de entrega do lote. | — |
| `losts` | `INTEGER` | Não | Quantidade de aves perdidas; padrão zero. | `DEFAULT 0 CHECK (losts >= 0)` |
| `cost` | `DOUBLE PRECISION` | Não | Custo registrado para o lote; padrão zero. | `DEFAULT 0 CHECK (cost >= 0)` |
| `id_enterprise` | `INTEGER` | Não | Empresa associada; referencia enterprises.id. | `REFERENCES enterprises(id)` |
| `id_farm` | `INTEGER` | Não | Fazenda associada; referencia farms.id. | `REFERENCES farms(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `CHECK (delivered_chickens <= received_chickens)`.

### `public.chicken_left`

Registros de saídas ou perdas de aves por fazenda.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do registro. | `PRIMARY KEY` |
| `chickens_count` | `INTEGER` | Não | Quantidade de aves que saíram. | `CHECK (chickens_count > 0)` |
| `exit_date` | `DATE` | Não | Data da saída das aves. | — |
| `id_farm` | `INTEGER` | Não | Fazenda de origem; referencia farms.id. | `REFERENCES farms(id)` |

### `public.water_registries`

Leituras inicial e final do hidrômetro por fazenda e data.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da leitura. | `PRIMARY KEY` |
| `registration_date` | `DATE` | Não | Data da leitura de água. | — |
| `start_hydrometer` | `NUMERIC` | Não | Leitura inicial cumulativa do hidrômetro. | `CHECK(start_hydrometer > 0)` |
| `end_hydrometer` | `NUMERIC` | Não | Leitura final cumulativa do hidrômetro; deve ser maior ou igual à inicial. | `CHECK(end_hydrometer > 0)` |
| `id_farm` | `INTEGER` | Não | Fazenda da leitura; referencia farms.id. | `REFERENCES farms(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `CHECK (end_hydrometer >= start_hydrometer)`.

### `public.energy_registries`

Consumo de energia registrado por fazenda e data.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do registro. | `PRIMARY KEY` |
| `registration_date` | `DATE` | Não | Data do registro de energia. | — |
| `energy_consumption` | `NUMERIC` | Não | Consumo de energia registrado, normalmente expresso em kWh. | `CHECK(energy_consumption > 0)` |
| `id_farm` | `INTEGER` | Não | Fazenda do registro; referencia farms.id. | `REFERENCES farms(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

## Metas, dicas e avaliações

### `public.individual_goals`

Metas individuais de uma fazenda.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da meta. | `PRIMARY KEY` |
| `description` | `VARCHAR` | Sim | Descrição opcional da meta. | — |
| `type` | `VARCHAR(50)` | Não | Tipo ou indicador da meta. | `CHECK(length(type) > 0)` |
| `status` | `VARCHAR(50)` | Não | Situação atual da meta. | `CHECK(length(status) > 0)` |
| `target_value` | `NUMERIC` | Não | Valor que se pretende atingir. | `CHECK(target_value > 0)` |
| `title` | `VARCHAR(50)` | Não | Título curto da meta. | `CHECK(length(title) > 0)` |
| `id_farm` | `INTEGER` | Não | Fazenda responsável pela meta; referencia farms.id. | `REFERENCES farms(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.state_goals`

Metas estaduais ou compartilhadas relacionadas a fazendas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da meta. | `PRIMARY KEY` |
| `description` | `TEXT` | Sim | Descrição opcional da meta. | — |
| `type` | `VARCHAR(50)` | Não | Tipo ou indicador da meta. | `CHECK(length(type) > 0)` |
| `status` | `VARCHAR(40)` | Não | Situação atual da meta. | `CHECK(length(status) > 0)` |
| `target_value` | `NUMERIC` | Não | Valor que se pretende atingir. | `CHECK(target_value > 0)` |
| `title` | `VARCHAR(50)` | Não | Título curto da meta. | `CHECK(length(title) > 0)` |
| `date_creation` | `TIMESTAMP` | Não | Data e hora de criação; padrão no momento da inserção. | `DEFAULT CURRENT_TIMESTAMP` |
| `date_end` | `TIMESTAMP` | Não | Data e hora limite; não pode anteceder a criação. | — |
| `id_farm` | `INTEGER` | Não | Fazenda associada; referencia farms.id. | `REFERENCES farms(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `CHECK (date_end >= date_creation)`.

### `public.regions_goals`

Regiões associadas a metas estaduais.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da associação regional. | `PRIMARY KEY` |
| `region` | `VARCHAR(50)` | Não | Nome da região. | `CHECK(btrim(region) <> '')` |
| `id_goal` | `INTEGER` | Não | Meta associada; referencia state_goals.id. | `REFERENCES state_goals(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.farm_goals`

Associação entre fazendas e metas estaduais.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da associação. | `PRIMARY KEY` |
| `id_farm` | `INTEGER` | Não | Fazenda associada; referencia farms.id. | `REFERENCES farms(id)` |
| `id_goal` | `INTEGER` | Não | Meta associada; referencia state_goals.id. | `REFERENCES state_goals(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `UNIQUE (id_farm, id_goal)`.

### `public.state_goal_regions`

Associação entre metas e registros regionais.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da associação. | `PRIMARY KEY` |
| `id_goal` | `INTEGER` | Não | Meta estadual; referencia state_goals.id. | `REFERENCES state_goals(id)` |
| `id_region` | `INTEGER` | Não | Registro regional; referencia regions_goals.id. | `REFERENCES regions_goals(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `UNIQUE (id_goal, id_region)`.

### `public.tips`

Dicas de uso e boas práticas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da dica. | `PRIMARY KEY` |
| `tip` | `TEXT` | Não | Texto da dica. | `CHECK(length(tip) > 0)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.categories`

Categorias usadas para organizar dicas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da categoria. | `PRIMARY KEY` |
| `category` | `VARCHAR(50)` | Não | Nome da categoria. | `CHECK(length(category) > 0)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.tip_categories`

Associação entre dicas e categorias; cada par é único.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da associação. | `PRIMARY KEY` |
| `id_tip` | `INTEGER` | Não | Dica associada; referencia tips.id. | `REFERENCES tips(id)` |
| `id_category` | `INTEGER` | Não | Categoria associada; referencia categories.id. | `REFERENCES categories(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `UNIQUE (id_tip, id_category)`.

### `public.farms_tips`

Associação entre fazendas e dicas; cada par é único.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da associação. | `PRIMARY KEY` |
| `id_farm` | `INTEGER` | Não | Fazenda associada; referencia farms.id. | `REFERENCES farms(id)` |
| `id_tip` | `INTEGER` | Não | Dica associada; referencia tips.id. | `REFERENCES tips(id)` |

**Regras entre colunas:**

- `UNIQUE (id_farm, id_tip)`.

### `public.reviews`

Avaliações e comentários associados a dicas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da avaliação. | `PRIMARY KEY` |
| `comment` | `TEXT` | Não | Comentário da avaliação. | — |
| `rating` | `INTEGER` | Não | Nota numérica não negativa. | `CHECK (rating >= 0)` |
| `id_tip` | `INTEGER` | Não | Dica avaliada; referencia tips.id. | `REFERENCES tips(id)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

## Planos e pagamentos

### `public.plans`

Planos comerciais disponíveis para empresas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do plano. | `PRIMARY KEY` |
| `title` | `VARCHAR(100)` | Não | Nome único do plano. | `UNIQUE CHECK (btrim(title) <> '')` |
| `duration_days` | `INTEGER` | Não | Duração do plano em dias. | `CHECK (duration_days > 0)` |
| `description` | `TEXT` | Não | Descrição do plano. | `CHECK (btrim(description) <> '')` |
| `price` | `NUMERIC(10,2)` | Não | Preço do plano. | `CHECK (price > 0)` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

### `public.enterprise_plans`

Planos contratados por empresas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno da contratação. | `PRIMARY KEY` |
| `id_enterprise` | `INTEGER` | Não | Empresa contratante; referencia enterprises.id. | `REFERENCES enterprises(id) ON DELETE CASCADE` |
| `id_plan` | `INTEGER` | Não | Plano contratado; referencia plans.id. | `REFERENCES plans(id) ON DELETE CASCADE` |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `UNIQUE (id_enterprise, id_plan)`.
- `UNIQUE (id, id_enterprise)`.

### `public.payments`

Pagamentos vinculados a uma empresa e a um plano contratado.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `SERIAL` | Não | Identificador interno do pagamento. | `PRIMARY KEY` |
| `type` | `VARCHAR(50)` | Não | Tipo ou meio de pagamento. | `CHECK (btrim(type) <> '')` |
| `value` | `NUMERIC(10,2)` | Não | Valor pago. | `CHECK (value > 0)` |
| `date_creation` | `TIMESTAMP` | Não | Data e hora de criação do pagamento. | `DEFAULT CURRENT_TIMESTAMP` |
| `id_enterprise` | `INTEGER` | Não | Empresa pagadora; participa da chave estrangeira composta. | — |
| `id_enterprise_plan` | `INTEGER` | Não | Contratação do plano; participa da chave estrangeira composta. | — |
| `updated_at` | `TIMESTAMPTZ` | Não | Data e hora da última atualização da linha. | `DEFAULT CURRENT_TIMESTAMP` |

**Regras entre colunas:**

- `FOREIGN KEY (id_enterprise_plan, id_enterprise) REFERENCES enterprise_plans(id, id_enterprise)`.

## Histórico

### `public.farms_log`

Histórico de imagens das fazendas após inserção, atualização ou exclusão.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `INTEGER` | Sim | ID original da fazenda, sem chave primária nesta tabela de histórico. | — |
| `name` | `VARCHAR` | Sim | Nome da fazenda no evento registrado. | — |
| `area_property` | `DOUBLE PRECISION` | Sim | Área da propriedade no evento registrado. | — |
| `region` | `VARCHAR` | Sim | Região da fazenda no evento registrado. | — |
| `poulty_capacity` | `INTEGER` | Sim | Capacidade de aves; nome legado usado nesta tabela de histórico. | — |
| `place` | `VARCHAR` | Sim | Localidade da fazenda no evento registrado. | — |
| `chickens_now` | `INTEGER` | Sim | Quantidade atual de aves no evento registrado. | — |
| `id_adress` | `INTEGER` | Sim | ID do endereço; nome legado usado nesta tabela de histórico. | — |
| `id_enterprise` | `INTEGER` | Sim | ID da empresa associada no evento registrado. | — |

Esta tabela registra imagens da linha após inserções, atualizações ou exclusões. O esquema atual não acrescenta chave primária nem data específica do evento de log.

### `public.lots_log`

Histórico de imagens dos lotes após inserção, atualização ou exclusão.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `INTEGER` | Sim | ID original do lote, sem chave primária nesta tabela de histórico. | — |
| `received_chickens` | `INTEGER` | Sim | Quantidade recebida no evento registrado. | — |
| `delivered_chickens` | `INTEGER` | Sim | Quantidade entregue no evento registrado. | — |
| `delivery_date` | `DATE` | Sim | Data de entrega no evento registrado. | — |
| `losts` | `INTEGER` | Sim | Perdas no evento registrado. | — |
| `cost` | `DOUBLE PRECISION` | Sim | Custo no evento registrado. | — |
| `id_enterprise` | `INTEGER` | Sim | ID da empresa no evento registrado. | — |
| `id_farm` | `INTEGER` | Sim | ID da fazenda no evento registrado. | — |

Esta tabela registra imagens da linha após inserções, atualizações ou exclusões. O esquema atual não acrescenta chave primária nem data específica do evento de log.

### `public.payments_log`

Histórico de imagens dos pagamentos após inserção, atualização ou exclusão.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `INTEGER` | Sim | ID original do pagamento, sem chave primária nesta tabela de histórico. | — |
| `type` | `VARCHAR` | Sim | Tipo do pagamento no evento registrado. | — |
| `value` | `DOUBLE PRECISION` | Sim | Valor do pagamento no evento registrado. | — |
| `date_creation` | `TIMESTAMP` | Sim | Data de criação do pagamento no evento registrado. | — |
| `id_enterprise` | `INTEGER` | Sim | ID da empresa no evento registrado. | — |

Esta tabela registra imagens da linha após inserções, atualizações ou exclusões. O esquema atual não acrescenta chave primária nem data específica do evento de log.

## Controle de migrações e importação

### `public.controle_versoes`

Registro de cada execução bem-sucedida do executor SQL.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `id` | `BIGINT` | Não | Identificador interno da linha de versão. | `GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY` |
| `versao` | `BIGINT` | Não | Número sequencial único da execução. | `GENERATED BY DEFAULT AS IDENTITY UNIQUE` |
| `commit_id` | `VARCHAR(64)` | Não | SHA do commit aplicado. | — |
| `comentario_commit` | `TEXT` | Não | Mensagem do commit aplicado. | — |
| `aplicado_em` | `TIMESTAMP` | Sim | Data e hora em que a execução foi registrada. | `DEFAULT NOW()` |

### `public.controle_scripts_sql`

Controle por arquivo SQL, mantido pelo executor apply_sql.py.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `arquivo` | `TEXT` | Não | Caminho relativo do arquivo SQL na pasta configurada. | `PRIMARY KEY` |
| `checksum` | `VARCHAR(64)` | Não | Checksum SHA-256 do conteúdo SQL executado. | — |
| `commit_id` | `VARCHAR(64)` | Não | SHA do commit associado à execução do arquivo. | — |
| `executado_em` | `TIMESTAMPTZ` | Não | Data e hora da execução mais recente do arquivo. | `DEFAULT NOW()` |

### `midas.resource_import_requests`

Recibo idempotente e resultado de cada solicitação de importação histórica.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `request_id` | `UUID` | Não | UUID da solicitação e chave de idempotência. | `PRIMARY KEY` |
| `actor_user_type` | `TEXT` | Não | Tipo de usuário que iniciou a solicitação. | — |
| `actor_user_id` | `BIGINT` | Não | ID do usuário que iniciou a solicitação. | — |
| `source_type` | `TEXT` | Não | Tipo da fonte dos dados importados. | — |
| `source_name` | `TEXT` | Não | Nome informado para a fonte dos dados. | — |
| `payload_sha256` | `TEXT` | Não | SHA-256 hexadecimal do conteúdo recebido. | `CHECK (payload_sha256 ~ '^[0-9a-f]{64}$')` |
| `status` | `TEXT` | Não | Resultado: accepted ou rejected. | `CHECK (status IN ('accepted', 'rejected'))` |
| `received_count` | `INTEGER` | Não | Quantidade de registros recebidos. | `CHECK (received_count >= 0)` |
| `inserted_count` | `INTEGER` | Não | Quantidade de registros inseridos. | `CHECK (inserted_count >= 0)` |
| `skipped_duplicates` | `INTEGER` | Não | Quantidade de duplicatas ignoradas. | `CHECK (skipped_duplicates >= 0)` |
| `rejected_count` | `INTEGER` | Não | Quantidade de registros rejeitados. | `CHECK (rejected_count >= 0)` |
| `errors` | `JSONB` | Não | Detalhes de validação em JSON; padrão é uma lista vazia. | `DEFAULT '[]'::JSONB` |
| `schema_version` | `TEXT` | Não | Versão do contrato de importação. | `DEFAULT 'resource-import-v1'` |
| `created_at` | `TIMESTAMPTZ` | Não | Data e hora de recebimento da solicitação. | `DEFAULT clock_timestamp()` |
| `completed_at` | `TIMESTAMPTZ` | Não | Data e hora de conclusão da solicitação. | `DEFAULT clock_timestamp()` |

### `midas.importer_identities`

Vínculo entre roles técnicos de importação e proprietários de fazendas.

| Coluna | Tipo | Aceita NULL? | Descrição | Regras e padrão |
|---|---|---|---|---|
| `database_role` | `NAME` | Não | Nome do role PostgreSQL que autentica o importador. | `PRIMARY KEY` |
| `farm_owner_id` | `BIGINT` | Não | Proprietário associado; referencia public.farm_owners.id. | `REFERENCES public.farm_owners(id)` |

**Regras entre colunas:**

- `CHECK (database_role <> 'public'::NAME)`.

## Colunas de atualização automática

`updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` é incluída em `addresses`, `enterprises`, `farms`, `lots`, `water_registries`, `energy_registries`, `plans`, `enterprise_plans`, `payments`, `individual_goals`, `state_goals`, `regions_goals`, `farm_goals`, `state_goal_regions`, `tips`, `categories`, `tip_categories` e `reviews`. Um trigger atualiza o valor antes de cada `UPDATE`.

## Views

- `chickens_per_liter`, `chickens_per_kwh` e `integrated_consumption`: indicadores de consumo do mês anterior por fazenda.
- `midas.*`: views de leitura para o role Midas. A maioria espelha tabelas públicas; as views de `farm_owners`, `company_employees` e `adms` omitem as senhas. `midas.tips` e `midas.categories` expõem apenas identificador e nome/texto.

## Carga de demonstração

`sql/dataload_inicial.sql` é configurado como `once` e contém dados sintéticos/de demonstração para endereços, empresas, fazendas, dicas, categorias, avaliações, proprietários, metas, leituras de água e energia, lotes e associações. Os comentários do arquivo indicam aproximadamente 500 registros. Essa carga não inclui linhas para todas as tabelas; em especial, não deve ser interpretada como fotografia do banco de produção. O executor registra um baseline e não injeta a carga se detectar dados de aplicação preexistentes.

## Índices de consulta desta branch

`sql/indices_consulta_registros.sql` declara três índices compostos: `farm_owners (id, password, email)`, `water_registries (id, start_hydrometer, end_hydrometer)` e `energy_registries (id, energy_consumption)`. Os três `id` já são chaves primárias. O catálogo registra a definição solicitada; a utilidade desses índices depende dos filtros e ordenações usados pelas consultas.
