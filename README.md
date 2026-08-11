# postgres segundo prod database

Template para banco PostgreSQL versionado por arquivos SQL locais.

## Estrutura

- `sql/`: arquivos SQL
- `scripts/apply_sql.py`: orquestrador local
- `config.yaml`: ordem de execucao e configuracao
- `.env.example`: variaveis sensiveis

## Execucao dos arquivos SQL

Registre os arquivos em `database.execution_order`, respeitando a ordem de dependencias:

```yaml
execution_order:
  - file: banco_ouros_fisico.sql
    mode: once
```

Modos disponiveis: `once` executa uma vez; `on_change` executa quando o conteudo mudar; `always` executa em toda execucao; `never` apenas valida o arquivo.

## Uso

```bash
pip install -r requirements.txt
python scripts/apply_sql.py
```
