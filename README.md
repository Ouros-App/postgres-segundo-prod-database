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
somente essas tabelas para alimentar o banco analítico; sua senha deve ser
configurada fora do repositório.

## Monitoramento DAU

`sql/monitoramento_dau.sql` registra uma linha por conta e dia na tabela
`public.user_daily_activity`. Uma conta é identificada pelo par `user_type` e
`user_id` (`farm_owner`, `company_employee` ou `adm`), e o dia segue
`America/Sao_Paulo`. A função `public.record_daily_activity(text, integer)` valida
o cadastro e retorna `true` apenas quando grava o primeiro uso da conta naquele
dia. Ela usa o horário de gravação do banco e não reconstrói eventos perdidos.

O backend deve chamar a função depois de autenticar um login válido ou autorizar
uma requisição de uso. A API deste repositório não está incluída, então publicar
esta alteração disponibiliza a estrutura e as permissões, mas a coleta real só
começa após essa integração. Não são criados registros a partir de seeds ou do
campo `first_access`.

O role `activity_recorder` recebe somente `EXECUTE` na função e precisa da
variável `ACTIVITY_RECORDER_PASSWORD` configurada no `.env` local ou no secret de
mesmo nome do GitHub Actions; sem uma senha, ele permanece `NOLOGIN`. O role
`analytics_sync_ro` pode ler as views
`public.dau_daily` e `public.dau_daily_by_user_type`, sem acesso à tabela
individual. As views omitem dias sem registros; relatórios por intervalo devem
gerar calendário e preencher esses dias com zero, distinguindo ausência de uso
de falhas de coleta conhecidas.

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
│   ├── monitoramento_dau.sql
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
