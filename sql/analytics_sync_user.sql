-- Role-level provisioning is handled by scripts/apply_sql.py with bootstrap credentials.
-- This migration is intentionally limited to privileges owned by the application DB owner.

REVOKE ALL PRIVILEGES ON SCHEMA public FROM analytics_sync_ro;
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
