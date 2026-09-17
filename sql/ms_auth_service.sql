DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'ms_auth_service_ro'
    ) THEN
        CREATE ROLE ms_auth_service_ro
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

ALTER ROLE ms_auth_service_ro
    LOGIN
    NOINHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 5
    PASSWORD ${MS_AUTH_SERVICE_PASSWORD};

DO $$
BEGIN
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO ms_auth_service_ro',
        current_database()
    );
END
$$;

ALTER ROLE ms_auth_service_ro SET default_transaction_read_only = on;
ALTER ROLE ms_auth_service_ro SET search_path = public, pg_catalog;

REVOKE ALL PRIVILEGES ON SCHEMA public FROM ms_auth_service_ro;
GRANT USAGE ON SCHEMA public TO ms_auth_service_ro;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ms_auth_service_ro;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM ms_auth_service_ro;
GRANT SELECT ON TABLE
    public.farm_owners,
    public.company_employees,
    public.adms
TO ms_auth_service_ro;

-- Future writes must target only keycloak_user_id on the three tables.
