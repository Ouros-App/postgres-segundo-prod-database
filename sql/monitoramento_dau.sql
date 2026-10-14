-- Daily activity is recorded only when the authenticated backend calls this function.
-- Keep IDs as historical identity values; do not reuse account IDs after deletion.

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE TABLE IF NOT EXISTS public.user_daily_activity (
    activity_date DATE NOT NULL,
    user_type TEXT NOT NULL
        CHECK (user_type IN ('farm_owner', 'company_employee', 'adm')),
    user_id INTEGER NOT NULL CHECK (user_id > 0),
    first_recorded_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (activity_date, user_type, user_id)
);

COMMENT ON TABLE public.user_daily_activity IS
    'Uma linha por conta e dia de uso; activity_date segue America/Sao_Paulo.';
COMMENT ON COLUMN public.user_daily_activity.activity_date IS
    'Dia da atividade calculado no fuso America/Sao_Paulo.';
COMMENT ON COLUMN public.user_daily_activity.user_type IS
    'Tipo de conta local: farm_owner, company_employee ou adm.';
COMMENT ON COLUMN public.user_daily_activity.user_id IS
    'ID da conta no cadastro correspondente; não deve ser reutilizado após exclusão.';
COMMENT ON COLUMN public.user_daily_activity.first_recorded_at IS
    'Instante do primeiro registro confirmado para a conta naquele dia.';

CREATE OR REPLACE FUNCTION public.record_daily_activity(
    p_user_type TEXT,
    p_user_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $function$
DECLARE
    v_recorded_at TIMESTAMPTZ;
    v_activity_date DATE;
    v_inserted_rows INTEGER;
BEGIN
    IF p_user_type IS NULL
       OR p_user_type NOT IN ('farm_owner', 'company_employee', 'adm') THEN
        RAISE EXCEPTION 'Tipo de usuário inválido: %', p_user_type
            USING ERRCODE = '22023';
    END IF;

    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        RAISE EXCEPTION 'ID de usuário deve ser positivo'
            USING ERRCODE = '22023';
    END IF;

    IF p_user_type = 'farm_owner' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.farm_owners AS account WHERE account.id = p_user_id
        ) THEN
            RAISE EXCEPTION 'Conta de usuário inexistente'
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_user_type = 'company_employee' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.company_employees AS account WHERE account.id = p_user_id
        ) THEN
            RAISE EXCEPTION 'Conta de usuário inexistente'
                USING ERRCODE = '22023';
        END IF;
    ELSIF NOT EXISTS (
        SELECT 1 FROM public.adms AS account WHERE account.id = p_user_id
    ) THEN
        RAISE EXCEPTION 'Conta de usuário inexistente'
            USING ERRCODE = '22023';
    END IF;

    v_recorded_at := pg_catalog.clock_timestamp();
    v_activity_date := (v_recorded_at AT TIME ZONE 'America/Sao_Paulo')::DATE;

    INSERT INTO public.user_daily_activity (
        activity_date, user_type, user_id, first_recorded_at
    )
    VALUES (v_activity_date, p_user_type, p_user_id, v_recorded_at)
    ON CONFLICT (activity_date, user_type, user_id) DO NOTHING;

    GET DIAGNOSTICS v_inserted_rows = ROW_COUNT;
    RETURN v_inserted_rows = 1;
END;
$function$;

COMMENT ON FUNCTION public.record_daily_activity(TEXT, INTEGER) IS
    'Valida uma conta e registra uma única atividade diária usando America/Sao_Paulo; retorna true somente no primeiro registro do dia.';

CREATE OR REPLACE VIEW public.dau_daily AS
SELECT activity_date, COUNT(*)::BIGINT AS active_users
FROM public.user_daily_activity
GROUP BY activity_date;

COMMENT ON VIEW public.dau_daily IS
    'Contagem diária de contas ativas registradas; dias sem linhas não aparecem.';

CREATE OR REPLACE VIEW public.dau_daily_by_user_type AS
SELECT activity_date, user_type, COUNT(*)::BIGINT AS active_users
FROM public.user_daily_activity
GROUP BY activity_date, user_type;

COMMENT ON VIEW public.dau_daily_by_user_type IS
    'Contagem diária de contas ativas por tipo; dias sem linhas não aparecem.';

REVOKE ALL PRIVILEGES ON SCHEMA public FROM activity_recorder;
GRANT USAGE ON SCHEMA public TO activity_recorder;

REVOKE ALL PRIVILEGES ON TABLE
    public.user_daily_activity,
    public.farm_owners,
    public.company_employees,
    public.adms
FROM activity_recorder;

REVOKE ALL PRIVILEGES ON FUNCTION public.record_daily_activity(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.record_daily_activity(TEXT, INTEGER) FROM activity_recorder;
GRANT EXECUTE ON FUNCTION public.record_daily_activity(TEXT, INTEGER) TO activity_recorder;
