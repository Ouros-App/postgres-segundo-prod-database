# postgres segundo prod database

Template para banco PostgreSQL versionado por arquivos SQL locais.

## Estrutura

- `sql/`: arquivos SQL
- `scripts/apply_sql.py`: orquestrador local
- `config.yaml`: ordem de execucao e configuracao
- `.env.example`: variaveis sensiveis

## Uso

```bash
pip install -r requirements.txt
python scripts/apply_sql.py
```
