# postgres-segundo-prod-database

<!-- REPO-METADATA:START -->
<div align="center">

[![Repo Size](https://img.shields.io/github/repo-size/Ouros-App/postgres-segundo-prod-database?style=flat-square&label=REPO%20SIZE)](https://github.com/Ouros-App/postgres-segundo-prod-database)
[![Languages](https://img.shields.io/github/languages/count/Ouros-App/postgres-segundo-prod-database?style=flat-square&label=LANGUAGES)](https://github.com/Ouros-App/postgres-segundo-prod-database/languages)
[![Forks](https://img.shields.io/github/forks/Ouros-App/postgres-segundo-prod-database?style=flat-square&label=FORKS)](https://github.com/Ouros-App/postgres-segundo-prod-database/network/members)
[![Issues](https://img.shields.io/github/issues/Ouros-App/postgres-segundo-prod-database?style=flat-square&label=ISSUES)](https://github.com/Ouros-App/postgres-segundo-prod-database/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/Ouros-App/postgres-segundo-prod-database?style=flat-square&label=PULL%20REQUESTS)](https://github.com/Ouros-App/postgres-segundo-prod-database/pulls)

</div>
<!-- REPO-METADATA:END -->

Template para versionamento e aplicação de scripts SQL em PostgreSQL.

## Status e escopo

O repositório contém um executor local de SQL, arquivos SQL de versionamento e um esquema físico de banco. A configuração executa `sql/banco_ouros_fisico.sql` em modo `on_change`, depois de garantir o usuário proprietário e o banco lógico configurado.

A aplicação automática está definida em `.github/workflows/apply-sql-on-main.yml` e é disparada por push em `main` ou manualmente pelo GitHub Actions. O repositório não provisiona a instância/servidor PostgreSQL nem o `POSTGRES_ROOT_DB`; esses recursos precisam existir e estar acessíveis pelas credenciais configuradas.

## Componentes

- `scripts/apply_sql.py`: carrega a configuração, expande variáveis de ambiente, garante o banco e o usuário proprietário, aplica o esquema de versionamento e executa os SQLs configurados.
- `config.yaml`: define PostgreSQL, caminhos, tabela de versões e a ordem dos SQLs.
- `sql/versionamento.sql`: cria a tabela `controle_versoes`.
- `sql/banco_ouros_fisico.sql`: cria tabelas relacionadas a endereços, empresas, fazendas, lotes, metas, planos de medicação e outras entidades do esquema físico.
- `.env.example`: lista as variáveis usadas pela configuração.
- `tests/test_apply_sql.py`: teste automatizado para carregamento da configuração.

O executor também mantém a tabela `controle_scripts_sql`, com checksum, commit e data de execução de cada arquivo processado.

As tabelas usadas pelo banco analítico recebem `updated_at` automaticamente por
`sql/atualiza_updated_at_analytics.sql`. O role `analytics_sync_ro` pode ler
as tabelas autorizadas e as views analíticas descritas abaixo; sua senha deve
ser configurada fora do repositório. As novas views não são expostas
automaticamente ao role `midas_ro`.

## Views analíticas

`sql/views_analytics.sql` cria cinco views comuns no schema `public`:

- `water_monthly`: uma linha por granja e mês com leituras de água; inclui consumo, acumulado anual e consumo do mês consecutivo anterior, quando disponível.
- `energy_monthly`: os mesmos indicadores para energia.
- `integrated_monthly`: uma linha por granja e mês em que água ou energia foi registrada; mantém o recurso ausente como `NULL`, informa flags de disponibilidade e calcula totais e participações por recurso.
- `goals_progress`: uma linha para cada granja, inclusive sem metas; reproduz a pontuação de `calculate_goals_progress` e discrimina metas desconhecidas.
- `payments_monthly`: uma linha por empresa e mês com pagamentos registrados, acumulado anual e comparação consecutiva.

Exemplo de consulta para um dashboard por empresa:

```sql
SELECT
    id_farm,
    month,
    water_consumed,
    water_consumed_ytd,
    previous_month_water_consumed
FROM public.water_monthly
WHERE id_enterprise = 42
  AND month >= DATE '2025-01-01'
  AND month < DATE '2026-01-01'
ORDER BY month, id_farm;
```

Os meses são datas do primeiro dia do mês. As views mensais excluem o mês em
andamento e registros futuros com base em `CURRENT_DATE` da sessão. Os
timestamps são usados sem conversão de fuso; configure a timezone esperada pela
organização na conexão do BI. Meses sem registros não criam linhas, então o
acumulado soma apenas os valores registrados disponíveis. As colunas de
comparação retornam `NULL` se faltar o mês imediatamente anterior ou se o
valor anterior for zero.

As funções de janela calculam os acumulados anuais e as comparações entre meses
consecutivos. Como são calculadas na view, filtros externos por período preservam
o acumulado anual desde o início do ano. Empresa e região são o cadastro atual
da granja e podem reclassificar períodos históricos após uma alteração cadastral.

Em `goals_progress`, metas concluídas pontuam 100, em andamento 50 e pendentes
ou com status desconhecido 0. Uma meta compartilhada conta uma vez por granja
vinculada. Sem metas, a view expõe `goals_count = 0` e `progress_pct = NULL`; a
função existente `calculate_goals_progress` continua retornando zero nesse caso.
`target_value` não é convertido em percentual de cumprimento,
pois o esquema não registra a medida alcançada.

`payments_value` é a soma de `payments.value` registrada, sem confirmação de
liquidação. Água e energia permanecem indicadores separados; não há índice
combinado nem divisão por `farms.chickens_now`, que representa o estoque atual.
O role `analytics_sync_ro` tem leitura explícita nas cinco views. O script de
permissões é executado depois delas e revoga acessos anteriores antes de
reconceder a lista aprovada.

## RPA de importação do banco pré

O script `scripts/rpa_pre_novo.py` implementa a importação planejada do banco
pré para o esquema atual do Ouros. Configure as variáveis `RPA_SOURCE_*` e
`RPA_TARGET_*` no `.env`; mantenha credenciais fora do Git.
`RPA_SOURCE_SYSTEM` identifica de forma estável a origem usada no mapa
persistente de IDs.

Antes da carga, rode diagnóstico, simulação e reconciliação pré-carga. Os
relatórios JSON são compatíveis entre si e não incluem campos de negócio nem
credenciais; os detalhes pendentes incluem os IDs legados para auditoria:

```bash
python scripts/rpa_pre_novo.py diagnose --report reports/rpa-pre-novo-diagnose.json
python scripts/rpa_pre_novo.py simulate --report reports/rpa-pre-novo-simulation.json
python scripts/rpa_pre_novo.py reconcile --before-load \
  --simulation-report reports/rpa-pre-novo-simulation.json \
  --report reports/rpa-pre-novo-reconciliation.json
```

`simulate` executa as mesmas regras da carga dentro de uma transação revertida,
usa IDs temporários negativos e não avança as sequences do destino. Verifique
os itens pendentes nos relatórios e confirme que as migrations aprovadas foram
aplicadas no banco de destino. A carga real é separada e exige a confirmação
literal do banco, além dos três relatórios:

```bash
python scripts/rpa_pre_novo.py load \
  --confirm-load \
  --expected-target-db NOME_EXATO_DO_BANCO \
  --diagnostic-report reports/rpa-pre-novo-diagnose.json \
  --simulation-report reports/rpa-pre-novo-simulation.json \
  --reconciliation-report reports/rpa-pre-novo-reconciliation.json \
  --report reports/rpa-pre-novo-load.json
```

A carga grava entidades e mapa de IDs na mesma transação; erro inesperado
reverte tudo. Linhas rejeitadas por dados ou dependências ficam registradas
como pendentes, sem interromper as outras linhas. Depois da carga, valide os
mapas persistidos e os vínculos com:

```bash
python scripts/rpa_pre_novo.py reconcile --after-load \
  --report reports/rpa-pre-novo-reconciliation-after.json
```

## Pré-requisitos

- Python 3.12, usado pelo workflow de aplicação.
- Uma instância PostgreSQL acessível com as credenciais de bootstrap e do usuário proprietário.
- Git disponível quando o commit não for fornecido por `GITHUB_SHA`.

As dependências Python estão fixadas em `requirements.txt`:

- `psycopg2-binary==2.9.9`
- `PyYAML==6.0.2`
- `python-dotenv==1.0.1`

## Instalação e configuração

Na raiz do repositório:

```bash
cp .env.example .env
python -m pip install -r requirements.txt
```

Preencha no arquivo `.env`:

- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_ROOT_DB`
- `POSTGRES_ROOT_USER`
- `POSTGRES_ROOT_PASSWORD`

A configuração usa essas variáveis em `config.yaml`. Para executar um SQL adicional, inclua um arquivo relativo a `sql/` em `database.execution_order`, por exemplo:

```yaml
execution_order:
  - file: banco_ouros_fisico.sql
    mode: on_change
```

Os modos aceitos pelo executor são `once`, `on_change`, `always` e `never`.

## Execução

```bash
python scripts/apply_sql.py
```

O executor aplica primeiro `sql/versionamento.sql`, depois processa os arquivos configurados e registra o commit em `controle_versoes`. Arquivos em modo `once` não são reaplicados; em `on_change`, só são executados quando o conteúdo muda.

No GitHub Actions, o workflow de aplicação instala as dependências e executa o mesmo comando usando os secrets correspondentes às variáveis `POSTGRES_*`.

A migration `audience_engine_metadata.sql` cria apenas os ponteiros dos snapshots
de audiência e os vínculos revisados entre dicas e audiências. Ela não cria
contas de login. Antes de usar a aplicação, crie as contas separadas e aplique
os grants: `audience_source` recebe `CONNECT`, `USAGE` em `public` e `SELECT`
em `public.farms`, `public.farm_owners` e `public.water_registries`;
`audience_metadata` recebe `CONNECT`, `USAGE` em `public`, `SELECT` em
`public.tip_audience_refs` e `SELECT`, `INSERT` e `UPDATE` em
`public.audience_snapshot_refs`.

## Evolução diária do estoque de aves

`sql/farm_chicken_stock_timeline.sql` cria a função de leitura
`public.farm_chicken_stock_timeline(id_farm, start_date, starting_stock, until_date)`.
Uma CTE recursiva calcula o saldo do próximo dia a partir do anterior, incluindo
dias sem movimentos. O saldo inicial representa o fechamento de `start_date`;
movimentos desse dia já devem estar incluídos nele.

```sql
SELECT *
FROM public.farm_chicken_stock_timeline(
    1, DATE '2026-10-01', 1000, DATE '2026-10-04'
);
```

A primeira linha apresenta o saldo inicial e movimentos iguais a zero. As
demais somam `lots.received_chickens` e descontam `lots.delivered_chickens`,
`lots.losts` e saídas adicionais de `chicken_left`. Os movimentos de lotes são
atribuídos a `delivery_date`, pois o modelo não possui uma data de recebimento.
Lotes sem essa data ficam fora do cálculo. Essa convenção precisa corresponder
ao uso dos dados; o resultado não reconstrói recebimentos ocorridos em outra
data. Uma saída registrada em `chicken_left` não deve repetir uma perda já
contabilizada no lote.

Saldo negativo é apresentado para permitir a identificação de inconsistências.
Fazenda inexistente, parâmetros nulos, saldo inicial negativo ou intervalo
invertido retornam um conjunto vazio. A função usa as permissões do chamador,
que precisa ter leitura de `farms`, `lots` e `chicken_left`. Ela calcula o saldo
para o intervalo solicitado sem atualizar `farms.chickens_now`.

Os testes desse cálculo são executados no PostgreSQL 16 pelo job de integração.

## Testes e qualidade

Execute os testes existentes com:

```bash
python -m unittest discover -s tests -v
```

O workflow `.github/workflows/ci-cd.yml` valida a presença do scaffold, executa integração contra PostgreSQL real e bloqueia migrations automáticas destrutivas que poderiam sobrescrever ou apagar dados de usuários.

## Estrutura do projeto

```text
.
├── .env.example
├── config.yaml
├── requirements.txt
├── scripts/
│   └── apply_sql.py
├── sql/
│   ├── banco_ouros_fisico.sql
│   └── versionamento.sql
└── tests/
    └── test_apply_sql.py
```

## Contribuição

Ao alterar o esquema, atualize os arquivos SQL e a ordem em `config.yaml` quando aplicável. Execute os testes locais e verifique as validações do workflow antes de enviar a alteração.

## Licença

Este projeto está sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE).


## Principais contribuidores

<!-- CONTRIBUTORS:START -->
- [@Nicolas25vlad](https://github.com/Nicolas25vlad) — 5 contribuições
- [@LucasRamosDeCarvalho](https://github.com/LucasRamosDeCarvalho) — 2 contribuições
<!-- CONTRIBUTORS:END -->

> Atualizado automaticamente semanalmente pelo workflow de metadados do README.
