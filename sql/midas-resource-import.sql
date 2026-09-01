-- Importacao historica controlada pelo MCP (contrato v1, all_or_nothing).
-- Unidades: agua em m3 (leituras cumulativas); energia em kWh; data sem fuso.

CREATE SCHEMA IF NOT EXISTS midas;
DO $$ DECLARE v_schema TEXT; BEGIN
    SELECT n.nspname INTO v_schema FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pgcrypto';
    IF v_schema IS NOT NULL AND v_schema <> 'midas' THEN
        RAISE EXCEPTION 'pgcrypto is installed in schema %, move it to midas before this migration', v_schema;
    END IF;
END $$;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA midas;

CREATE TABLE IF NOT EXISTS midas.resource_import_requests (
    request_id UUID PRIMARY KEY,
    actor_user_type TEXT NOT NULL,
    actor_user_id BIGINT NOT NULL,
    source_type TEXT NOT NULL,
    source_name TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
    status TEXT NOT NULL CHECK (status IN ('accepted', 'rejected')),
    received_count INTEGER NOT NULL CHECK (received_count >= 0),
    inserted_count INTEGER NOT NULL CHECK (inserted_count >= 0),
    skipped_duplicates INTEGER NOT NULL CHECK (skipped_duplicates >= 0),
    rejected_count INTEGER NOT NULL CHECK (rejected_count >= 0),
    errors JSONB NOT NULL DEFAULT '[]'::JSONB,
    schema_version TEXT NOT NULL DEFAULT 'resource-import-v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS midas.importer_identities (
    database_role NAME PRIMARY KEY,
    farm_owner_id BIGINT NOT NULL REFERENCES public.farm_owners(id),
    CHECK (database_role <> 'public'::NAME)
);

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM public.water_registries GROUP BY id_farm, registration_date, start_hydrometer, end_hydrometer HAVING count(*) > 1)
       OR EXISTS (SELECT 1 FROM public.energy_registries GROUP BY id_farm, registration_date, energy_consumption HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'duplicate legacy resource records require DBA review';
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS water_registries_import_natural_key
    ON public.water_registries (id_farm, registration_date, start_hydrometer, end_hydrometer);
CREATE UNIQUE INDEX IF NOT EXISTS energy_registries_import_natural_key
    ON public.energy_registries (id_farm, registration_date, energy_consumption);

CREATE OR REPLACE FUNCTION midas.import_resource_records(
    p_request_id UUID, p_actor_user_type TEXT, p_actor_user_id BIGINT,
    p_source_type TEXT, p_source_name TEXT, p_records JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = midas, pg_catalog
AS $$
DECLARE
    v_farm_id INTEGER;
    v_item JSONB;
    v_index INTEGER;
    v_resource TEXT;
    v_date DATE;
    v_start NUMERIC;
    v_end NUMERIC;
    v_energy NUMERIC;
    v_errors JSONB := '[]'::JSONB;
    v_count INTEGER := 0;
    v_inserted INTEGER := 0;
    v_skipped INTEGER := 0;
    v_existing JSONB;
BEGIN
    IF p_request_id IS NULL OR p_actor_user_type IS DISTINCT FROM 'farm_owner'
       OR p_actor_user_id IS NULL OR p_source_type IS NULL OR btrim(p_source_type) = ''
       OR p_source_name IS NULL OR btrim(p_source_name) = ''
       OR jsonb_typeof(p_records) <> 'array' THEN
        RAISE EXCEPTION 'invalid import request';
    END IF;
    IF pg_column_size(p_records) > 1048576 OR jsonb_array_length(p_records) > 1000 THEN
        RAISE EXCEPTION 'import limits exceeded';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::TEXT, 0));
    SELECT jsonb_build_object('request_id', r.request_id, 'status', r.status,
        'inserted', r.inserted_count, 'skipped_duplicates', r.skipped_duplicates,
        'rejected', r.rejected_count, 'errors', r.errors)
      INTO v_existing FROM midas.resource_import_requests r WHERE r.request_id = p_request_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;

    SELECT farm_owner_id INTO p_actor_user_id FROM midas.importer_identities WHERE database_role = session_user;
    IF p_actor_user_id IS NULL THEN RAISE EXCEPTION 'authenticated actor is required'; END IF;
    SELECT id_farm INTO v_farm_id FROM public.farm_owners WHERE id = p_actor_user_id FOR SHARE;
    IF v_farm_id IS NULL THEN RAISE EXCEPTION 'farm owner not found'; END IF;

    BEGIN
      FOR v_item, v_index IN SELECT value, ordinality::INTEGER FROM jsonb_array_elements(p_records) WITH ORDINALITY LOOP
        v_count := v_count + 1;
        v_resource := v_item->>'resource_type';
        BEGIN
            IF jsonb_typeof(v_item) <> 'object' OR v_resource IS NULL OR v_resource NOT IN ('water', 'energy')
               OR (SELECT count(*) FROM jsonb_object_keys(v_item)) <> 8
               OR (v_item - 'resource_type' - 'farm_id' - 'registration_date' - 'start_hydrometer'
                   - 'end_hydrometer' - 'energy_consumption' - 'source_row' - 'confidence') <> '{}'::JSONB
               OR (v_item->>'farm_id')::INTEGER IS DISTINCT FROM v_farm_id THEN
                RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'INVALID_VALUE';
            END IF;
            v_date := (v_item->>'registration_date')::DATE;
            IF v_resource = 'water' THEN
                v_start := (v_item->>'start_hydrometer')::NUMERIC;
                v_end := (v_item->>'end_hydrometer')::NUMERIC;
                IF v_start <= 0 OR v_end <= 0 OR v_end < v_start THEN RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'INVALID_VALUE'; END IF;
                INSERT INTO public.water_registries (registration_date, start_hydrometer, end_hydrometer, id_farm)
                VALUES (v_date, v_start, v_end, v_farm_id) ON CONFLICT DO NOTHING;
            ELSE
                v_energy := (v_item->>'energy_consumption')::NUMERIC;
                IF v_energy <= 0 THEN RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'INVALID_VALUE'; END IF;
                INSERT INTO public.energy_registries (registration_date, energy_consumption, id_farm)
                VALUES (v_date, v_energy, v_farm_id) ON CONFLICT DO NOTHING;
            END IF;
            IF FOUND THEN v_inserted := v_inserted + 1; ELSE v_skipped := v_skipped + 1; END IF;
        EXCEPTION WHEN SQLSTATE 'P0002' THEN
            v_errors := v_errors || jsonb_build_array(jsonb_build_object('index', v_index - 1, 'code', 'INVALID_VALUE', 'message', 'registro invalido'));
        END;
      END LOOP;
    IF jsonb_array_length(v_errors) > 0 THEN
        RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'invalid records';
    END IF;
    EXCEPTION WHEN SQLSTATE 'P0001' THEN
        v_existing := jsonb_build_object('request_id', p_request_id, 'status', 'rejected',
            'inserted', 0, 'skipped_duplicates', 0, 'rejected', v_count, 'errors', v_errors);
        INSERT INTO midas.resource_import_requests
            (request_id, actor_user_type, actor_user_id, source_type, source_name, payload_sha256,
             status, received_count, inserted_count, skipped_duplicates, rejected_count, errors)
        VALUES (p_request_id, p_actor_user_type, p_actor_user_id, p_source_type, p_source_name,
            encode(midas.digest(p_records::TEXT, 'sha256'), 'hex'), 'rejected', v_count, 0, 0, v_count, v_errors);
        RETURN v_existing;
    WHEN OTHERS THEN
        RAISE;
    END;
    v_existing := jsonb_build_object('request_id', p_request_id, 'status', 'accepted', 'inserted', v_inserted,
        'skipped_duplicates', v_skipped, 'rejected', 0, 'errors', '[]'::JSONB);
    INSERT INTO midas.resource_import_requests
        (request_id, actor_user_type, actor_user_id, source_type, source_name, payload_sha256,
         status, received_count, inserted_count, skipped_duplicates, rejected_count, errors)
    VALUES (p_request_id, p_actor_user_type, p_actor_user_id, p_source_type, p_source_name,
        encode(digest(p_records::TEXT, 'sha256'), 'hex'), 'accepted', v_count, v_inserted, v_skipped, 0, '[]'::JSONB);
    RETURN v_existing;
END;
$$;

COMMENT ON FUNCTION midas.import_resource_records(UUID, TEXT, BIGINT, TEXT, TEXT, JSONB)
    IS 'MCP-only historical water/energy import; v1 all_or_nothing, farm_owner scoped, idempotent.';

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'midas_importer') THEN
        CREATE ROLE midas_importer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
END $$;
REVOKE ALL ON FUNCTION midas.import_resource_records(UUID, TEXT, BIGINT, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT USAGE ON SCHEMA midas TO midas_importer;
GRANT EXECUTE ON FUNCTION midas.import_resource_records(UUID, TEXT, BIGINT, TEXT, TEXT, JSONB) TO midas_importer;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM midas_importer;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM midas_importer;
