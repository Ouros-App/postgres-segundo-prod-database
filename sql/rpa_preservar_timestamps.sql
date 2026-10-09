-- Rebuild the Midas views so PostgreSQL can change the underlying column types.
DROP VIEW IF EXISTS midas.water_registries;
DROP VIEW IF EXISTS midas.energy_registries;

ALTER TABLE water_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP
    USING registration_date::TIMESTAMP;

ALTER TABLE energy_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP
    USING registration_date::TIMESTAMP;

CREATE VIEW midas.water_registries AS
SELECT * FROM public.water_registries;

CREATE VIEW midas.energy_registries AS
SELECT * FROM public.energy_registries;

REVOKE ALL PRIVILEGES ON TABLE midas.water_registries, midas.energy_registries FROM PUBLIC;
GRANT SELECT ON TABLE midas.water_registries, midas.energy_registries TO midas_ro;
