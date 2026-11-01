-- Views analíticas mensais. Os cadastros de empresa e região refletem o estado atual.

CREATE OR REPLACE VIEW public.water_monthly AS
WITH monthly_water AS (
    SELECT
        w.id_farm,
        date_trunc('month', w.registration_date)::date AS month,
        SUM(w.end_hydrometer - w.start_hydrometer)::numeric AS water_consumed
    FROM public.water_registries AS w
    WHERE w.registration_date < date_trunc('month', CURRENT_DATE)
    GROUP BY w.id_farm, date_trunc('month', w.registration_date)::date
),
farm_months AS (
    SELECT
        mw.id_farm,
        f.id_enterprise,
        f.region,
        mw.month,
        mw.water_consumed
    FROM monthly_water AS mw
    JOIN public.farms AS f ON f.id = mw.id_farm
),
windowed AS (
    SELECT
        fm.id_farm,
        fm.id_enterprise,
        fm.region,
        fm.month,
        fm.water_consumed,
        SUM(fm.water_consumed) OVER (
            PARTITION BY fm.id_farm, date_trunc('year', fm.month)
            ORDER BY fm.month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS water_consumed_ytd,
        LAG(fm.month) OVER (
            PARTITION BY fm.id_farm ORDER BY fm.month
        ) AS previous_month,
        LAG(fm.water_consumed) OVER (
            PARTITION BY fm.id_farm ORDER BY fm.month
        ) AS previous_water_consumed
    FROM farm_months AS fm
),
compared AS (
    SELECT
        w.id_farm,
        w.id_enterprise,
        w.region,
        w.month,
        w.water_consumed,
        w.water_consumed_ytd,
        CASE
            WHEN w.previous_month = (w.month - INTERVAL '1 month')::date
                THEN w.previous_water_consumed
            ELSE NULL
        END AS previous_month_water_consumed
    FROM windowed AS w
)
SELECT
    id_farm,
    id_enterprise,
    region,
    month,
    water_consumed,
    water_consumed_ytd,
    previous_month_water_consumed
FROM compared;

COMMENT ON VIEW public.water_monthly IS
    'Consumo mensal de água por granja, apenas para meses encerrados.';

CREATE OR REPLACE VIEW public.energy_monthly AS
WITH monthly_energy AS (
    SELECT
        e.id_farm,
        date_trunc('month', e.registration_date)::date AS month,
        SUM(e.energy_consumption)::numeric AS energy_consumed
    FROM public.energy_registries AS e
    WHERE e.registration_date < date_trunc('month', CURRENT_DATE)
    GROUP BY e.id_farm, date_trunc('month', e.registration_date)::date
),
farm_months AS (
    SELECT
        me.id_farm,
        f.id_enterprise,
        f.region,
        me.month,
        me.energy_consumed
    FROM monthly_energy AS me
    JOIN public.farms AS f ON f.id = me.id_farm
),
windowed AS (
    SELECT
        fm.id_farm,
        fm.id_enterprise,
        fm.region,
        fm.month,
        fm.energy_consumed,
        SUM(fm.energy_consumed) OVER (
            PARTITION BY fm.id_farm, date_trunc('year', fm.month)
            ORDER BY fm.month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS energy_consumed_ytd,
        LAG(fm.month) OVER (
            PARTITION BY fm.id_farm ORDER BY fm.month
        ) AS previous_month,
        LAG(fm.energy_consumed) OVER (
            PARTITION BY fm.id_farm ORDER BY fm.month
        ) AS previous_energy_consumed
    FROM farm_months AS fm
),
compared AS (
    SELECT
        e.id_farm,
        e.id_enterprise,
        e.region,
        e.month,
        e.energy_consumed,
        e.energy_consumed_ytd,
        CASE
            WHEN e.previous_month = (e.month - INTERVAL '1 month')::date
                THEN e.previous_energy_consumed
            ELSE NULL
        END AS previous_month_energy_consumed
    FROM windowed AS e
)
SELECT
    id_farm,
    id_enterprise,
    region,
    month,
    energy_consumed,
    energy_consumed_ytd,
    previous_month_energy_consumed
FROM compared;

COMMENT ON VIEW public.energy_monthly IS
    'Consumo mensal de energia por granja, apenas para meses encerrados.';

CREATE OR REPLACE VIEW public.integrated_monthly AS
WITH monthly_water AS (
    SELECT
        w.id_farm,
        date_trunc('month', w.registration_date)::date AS month,
        SUM(w.end_hydrometer - w.start_hydrometer)::numeric AS water_consumed,
        COUNT(*)::bigint AS water_registry_count
    FROM public.water_registries AS w
    WHERE w.registration_date < date_trunc('month', CURRENT_DATE)
    GROUP BY w.id_farm, date_trunc('month', w.registration_date)::date
),
monthly_energy AS (
    SELECT
        e.id_farm,
        date_trunc('month', e.registration_date)::date AS month,
        SUM(e.energy_consumption)::numeric AS energy_consumed,
        COUNT(*)::bigint AS energy_registry_count
    FROM public.energy_registries AS e
    WHERE e.registration_date < date_trunc('month', CURRENT_DATE)
    GROUP BY e.id_farm, date_trunc('month', e.registration_date)::date
),
resource_months AS (
    SELECT
        COALESCE(w.id_farm, e.id_farm) AS id_farm,
        COALESCE(w.month, e.month) AS month,
        w.water_consumed,
        e.energy_consumed,
        COALESCE(w.water_registry_count, 0)::bigint AS water_registry_count,
        COALESCE(e.energy_registry_count, 0)::bigint AS energy_registry_count
    FROM monthly_water AS w
    FULL OUTER JOIN monthly_energy AS e
        ON e.id_farm = w.id_farm AND e.month = w.month
),
farm_months AS (
    SELECT
        rm.id_farm,
        f.id_enterprise,
        f.region,
        rm.month,
        rm.water_consumed,
        rm.energy_consumed,
        rm.water_registry_count,
        rm.energy_registry_count
    FROM resource_months AS rm
    JOIN public.farms AS f ON f.id = rm.id_farm
),
windowed AS (
    SELECT
        fm.id_farm,
        fm.id_enterprise,
        fm.region,
        fm.month,
        fm.water_consumed,
        fm.energy_consumed,
        fm.water_registry_count > 0 AS has_water_data,
        fm.energy_registry_count > 0 AS has_energy_data,
        fm.water_registry_count,
        fm.energy_registry_count,
        SUM(fm.water_consumed) OVER (
            PARTITION BY fm.id_enterprise, fm.month
        ) AS enterprise_month_water_consumed,
        SUM(fm.energy_consumed) OVER (
            PARTITION BY fm.id_enterprise, fm.month
        ) AS enterprise_month_energy_consumed
    FROM farm_months AS fm
),
shares AS (
    SELECT
        w.id_farm,
        w.id_enterprise,
        w.region,
        w.month,
        w.water_consumed,
        w.energy_consumed,
        w.has_water_data,
        w.has_energy_data,
        w.water_registry_count,
        w.energy_registry_count,
        w.enterprise_month_water_consumed,
        w.enterprise_month_energy_consumed,
        100::numeric * w.water_consumed
            / NULLIF(w.enterprise_month_water_consumed, 0) AS water_share_pct,
        100::numeric * w.energy_consumed
            / NULLIF(w.enterprise_month_energy_consumed, 0) AS energy_share_pct
    FROM windowed AS w
)
SELECT
    id_farm,
    id_enterprise,
    region,
    month,
    water_consumed,
    energy_consumed,
    has_water_data,
    has_energy_data,
    water_registry_count,
    energy_registry_count,
    enterprise_month_water_consumed,
    enterprise_month_energy_consumed,
    water_share_pct,
    energy_share_pct
FROM shares;

COMMENT ON VIEW public.integrated_monthly IS
    'Água e energia mensais por granja e mês com ao menos um recurso registrado; recursos ausentes ficam NULL.';

CREATE OR REPLACE VIEW public.goals_progress AS
WITH goals AS (
    SELECT ig.id_farm, ig.status
    FROM public.individual_goals AS ig

    UNION ALL

    SELECT fg.id_farm, fg.status
    FROM public.farm_goals AS fg
),
farm_progress AS (
    SELECT
        g.id_farm,
        COUNT(*)::bigint AS goals_count,
        COUNT(*) FILTER (WHERE g.status = 'Concluída')::bigint AS completed_goals_count,
        COUNT(*) FILTER (WHERE g.status = 'Em andamento')::bigint AS in_progress_goals_count,
        COUNT(*) FILTER (WHERE g.status = 'Pendente')::bigint AS pending_goals_count,
        COUNT(*) FILTER (
            WHERE g.status NOT IN ('Concluída', 'Em andamento', 'Pendente')
        )::bigint AS unknown_status_goals_count,
        ROUND(AVG(
            CASE g.status
                WHEN 'Concluída' THEN 100
                WHEN 'Em andamento' THEN 50
                WHEN 'Pendente' THEN 0
                ELSE 0
            END
        ), 2) AS progress_pct
    FROM goals AS g
    GROUP BY g.id_farm
)
SELECT
    f.id AS id_farm,
    f.id_enterprise,
    f.region,
    COALESCE(fp.goals_count, 0)::bigint AS goals_count,
    COALESCE(fp.completed_goals_count, 0)::bigint AS completed_goals_count,
    COALESCE(fp.in_progress_goals_count, 0)::bigint AS in_progress_goals_count,
    COALESCE(fp.pending_goals_count, 0)::bigint AS pending_goals_count,
    COALESCE(fp.unknown_status_goals_count, 0)::bigint AS unknown_status_goals_count,
    fp.progress_pct
FROM public.farms AS f
LEFT JOIN farm_progress AS fp ON fp.id_farm = f.id;

COMMENT ON VIEW public.goals_progress IS
    'Progresso das metas individuais e compartilhadas por granja; o contexto cadastral reflete empresa e região atuais.';

CREATE OR REPLACE VIEW public.payments_monthly AS
WITH monthly_payments AS (
    SELECT
        p.id_enterprise,
        date_trunc('month', p.date_creation)::date AS month,
        COUNT(*)::bigint AS payments_count,
        SUM(p.value)::numeric AS payments_value
    FROM public.payments AS p
    JOIN public.enterprises AS e ON e.id = p.id_enterprise
    WHERE p.date_creation < date_trunc('month', CURRENT_DATE)
    GROUP BY p.id_enterprise, date_trunc('month', p.date_creation)::date
),
windowed AS (
    SELECT
        mp.id_enterprise,
        mp.month,
        mp.payments_count,
        mp.payments_value,
        SUM(mp.payments_value) OVER (
            PARTITION BY mp.id_enterprise, date_trunc('year', mp.month)
            ORDER BY mp.month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS payments_value_ytd,
        LAG(mp.month) OVER (
            PARTITION BY mp.id_enterprise ORDER BY mp.month
        ) AS previous_month,
        LAG(mp.payments_value) OVER (
            PARTITION BY mp.id_enterprise ORDER BY mp.month
        ) AS previous_payments_value
    FROM monthly_payments AS mp
),
compared AS (
    SELECT
        w.id_enterprise,
        w.month,
        w.payments_count,
        w.payments_value,
        w.payments_value_ytd,
        CASE
            WHEN w.previous_month = (w.month - INTERVAL '1 month')::date
                THEN w.previous_payments_value
            ELSE NULL
        END AS previous_month_payments_value,
        CASE
            WHEN w.previous_month = (w.month - INTERVAL '1 month')::date
                THEN 100::numeric * (w.payments_value - w.previous_payments_value)
                    / NULLIF(w.previous_payments_value, 0)
            ELSE NULL
        END AS payments_change_pct
    FROM windowed AS w
)
SELECT
    id_enterprise,
    month,
    payments_count,
    payments_value,
    payments_value_ytd,
    previous_month_payments_value,
    payments_change_pct
FROM compared;

COMMENT ON VIEW public.payments_monthly IS
    'Pagamentos registrados por empresa e mês encerrado; a soma não confirma liquidação financeira.';

REVOKE ALL PRIVILEGES ON TABLE
    public.water_monthly,
    public.energy_monthly,
    public.integrated_monthly,
    public.goals_progress,
    public.payments_monthly
FROM PUBLIC;
