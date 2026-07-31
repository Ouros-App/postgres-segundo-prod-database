CREATE TABLE IF NOT EXISTS controle_versoes (
    id SERIAL PRIMARY KEY,
    versao INTEGER UNIQUE NOT NULL,
    commit_id VARCHAR(64) NOT NULL,
    comentario_commit TEXT NOT NULL,
    aplicado_em TIMESTAMP DEFAULT NOW()
);
