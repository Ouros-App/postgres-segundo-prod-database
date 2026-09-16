DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'analytics_sync_ro'
    ) THEN
        CREATE ROLE analytics_sync_ro
            LOGIN
            NOINHERIT
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS
            CONNECTION LIMIT 3;
    END IF;
END
$$;

ALTER ROLE analytics_sync_ro
    LOGIN
    NOINHERIT
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 3;

ALTER ROLE analytics_sync_ro SET default_transaction_read_only = on;
ALTER ROLE analytics_sync_ro SET search_path = public, pg_catalog;

GRANT USAGE ON SCHEMA public TO analytics_sync_ro;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM analytics_sync_ro;
GRANT SELECT ON TABLE
    public.addresses,
    public.enterprises,
    public.farms,
    public.lots,
    public.water_registries,
    public.energy_registries,
    public.plans,
    public.enterprise_plans,
    public.payments,
    public.individual_goals,
    public.state_goals,
    public.regions_goals,
    public.farm_goals,
    public.state_goal_regions,
    public.tips,
    public.categories,
    public.tip_categories,
    public.reviews
TO analytics_sync_ro;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM analytics_sync_ro;
