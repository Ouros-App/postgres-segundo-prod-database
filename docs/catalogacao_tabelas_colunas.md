# Catálogo do banco de dados

Este documento descreve as tabelas e colunas declaradas pelos scripts SQL do repositório. Os tipos, valores padrão, nulabilidade e restrições refletem o esquema versionado aqui; não são uma consulta aos dados de uma instância PostgreSQL em produção.

`PK` indica chave primária; `FK` indica chave estrangeira. Salvo indicação contrária, `NOT NULL` significa que a coluna é obrigatória e a ausência dessa marca significa que a coluna aceita `NULL`. Colunas `SERIAL` geram identificadores inteiros automaticamente.

## Tabelas do domínio

### `addresses`

Armazena endereços utilizados por empresas e fazendas.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do endereço. |
| `zip_code` | `VARCHAR(50) NOT NULL` | CEP ou código postal. |
| `state` | `VARCHAR(2) NOT NULL` | Sigla do estado ou região administrativa, com dois caracteres. |
| `city` | `VARCHAR(100) NOT NULL` | Cidade do endereço. |
| `number` | `VARCHAR(50) NOT NULL` | Número ou identificação do imóvel no endereço. |
| `country` | `VARCHAR(2) NOT NULL` | Código do país com dois caracteres. |

### `enterprises`

Registra empresas proprietárias ou responsáveis por fazendas e lotes.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da empresa. |
| `name` | `VARCHAR(100) NOT NULL` | Nome da empresa. |
| `email` | `VARCHAR(50) NOT NULL` | E-mail de contato. |
| `document_number` | `VARCHAR(14) NOT NULL` | Documento empresarial com 14 caracteres. |
| `telephone` | `VARCHAR(13) NOT NULL` | Telefone de contato. |
| `id_address` | `INTEGER NOT NULL`, FK → `addresses.id` | Endereço associado à empresa. |

### `farms`

Cadastro das fazendas vinculadas a uma empresa e a um endereço.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da fazenda. |
| `name` | `VARCHAR(100) NOT NULL` | Nome da fazenda. |
| `area_property` | `NUMERIC NOT NULL`, maior que zero | Área da propriedade. A unidade não é especificada no DDL. |
| `region` | `VARCHAR(50) NOT NULL` | Região da fazenda; não pode ser vazia após remoção de espaços laterais. |
| `place` | `VARCHAR(50)`, aceita `NULL` | Localidade ou nome do lugar. Se preenchido, não pode ser vazio. |
| `chickens_now` | `INTEGER NOT NULL DEFAULT 0`, mínimo zero | Quantidade atual de galinhas/aves na fazenda. |
| `foto_url` | `TEXT`, aceita `NULL` | URL ou referência da foto da fazenda. |
| `id_address` | `INTEGER NOT NULL`, FK → `addresses.id` | Endereço da fazenda. |
| `id_enterprise` | `INTEGER NOT NULL`, FK → `enterprises.id` | Empresa à qual a fazenda está vinculada. |

### `farm_owners`

Contas dos proprietários ou usuários responsáveis por fazendas.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do proprietário. |
| `name` | `VARCHAR(100)`, aceita `NULL` | Nome do proprietário. Se preenchido, não pode ser vazio. |
| `password` | `TEXT NOT NULL` | Senha ou credencial armazenada; o DDL exige conteúdo não vazio. |
| `email` | `VARCHAR(50) NOT NULL` | E-mail da conta. |
| `document_number` | `VARCHAR(11)`, aceita `NULL` | Documento pessoal com 11 caracteres quando informado. |
| `telephone` | `VARCHAR(13)`, aceita `NULL` | Telefone com mais de nove caracteres quando informado. |
| `first_access` | `BOOLEAN NOT NULL DEFAULT TRUE` | Indica se a conta ainda está no primeiro acesso. |
| `foto_url` | `TEXT`, aceita `NULL` | URL ou referência da foto do proprietário. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda associada ao proprietário. |

### `chicken_left`

Registra saídas ou baixas de aves de uma fazenda.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do registro de saída. |
| `chickens_count` | `INTEGER NOT NULL`, maior que zero | Quantidade de aves que saíram. |
| `exit_date` | `DATE NOT NULL` | Data da saída. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda relacionada à saída. |

### `water_registries`

Leituras de hidrômetro associadas a uma fazenda e data.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da leitura. |
| `registration_date` | `DATE NOT NULL` | Data em que a leitura foi registrada. |
| `start_hydrometer` | `NUMERIC NOT NULL`, maior que zero | Leitura inicial do hidrômetro. |
| `end_hydrometer` | `NUMERIC NOT NULL`, maior que zero | Leitura final; deve ser maior ou igual à inicial. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda à qual pertence a leitura. |

### `energy_registries`

Registros de consumo de energia de uma fazenda.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do registro de energia. |
| `registration_date` | `DATE NOT NULL` | Data do registro. |
| `energy_consumption` | `NUMERIC NOT NULL`, maior que zero | Consumo de energia. A unidade não é especificada no DDL principal. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda à qual pertence o consumo. |

### `lots`

Lotes de aves administrados por uma empresa e associados a uma fazenda.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do lote. |
| `received_chickens` | `INTEGER NOT NULL`, mínimo zero | Aves recebidas no lote. |
| `delivered_chickens` | `INTEGER NOT NULL`, mínimo zero | Aves entregues; não pode superar as recebidas. |
| `delivery_date` | `DATE NOT NULL` | Data de entrega do lote. |
| `losts` | `INTEGER NOT NULL DEFAULT 0`, mínimo zero | Quantidade de aves perdidas. |
| `cost` | `DOUBLE PRECISION NOT NULL DEFAULT 0`, mínimo zero | Custo do lote. |
| `id_enterprise` | `INTEGER NOT NULL`, FK → `enterprises.id` | Empresa responsável pelo lote. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda relacionada ao lote. |

### `tips`

Conteúdo de dicas disponibilizado pelo sistema.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da dica. |
| `tip` | `TEXT NOT NULL` | Texto da dica; não pode ser vazio. |

### `categories`

Categorias usadas para classificar dicas.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da categoria. |
| `category` | `VARCHAR(50) NOT NULL` | Nome da categoria; não pode ser vazio. |

### `reviews`

Avaliações ou comentários associados a uma dica.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da avaliação. |
| `comment` | `TEXT NOT NULL` | Texto do comentário. |
| `rating` | `INTEGER NOT NULL`, mínimo zero | Nota atribuída. O DDL não define um limite máximo. |
| `id_tip` | `INTEGER NOT NULL`, FK → `tips.id` | Dica avaliada. |

### `tip_categories`

Tabela de associação entre dicas e categorias. A combinação de dica e categoria é única.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da associação. |
| `id_tip` | `INTEGER NOT NULL`, FK → `tips.id` | Dica associada. |
| `id_category` | `INTEGER NOT NULL`, FK → `categories.id` | Categoria associada. |

### `farms_tips`

Associa dicas às fazendas; a combinação de fazenda e dica é única.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da associação. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda que recebe a dica. |
| `id_tip` | `INTEGER NOT NULL`, FK → `tips.id` | Dica associada. |

### `individual_goals`

Metas individuais configuradas para uma fazenda.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da meta. |
| `description` | `VARCHAR`, aceita `NULL` | Descrição complementar da meta. |
| `type` | `VARCHAR(50) NOT NULL` | Tipo ou assunto da meta; não pode ser vazio. |
| `status` | `VARCHAR(50) NOT NULL` | Estado atual da meta; não pode ser vazio. |
| `target_value` | `NUMERIC NOT NULL`, maior que zero | Valor ou quantidade que se deseja atingir. |
| `title` | `VARCHAR(50) NOT NULL` | Título da meta; não pode ser vazio. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda responsável pela meta. |

### `state_goals`

Metas de abrangência estadual, vinculadas a uma fazenda conforme o DDL atual.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da meta estadual. |
| `description` | `TEXT`, aceita `NULL` | Descrição detalhada da meta. |
| `type` | `VARCHAR(50) NOT NULL` | Categoria ou tema da meta; não pode ser vazio. |
| `status` | `VARCHAR(40) NOT NULL` | Estado atual da meta; não pode ser vazio. |
| `target_value` | `NUMERIC NOT NULL`, maior que zero | Valor ou quantidade desejada. |
| `title` | `VARCHAR(50) NOT NULL` | Título da meta; não pode ser vazio. |
| `date_creation` | `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` | Data e hora de criação. |
| `date_end` | `TIMESTAMP`, aceita `NULL` | Prazo final; quando preenchido, deve ser igual ou posterior à criação. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda vinculada à meta. |

### `regions_goals`

Registra regiões participantes de metas estaduais.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do vínculo regional. |
| `region` | `VARCHAR(50) NOT NULL` | Nome da região; não pode ser vazio após remoção de espaços laterais. |
| `id_goal` | `INTEGER NOT NULL`, FK → `state_goals.id` | Meta estadual relacionada. |

### `farm_goals`

Associação entre fazendas e metas estaduais. Uma fazenda não pode repetir a mesma meta.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da associação. |
| `id_farm` | `INTEGER NOT NULL`, FK → `farms.id` | Fazenda associada. |
| `id_goal` | `INTEGER NOT NULL`, FK → `state_goals.id` | Meta associada. |

### `state_goal_regions`

Relaciona metas estaduais a registros da tabela `regions_goals`; a combinação é única.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da associação. |
| `id_goal` | `INTEGER NOT NULL`, FK → `state_goals.id` | Meta relacionada. |
| `id_region` | `INTEGER NOT NULL`, FK → `regions_goals.id` | Registro regional relacionado. |

### `company_employees`

Contas de funcionários vinculados a empresas.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do funcionário. |
| `name` | `VARCHAR(100) NOT NULL` | Nome do funcionário. |
| `document_number` | `VARCHAR(11) NOT NULL UNIQUE` | Documento pessoal; não pode repetir. |
| `email` | `VARCHAR(50) NOT NULL` | E-mail do funcionário. |
| `telephone` | `VARCHAR(13) NOT NULL` | Telefone com mais de nove caracteres. |
| `password` | `TEXT`, aceita `NULL` | Senha; se informada, deve ser não vazia. |
| `id_enterprise` | `INTEGER NOT NULL`, FK → `enterprises.id` | Empresa à qual o funcionário pertence. |

### `adms`

Credenciais de administradores do sistema.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do administrador. |
| `email` | `VARCHAR(50) NOT NULL` | E-mail de acesso. |
| `password` | `TEXT NOT NULL` | Senha; não pode ser vazia. |

### `plans`

Planos comerciais que podem ser contratados por empresas.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do plano. |
| `title` | `VARCHAR(100) NOT NULL UNIQUE` | Título único do plano; não pode ser vazio. |
| `duration_days` | `INTEGER NOT NULL`, maior que zero | Duração do plano em dias. |
| `description` | `TEXT NOT NULL` | Descrição do plano; não pode ser vazia após remoção de espaços laterais. |
| `price` | `NUMERIC(10,2) NOT NULL`, maior que zero | Preço do plano, com duas casas decimais. |

### `enterprise_plans`

Associa empresas a planos contratados. As FKs são removidas em cascata quando empresa ou plano é excluído.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador da contratação. |
| `id_enterprise` | `INTEGER NOT NULL`, FK → `enterprises.id` com `ON DELETE CASCADE` | Empresa contratante. |
| `id_plan` | `INTEGER NOT NULL`, FK → `plans.id` com `ON DELETE CASCADE` | Plano contratado. |

### `payments`

Pagamentos associados ao plano de uma empresa. A referência composta garante que o plano pertence à empresa indicada.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `SERIAL`, PK | Identificador do pagamento. |
| `type` | `VARCHAR(50) NOT NULL` | Tipo ou método do pagamento; não pode ser vazio. |
| `value` | `NUMERIC(10,2) NOT NULL`, maior que zero | Valor pago. |
| `date_creation` | `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` | Data e hora de criação do registro. |
| `id_enterprise` | `INTEGER NOT NULL` | Empresa pagadora; compõe a FK para `enterprise_plans`. |
| `id_enterprise_plan` | `INTEGER NOT NULL` | Contratação do plano relacionada ao pagamento; compõe a FK para `enterprise_plans`. |

## Tabelas de histórico

Os gatilhos de `sql/triggers_logs.sql` copiam alterações de algumas tabelas para tabelas de histórico. As colunas de log não são declaradas como PK/FK no DDL correspondente.

### `payments_log`

Cópia dos principais dados de pagamento no momento em que o gatilho é executado.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `INTEGER`, aceita `NULL` | ID do pagamento de origem. |
| `type` | `VARCHAR`, aceita `NULL` | Tipo do pagamento. |
| `value` | `DOUBLE PRECISION`, aceita `NULL` | Valor copiado do pagamento. |
| `date_creation` | `TIMESTAMP`, aceita `NULL` | Data de criação do pagamento. |
| `id_enterprise` | `INTEGER`, aceita `NULL` | ID da empresa associada. |

### `lots_log`

Cópia dos dados do lote registrados pelo gatilho.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `INTEGER`, aceita `NULL` | ID do lote de origem. |
| `received_chickens` | `INTEGER`, aceita `NULL` | Quantidade de aves recebidas. |
| `delivered_chickens` | `INTEGER`, aceita `NULL` | Quantidade de aves entregues. |
| `delivery_date` | `DATE`, aceita `NULL` | Data de entrega. |
| `losts` | `INTEGER`, aceita `NULL` | Quantidade de aves perdidas. |
| `cost` | `DOUBLE PRECISION`, aceita `NULL` | Custo registrado. |
| `id_enterprise` | `INTEGER`, aceita `NULL` | ID da empresa associada. |
| `id_farm` | `INTEGER`, aceita `NULL` | ID da fazenda associada. |

### `farms_log`

Cópia histórica parcial dos dados de uma fazenda. O DDL contém nomes legados com grafia diferente dos campos da tabela principal.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `INTEGER`, aceita `NULL` | ID da fazenda de origem. |
| `name` | `VARCHAR`, aceita `NULL` | Nome da fazenda. |
| `area_property` | `DOUBLE PRECISION`, aceita `NULL` | Área copiada da fazenda. |
| `region` | `VARCHAR`, aceita `NULL` | Região da fazenda. |
| `poulty_capacity` | `INTEGER`, aceita `NULL` | Coluna histórica com esse nome no DDL; mantém uma grafia legada e não corresponde a uma coluna atual de `farms`. |
| `place` | `VARCHAR`, aceita `NULL` | Localidade da fazenda. |
| `chickens_now` | `INTEGER`, aceita `NULL` | Quantidade atual de aves registrada. |
| `id_adress` | `INTEGER`, aceita `NULL` | ID do endereço; nome histórico com grafia distinta de `farms.id_address`. |
| `id_enterprise` | `INTEGER`, aceita `NULL` | ID da empresa associada. |

## Tabelas de controle da aplicação

### `controle_versoes`

Histórico de versões do banco aplicado pelo executor.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `id` | `BIGINT IDENTITY`, PK | Identificador sequencial do registro. |
| `versao` | `BIGINT IDENTITY UNIQUE NOT NULL` | Número sequencial e único da versão. |
| `commit_id` | `VARCHAR(64) NOT NULL` | Identificador do commit associado à aplicação. |
| `comentario_commit` | `TEXT NOT NULL` | Comentário ou descrição do commit. |
| `aplicado_em` | `TIMESTAMP DEFAULT NOW()`, aceita `NULL` | Data e hora em que a versão foi aplicada. |

### `controle_scripts_sql`

Tabela mantida por `scripts/apply_sql.py` para controlar execução e checksum de cada script SQL.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `arquivo` | `TEXT`, PK | Caminho/nome do script SQL registrado. |
| `checksum` | `VARCHAR(64) NOT NULL` | Hash do conteúdo usado para detectar alterações. |
| `commit_id` | `VARCHAR(64) NOT NULL` | Commit associado à execução do script. |
| `executado_em` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | Data e hora da execução, com fuso horário. |

## Tabelas do importador MIDAS

As tabelas abaixo pertencem ao schema PostgreSQL `midas` e apoiam a importação controlada de registros históricos de água e energia.

### `midas.resource_import_requests`

Controle de idempotência, resultado e resumo de cada solicitação de importação.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `request_id` | `UUID`, PK | Identificador único fornecido para a solicitação. |
| `actor_user_type` | `TEXT NOT NULL` | Tipo de usuário que iniciou a importação. |
| `actor_user_id` | `BIGINT NOT NULL` | Identificador do usuário responsável. |
| `source_type` | `TEXT NOT NULL` | Tipo/origem dos dados importados. |
| `source_name` | `TEXT NOT NULL` | Nome da fonte dos dados. |
| `payload_sha256` | `TEXT NOT NULL` | Hash SHA-256 do conteúdo recebido; validado para 64 caracteres hexadecimais minúsculos. |
| `status` | `TEXT NOT NULL` | Resultado, restrito a `accepted` ou `rejected`. |
| `received_count` | `INTEGER NOT NULL`, mínimo zero | Quantidade de registros recebidos. |
| `inserted_count` | `INTEGER NOT NULL`, mínimo zero | Quantidade de registros inseridos. |
| `skipped_duplicates` | `INTEGER NOT NULL`, mínimo zero | Quantidade de duplicatas ignoradas. |
| `rejected_count` | `INTEGER NOT NULL`, mínimo zero | Quantidade de registros rejeitados. |
| `errors` | `JSONB NOT NULL DEFAULT '[]'` | Lista estruturada de erros da importação. |
| `schema_version` | `TEXT NOT NULL DEFAULT 'resource-import-v1'` | Versão do formato de importação. |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()` | Momento de criação da solicitação. |
| `completed_at` | `TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()` | Momento de conclusão registrado. |

### `midas.importer_identities`

Relaciona uma role de banco de dados autorizada ao proprietário de fazenda que ela representa.

| Coluna | Tipo e regras | Descrição |
|---|---|---|
| `database_role` | `NAME`, PK | Nome da role PostgreSQL autenticada; a role `public` é proibida. |
| `farm_owner_id` | `BIGINT NOT NULL`, FK → `public.farm_owners.id` | Proprietário associado à role. |

## Relações principais

- `enterprises` e `farms` apontam para `addresses`; cada fazenda também aponta para uma empresa.
- `farm_owners`, registros de água/energia, lotes, saídas de aves e metas individuais relacionam-se a fazendas.
- `reviews` aponta para uma dica; `tip_categories` liga dicas a categorias; `farms_tips` liga dicas a fazendas.
- `enterprise_plans` liga empresas e planos; `payments` referencia a contratação composta por empresa e plano.
- Metas estaduais relacionam-se a regiões por `regions_goals` e `state_goal_regions`; `farm_goals` associa fazendas às metas.
- `midas.importer_identities` liga roles autenticadas aos proprietários autorizados para importação.

## Observações

- A documentação é derivada dos scripts versionados no repositório. Migrações históricas podem conter diferenças temporárias de estrutura; a configuração atual e o DDL principal indicam o esquema esperado após a aplicação dos scripts.
- A tabela `farms_log` conserva `poulty_capacity` e `id_adress` como nomes históricos, apesar de não corresponderem às colunas atuais da tabela `farms`.
- A grafia `losts` é a que está definida no esquema para a quantidade de perdas do lote.
- Descrições de unidades só são informadas quando aparecem explicitamente nos scripts SQL; não se inferem unidades ausentes do DDL.
