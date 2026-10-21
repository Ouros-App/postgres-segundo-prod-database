CREATE TABLE IF NOT EXISTS public.database_role_daily_activity (
    activity_date DATE NOT NULL,
    database_role TEXT NOT NULL CHECK (btrim(database_role) <> ''),
    first_recorded_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (activity_date, database_role)
);

CREATE TABLE IF NOT EXISTS public.database_write_events (
    event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_at TIMESTAMPTZ NOT NULL,
    activity_date DATE NOT NULL,
    database_user TEXT NOT NULL CHECK (btrim(database_user) <> ''),
    table_schema TEXT NOT NULL,
    table_name TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'))
);

CREATE INDEX IF NOT EXISTS database_write_events_event_at_event_id_idx
    ON public.database_write_events (event_at DESC, event_id DESC);

CREATE OR REPLACE FUNCTION public.capture_database_write_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $function$
DECLARE
    v_recorded_at TIMESTAMPTZ;
BEGIN
    v_recorded_at := pg_catalog.clock_timestamp();

    INSERT INTO public.database_write_events (
        event_at,
        activity_date,
        database_user,
        table_schema,
        table_name,
        action
    )
    VALUES (
        v_recorded_at,
        (v_recorded_at AT TIME ZONE 'America/Sao_Paulo')::DATE,
        session_user::TEXT,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP
    );

    DELETE FROM public.database_write_events AS logged_event
    WHERE logged_event.event_id IN (
        SELECT event_id
        FROM public.database_write_events
        ORDER BY event_at DESC, event_id DESC
        OFFSET 25000
    );

    INSERT INTO public.database_role_daily_activity (
        activity_date,
        database_role,
        first_recorded_at
    )
    VALUES (
        (v_recorded_at AT TIME ZONE 'America/Sao_Paulo')::DATE,
        session_user::TEXT,
        v_recorded_at
    )
    ON CONFLICT (activity_date, database_role) DO NOTHING;

    RETURN NULL;
END;
$function$;

DELETE FROM public.database_write_events AS logged_event
WHERE logged_event.event_id IN (
    SELECT event_id
    FROM public.database_write_events
    ORDER BY event_at DESC, event_id DESC
    OFFSET 25000
);

REVOKE ALL PRIVILEGES ON FUNCTION public.capture_database_write_activity() FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.database_role_daily_activity FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE public.database_write_events FROM PUBLIC;

DROP FUNCTION IF EXISTS public.record_daily_activity(TEXT, INTEGER);
DROP VIEW IF EXISTS public.dau_daily_by_user_type;

CREATE OR REPLACE VIEW public.dau_daily AS
SELECT activity_date, COUNT(*)::BIGINT AS active_database_roles
FROM public.database_role_daily_activity
GROUP BY activity_date;

CREATE OR REPLACE VIEW public.dau_daily_by_database_role AS
SELECT activity_date, database_role, first_recorded_at
FROM public.database_role_daily_activity;

CREATE OR REPLACE VIEW public.database_write_activity_log AS
SELECT
    event_id,
    event_at,
    activity_date,
    database_user,
    table_schema,
    table_name,
    action
FROM public.database_write_events;

GRANT SELECT ON TABLE
    public.dau_daily,
    public.dau_daily_by_database_role,
    public.database_write_activity_log
TO analytics_sync_ro;

DO $do$
DECLARE
    v_table RECORD;
    v_trigger_name CONSTANT TEXT := 'trg_capture_database_write_activity';
BEGIN
    FOR v_table IN
        SELECT c.relname
        FROM pg_catalog.pg_class AS c
        JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p')
          AND c.relname NOT IN (
              'database_role_daily_activity',
              'database_write_events',
              'user_daily_activity',
              'controle_versoes'
          )
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_trigger AS t
            WHERE t.tgrelid = pg_catalog.to_regclass(
                pg_catalog.format('%I.%I', 'public', v_table.relname)
            )
              AND t.tgname = v_trigger_name
              AND NOT t.tgisinternal
        ) THEN
            EXECUTE pg_catalog.format(
                'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON %I.%I FOR EACH STATEMENT EXECUTE FUNCTION public.capture_database_write_activity()',
                v_trigger_name,
                'public',
                v_table.relname
            );
        END IF;
    END LOOP;
END;
$do$;

