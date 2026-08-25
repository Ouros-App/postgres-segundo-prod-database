DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'midas_ro'
    ) THEN
        CREATE ROLE midas_ro
            LOGIN
            NOINHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT 5;
    END IF;
END
$$;

ALTER ROLE midas_ro
    LOGIN
    NOINHERIT
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 5;

ALTER ROLE midas_ro SET default_transaction_read_only = on;
ALTER ROLE midas_ro SET search_path = midas, pg_catalog;

CREATE SCHEMA IF NOT EXISTS midas;

REVOKE ALL PRIVILEGES ON SCHEMA midas FROM PUBLIC;
GRANT USAGE ON SCHEMA midas TO midas_ro;

REVOKE ALL PRIVILEGES
    ON ALL TABLES IN SCHEMA public
    FROM midas_ro;

REVOKE ALL PRIVILEGES
    ON ALL SEQUENCES IN SCHEMA public
    FROM midas_ro;

CREATE OR REPLACE VIEW midas.addresses AS
SELECT * FROM public.addresses;

CREATE OR REPLACE VIEW midas.enterprises AS
SELECT * FROM public.enterprises;

CREATE OR REPLACE VIEW midas.farms AS
SELECT * FROM public.farms;

CREATE OR REPLACE VIEW midas.tips AS
SELECT * FROM public.tips;

CREATE OR REPLACE VIEW midas.categories AS
SELECT * FROM public.categories;

CREATE OR REPLACE VIEW midas.reviews AS
SELECT * FROM public.reviews;

CREATE OR REPLACE VIEW midas.farm_owners AS
SELECT
    id,
    name,
    email,
    document_number,
    telephone,
    id_farm
FROM public.farm_owners;

CREATE OR REPLACE VIEW midas.individual_goals AS
SELECT * FROM public.individual_goals;

CREATE OR REPLACE VIEW midas.water_registries AS
SELECT * FROM public.water_registries;

CREATE OR REPLACE VIEW midas.energy_registries AS
SELECT * FROM public.energy_registries;

CREATE OR REPLACE VIEW midas.lots AS
SELECT * FROM public.lots;

CREATE OR REPLACE VIEW midas.company_employees AS
SELECT
    id,
    name,
    document_number,
    email,
    telephone,
    id_enterprise
FROM public.company_employees;

CREATE OR REPLACE VIEW midas.adms AS
SELECT
    id,
    email
FROM public.adms;

CREATE OR REPLACE VIEW midas.state_goals AS
SELECT * FROM public.state_goals;

CREATE OR REPLACE VIEW midas.regions_goals AS
SELECT * FROM public.regions_goals;

CREATE OR REPLACE VIEW midas.farm_goals AS
SELECT * FROM public.farm_goals;

CREATE OR REPLACE VIEW midas.tip_categories AS
SELECT * FROM public.tip_categories;

CREATE OR REPLACE VIEW midas.state_goal_regions AS
SELECT * FROM public.state_goal_regions;

CREATE OR REPLACE VIEW midas.farms_tips AS
SELECT * FROM public.farms_tips;

REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA midas FROM PUBLIC;

GRANT SELECT
    ON ALL TABLES IN SCHEMA midas
    TO midas_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA midas
    REVOKE ALL ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA midas
    GRANT SELECT ON TABLES TO midas_ro;
