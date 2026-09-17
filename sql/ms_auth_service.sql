-- Role-level provisioning is handled by scripts/apply_sql.py with bootstrap credentials.
-- This migration only grants the read-only table access required by ms-auth-service.

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
