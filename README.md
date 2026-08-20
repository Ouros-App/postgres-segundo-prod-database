# postgres-segundo-prod-database

Template para versionamento e aplicação de scripts SQL em PostgreSQL.

## Status e escopo

O repositório contém um executor local de SQL, arquivos SQL de versionamento e um esquema físico de banco. A configuração atual deixa `database.execution_order` vazia; portanto, o arquivo `sql/banco_ouros_fisico.sql` existe no repositório, mas não está incluído na ordem de execução até ser adicionado ao `config.yaml`.

A aplicação automática está definida em `.github/workflows/apply-sql-on-main.yml` e é disparada por push em `main`.

## Componentes

- `scripts/apply_sql.py`: carrega a configuração, expande variáveis de ambiente, garante o banco e o usuário proprietário, aplica o esquema de versionamento e executa os SQLs configurados.
- `config.yaml`: define PostgreSQL, caminhos, tabela de versões e a ordem dos SQLs.
- `sql/versionamento.sql`: cria a tabela `controle_versoes`.
- `sql/banco_ouros_fisico.sql`: cria tabelas relacionadas a endereços, empresas, fazendas, lotes, metas, planos de medicação e outras entidades do esquema físico.
- `.env.example`: lista as variáveis usadas pela configuração.
- `tests/test_apply_sql.py`: teste automatizado para carregamento da configuração.

O executor também mantém a tabela `controle_scripts_sql`, com checksum, commit e data de execução de cada arquivo processado.

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
    mode: once
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

O workflow `.github/workflows/ci-cd.yml` valida a presença do scaffold, verifica nomes de arquivos SQL configurados e bloqueia SQL contendo `TRUNCATE` ou `DROP DATABASE`, `DROP TABLE` e `DROP SCHEMA`.

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
