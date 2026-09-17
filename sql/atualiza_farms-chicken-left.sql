ALTER TABLE farms
    ADD COLUMN IF NOT EXISTS chickens_now INTEGER NOT NULL DEFAULT 0
        CHECK (chickens_now >= 0),
    ADD COLUMN IF NOT EXISTS foto_url TEXT;

ALTER TABLE farm_owners
    ADD COLUMN IF NOT EXISTS foto_url TEXT;

CREATE TABLE IF NOT EXISTS chicken_left (
    id SERIAL PRIMARY KEY,
    chickens_count INTEGER NOT NULL
        CHECK (chickens_count > 0),
    exit_date DATE NOT NULL,
    id_farm INTEGER NOT NULL
        REFERENCES farms(id)
);
