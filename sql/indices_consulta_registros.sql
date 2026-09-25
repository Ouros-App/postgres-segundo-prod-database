CREATE INDEX IF NOT EXISTS idx_farm_owners_id_password_email
    ON farm_owners (id, password, email);

CREATE INDEX IF NOT EXISTS idx_water_registries_id_hydrometers
    ON water_registries (id, start_hydrometer, end_hydrometer);

CREATE INDEX IF NOT EXISTS idx_energy_registries_id_consumption
    ON energy_registries (id, energy_consumption);
