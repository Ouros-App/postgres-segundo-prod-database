-- Transitional identity link for the Keycloak migration.
--
-- Authentication remains on the existing login flow for now. These nullable
-- columns only establish a stable mapping between the Keycloak `sub` claim
-- (UUID) and the existing Ouros domain users.

ALTER TABLE farm_owners
    ADD COLUMN IF NOT EXISTS keycloak_user_id UUID;

ALTER TABLE company_employees
    ADD COLUMN IF NOT EXISTS keycloak_user_id UUID;

ALTER TABLE adms
    ADD COLUMN IF NOT EXISTS keycloak_user_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS ux_farm_owners_keycloak_user_id
    ON farm_owners (keycloak_user_id)
    WHERE keycloak_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_company_employees_keycloak_user_id
    ON company_employees (keycloak_user_id)
    WHERE keycloak_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_adms_keycloak_user_id
    ON adms (keycloak_user_id)
    WHERE keycloak_user_id IS NOT NULL;

COMMENT ON COLUMN farm_owners.keycloak_user_id IS
    'Keycloak user UUID from the OIDC sub claim. Nullable during migration.';
COMMENT ON COLUMN company_employees.keycloak_user_id IS
    'Keycloak user UUID from the OIDC sub claim. Nullable during migration.';
COMMENT ON COLUMN adms.keycloak_user_id IS
    'Keycloak user UUID from the OIDC sub claim. Nullable during migration.';
