CREATE TABLE IF NOT EXISTS device_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL CHECK (user_id > 0),
    user_role VARCHAR(50) NOT NULL CHECK (user_role IN ('FARM_OWNER', 'COMPANY_EMPLOYEE', 'ADM')),
    token VARCHAR(500) NOT NULL CHECK (btrim(token) <> ''),
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_device_tokens_token UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user 
    ON device_tokens (user_id, user_role);

CREATE INDEX IF NOT EXISTS idx_device_tokens_role
    ON device_tokens (user_role);

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL CHECK (user_id > 0),
    user_role VARCHAR(50) NOT NULL CHECK (user_role IN ('FARM_OWNER', 'COMPANY_EMPLOYEE', 'ADM')),
    title VARCHAR(150) NOT NULL CHECK (btrim(title) <> ''),
    message TEXT NOT NULL CHECK (btrim(message) <> ''),
    type VARCHAR(50) NOT NULL DEFAULT 'RANKING_UPDATED' CHECK (btrim(type) <> ''),
    id_tip INTEGER REFERENCES tips(id) ON DELETE SET NULL,
    data_payload TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    CONSTRAINT chk_notifications_read_at CHECK (read_at IS NULL OR read_at >= created_at)
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_notifications_user_lookup 
    ON notifications (user_id, user_role, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_tip 
    ON notifications (id_tip);

CREATE OR REPLACE FUNCTION update_device_tokens_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON device_tokens;

CREATE TRIGGER trg_device_tokens_updated_at
BEFORE UPDATE ON device_tokens
FOR EACH ROW
EXECUTE FUNCTION update_device_tokens_updated_at();
