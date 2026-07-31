# DB Postgres

Template para banco PostgreSQL versionado por arquivos SQL locais.

O diretorio `sql/` guarda os arquivos SQL. A ordem de execucao fica em `config.yaml`. O Python so orquestra: garante banco e role, executa os SQL e grava a versao atual do banco com commit e comentario.

O script e Python puro. Roda do mesmo jeito em Windows e Linux, sem depender de bash.

## Uso

Linux:

```bash
cp .env.example .env
pip install -r requirements.txt
python scripts/apply_sql.py
```

Windows:

```powershell
Copy-Item .env.example .env
pip install -r requirements.txt
python scripts\apply_sql.py
```

## GitHub Actions

O repositorio tem duas pipelines:

- `CI/CD`: roda em pull request e push na `main`, instala dependencias, executa os testes e valida `config.yaml`, `scripts/apply_sql.py` e os arquivos de `sql/`.
- `Apply SQL On Main`: roda apenas em push na `main`, instala dependencias e executa `python scripts/apply_sql.py`.

## Secrets do GitHub

A pipeline `Apply SQL On Main` nao usa `.env`. Os valores abaixo devem existir em `Settings > Secrets and variables > Actions` do repositorio:

| Secret | Uso |
| --- | --- |
| `POSTGRES_HOST` | host do PostgreSQL |
| `POSTGRES_PORT` | porta do PostgreSQL |
| `POSTGRES_DB` | banco da aplicacao |
| `POSTGRES_USER` | usuario dono da aplicacao |
| `POSTGRES_PASSWORD` | senha do usuario dono |
| `POSTGRES_ROOT_DB` | banco bootstrap usado para conectar antes de criar o alvo |
| `POSTGRES_ROOT_USER` | usuario com permissao para criar role e banco |
| `POSTGRES_ROOT_PASSWORD` | senha do usuario bootstrap |

## Como funciona

1. `scripts/apply_sql.py` carrega `.env` e `config.yaml`.
2. No GitHub Actions, as mesmas variaveis vem dos secrets do repositorio.
3. Se faltar, cria usuario e banco usando `POSTGRES_ROOT_DB` e `POSTGRES_ROOT_USER`.
4. Executa os SQL na ordem definida em `database.execution_order`.
5. Usa `database.version_schema_file` para garantir a tabela de versionamento.
6. Grava `versao`, `commit_id`, `comentario_commit` e `aplicado_em`.
7. Toda execucao gera uma nova linha de versao.

## Configuracao

```yaml
database:
  sql_path: sql
  version_table: controle_versoes
  version_schema_file: versionamento.sql
  execution_order:
    - versionamento.sql
```

## Query da versao atual

```sql
SELECT versao, commit_id, comentario_commit, aplicado_em
FROM controle_versoes
ORDER BY versao DESC
LIMIT 1;
```

## Estrutura esperada

```text
db-postgres/
|- sql/
|  |- versionamento.sql
|- scripts/
|  |- apply_sql.py
|- config.yaml
|- .env.example
|- .env
`- requirements.txt
```
