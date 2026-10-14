CREATE TABLE IF NOT EXISTS device_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    user_role VARCHAR(50) NOT NULL,
    token VARCHAR(500) NOT NULL,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_device_tokens_token UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user 
    ON device_tokens (user_id, user_role);

CREATE INDEX IF NOT EXISTS idx_device_tokens_role_user 
    ON device_tokens (user_role, user_id);

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    user_role VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL CHECK (btrim(title) <> ''),
    message TEXT NOT NULL CHECK (btrim(message) <> ''),
    type VARCHAR(50) NOT NULL DEFAULT 'RANKING_UPDATED',
    id_tip INTEGER REFERENCES tips(id) ON DELETE SET NULL,
    data_payload TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP WITHOUT TIME ZONE NULL
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_notifications_user_lookup 
    ON notifications (user_id, user_role, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_tip 
    ON notifications (id_tip);
