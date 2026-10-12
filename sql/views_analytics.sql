-- Views analíticas mensais. Os cadastros de empresa e região refletem o estado atual.

CREATE OR REPLACE VIEW public.water_monthly AS
WITH monthly_water AS (
    SELECT
        w.id_farm,
        date_trunc('month', w.registration_date)::date AS month,
        SUM(w.end_hydrometer - w.start_hydrometer)::numeric AS water_consumed,
        COUNT(*)::bigint AS registry_count
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
        mw.water_consumed,
        mw.registry_count
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
        ) AS previous_water_consumed,
        DENSE_RANK() OVER (
            PARTITION BY fm.id_enterprise, fm.month
            ORDER BY fm.water_consumed DESC
        ) AS water_consumption_rank,
        fm.registry_count
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
        END AS previous_month_water_consumed,
        CASE
            WHEN w.previous_month = (w.month - INTERVAL '1 month')::date
                THEN 100::numeric * (w.water_consumed - w.previous_water_consumed)
                    / NULLIF(w.previous_water_consumed, 0)
            ELSE NULL
        END AS water_change_pct,
        w.water_consumption_rank,
        w.registry_count
    FROM windowed AS w
)
SELECT
    id_farm,
    id_enterprise,
    region,
    month,
    water_consumed,
    water_consumed_ytd,
    previous_month_water_consumed,
    water_change_pct,
    water_consumption_rank,
    registry_count
FROM compared;

COMMENT ON VIEW public.water_monthly IS
    'Consumo mensal de água por granja, apenas para meses encerrados; ranks abrangem a empresa toda naquele mês.';
COMMENT ON COLUMN public.water_monthly.month IS
    'Primeiro dia do mês (DATE); o mês em andamento e datas futuras são excluídos por CURRENT_DATE da sessão.';
COMMENT ON COLUMN public.water_monthly.water_consumed IS
    'Soma NUMERIC de end_hydrometer - start_hydrometer nas leituras do mês.';
COMMENT ON COLUMN public.water_monthly.water_consumed_ytd IS
    'Acumulado do consumo mensal registrado no ano civil; meses sem registros não geram linhas.';
COMMENT ON COLUMN public.water_monthly.previous_month_water_consumed IS
    'Consumo do mês imediatamente anterior; NULL quando há lacuna ou o mês anterior não existe.';
COMMENT ON COLUMN public.water_monthly.water_change_pct IS
    'Variação percentual contra o mês imediatamente anterior; NULL para lacunas ou consumo anterior zero.';
COMMENT ON COLUMN public.water_monthly.water_consumption_rank IS
    'DENSE_RANK decrescente por empresa e mês; maior consumo registrado recebe posição 1.';
COMMENT ON COLUMN public.water_monthly.registry_count IS
    'Quantidade de leituras incluídas no total mensal.';

CREATE OR REPLACE VIEW public.energy_monthly AS
WITH monthly_energy AS (
    SELECT
        e.id_farm,
        date_trunc('month', e.registration_date)::date AS month,
        SUM(e.energy_consumption)::numeric AS energy_consumed,
        COUNT(*)::bigint AS registry_count
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
        me.energy_consumed,
        me.registry_count
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
        ) AS previous_energy_consumed,
        DENSE_RANK() OVER (
            PARTITION BY fm.id_enterprise, fm.month
            ORDER BY fm.energy_consumed DESC
        ) AS energy_consumption_rank,
        fm.registry_count
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
        END AS previous_month_energy_consumed,
        CASE
            WHEN e.previous_month = (e.month - INTERVAL '1 month')::date
                THEN 100::numeric * (e.energy_consumed - e.previous_energy_consumed)
                    / NULLIF(e.previous_energy_consumed, 0)
            ELSE NULL
        END AS energy_change_pct,
        e.energy_consumption_rank,
        e.registry_count
    FROM windowed AS e
)
SELECT
    id_farm,
    id_enterprise,
    region,
    month,
    energy_consumed,
    energy_consumed_ytd,
    previous_month_energy_consumed,
    energy_change_pct,
    energy_consumption_rank,
    registry_count
FROM compared;

COMMENT ON VIEW public.energy_monthly IS
    'Consumo mensal de energia por granja, apenas para meses encerrados; ranks abrangem a empresa toda naquele mês.';
COMMENT ON COLUMN public.energy_monthly.month IS
    'Primeiro dia do mês (DATE); o mês em andamento e datas futuras são excluídos por CURRENT_DATE da sessão.';
COMMENT ON COLUMN public.energy_monthly.energy_consumed IS
    'Soma NUMERIC do consumo de energia registrado no mês.';
COMMENT ON COLUMN public.energy_monthly.energy_consumed_ytd IS
    'Acumulado do consumo mensal registrado no ano civil; meses sem registros não geram linhas.';
COMMENT ON COLUMN public.energy_monthly.previous_month_energy_consumed IS
    'Consumo do mês imediatamente anterior; NULL quando há lacuna ou o mês anterior não existe.';
COMMENT ON COLUMN public.energy_monthly.energy_change_pct IS
    'Variação percentual contra o mês imediatamente anterior; NULL para lacunas ou consumo anterior zero.';
COMMENT ON COLUMN public.energy_monthly.energy_consumption_rank IS
    'DENSE_RANK decrescente por empresa e mês; maior consumo registrado recebe posição 1.';
COMMENT ON COLUMN public.energy_monthly.registry_count IS
    'Quantidade de registros de energia incluídos no total mensal.';

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
        ) AS enterprise_month_energy_consumed,
        DENSE_RANK() OVER (
            PARTITION BY fm.id_enterprise, fm.month
            ORDER BY fm.water_consumed DESC NULLS LAST
        ) AS water_consumption_rank,
        DENSE_RANK() OVER (
            PARTITION BY fm.id_enterprise, fm.month
            ORDER BY fm.energy_consumed DESC NULLS LAST
        ) AS energy_consumption_rank
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
            / NULLIF(w.enterprise_month_energy_consumed, 0) AS energy_share_pct,
        CASE WHEN w.has_water_data THEN w.water_consumption_rank END AS water_consumption_rank,
        CASE WHEN w.has_energy_data THEN w.energy_consumption_rank END AS energy_consumption_rank
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
    energy_share_pct,
    water_consumption_rank,
    energy_consumption_rank
FROM shares;

COMMENT ON VIEW public.integrated_monthly IS
    'Água e energia mensais por granja e mês com ao menos um recurso registrado; recursos ausentes ficam NULL.';
COMMENT ON COLUMN public.integrated_monthly.month IS
    'Primeiro dia do mês (DATE); considera apenas meses encerrados segundo CURRENT_DATE da sessão.';
COMMENT ON COLUMN public.integrated_monthly.water_consumed IS
    'Soma NUMERIC de água registrada no mês; NULL quando não há leitura.';
COMMENT ON COLUMN public.integrated_monthly.energy_consumed IS
    'Soma NUMERIC de energia registrada no mês; NULL quando não há registro.';
COMMENT ON COLUMN public.integrated_monthly.has_water_data IS
    'Indica se há ao menos uma leitura de água; diferencia ausência de dado de consumo igual a zero.';
COMMENT ON COLUMN public.integrated_monthly.has_energy_data IS
    'Indica se há ao menos um registro de energia.';
COMMENT ON COLUMN public.integrated_monthly.water_registry_count IS
    'Quantidade de leituras de água consideradas para a granja e o mês.';
COMMENT ON COLUMN public.integrated_monthly.energy_registry_count IS
    'Quantidade de registros de energia considerados para a granja e o mês.';
COMMENT ON COLUMN public.integrated_monthly.enterprise_month_water_consumed IS
    'Total de água registrado por todas as granjas da empresa no mês.';
COMMENT ON COLUMN public.integrated_monthly.enterprise_month_energy_consumed IS
    'Total de energia registrado por todas as granjas da empresa no mês.';
COMMENT ON COLUMN public.integrated_monthly.water_share_pct IS
    'Percentual da água da granja em relação ao total registrado da empresa no mês; NULL sem água ou com total zero.';
COMMENT ON COLUMN public.integrated_monthly.energy_share_pct IS
    'Percentual da energia da granja em relação ao total registrado da empresa no mês; NULL sem energia ou com total zero.';
COMMENT ON COLUMN public.integrated_monthly.water_consumption_rank IS
    'DENSE_RANK decrescente por empresa e mês; NULL quando a granja não tem água registrada.';
COMMENT ON COLUMN public.integrated_monthly.energy_consumption_rank IS
    'DENSE_RANK decrescente por empresa e mês; NULL quando a granja não tem energia registrada.';

CREATE OR REPLACE VIEW public.goals_progress AS
WITH goals AS (
    SELECT ig.id_farm, ig.status
    FROM public.individual_goals AS ig

    UNION ALL

    SELECT fg.id_farm, sg.status
    FROM public.farm_goals AS fg
    JOIN public.state_goals AS sg ON sg.id = fg.id_goal
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
),
ranked_goals AS (
    SELECT
        f.id AS id_farm,
        f.id_enterprise,
        f.region,
        fp.goals_count,
        fp.completed_goals_count,
        fp.in_progress_goals_count,
        fp.pending_goals_count,
        fp.unknown_status_goals_count,
        fp.progress_pct,
        DENSE_RANK() OVER (
            PARTITION BY f.id_enterprise ORDER BY fp.progress_pct DESC
        ) AS enterprise_progress_rank,
        DENSE_RANK() OVER (
            PARTITION BY f.region ORDER BY fp.progress_pct DESC
        ) AS region_progress_rank
    FROM farm_progress AS fp
    JOIN public.farms AS f ON f.id = fp.id_farm
    WHERE fp.goals_count > 0
)
SELECT
    f.id AS id_farm,
    f.id_enterprise,
    f.region,
    COALESCE(rg.goals_count, 0)::bigint AS goals_count,
    COALESCE(rg.completed_goals_count, 0)::bigint AS completed_goals_count,
    COALESCE(rg.in_progress_goals_count, 0)::bigint AS in_progress_goals_count,
    COALESCE(rg.pending_goals_count, 0)::bigint AS pending_goals_count,
    COALESCE(rg.unknown_status_goals_count, 0)::bigint AS unknown_status_goals_count,
    rg.progress_pct,
    rg.enterprise_progress_rank,
    rg.region_progress_rank
FROM public.farms AS f
LEFT JOIN ranked_goals AS rg ON rg.id_farm = f.id;

COMMENT ON VIEW public.goals_progress IS
    'Progresso das metas individuais e compartilhadas por granja; o contexto cadastral reflete empresa e região atuais.';
COMMENT ON COLUMN public.goals_progress.id_farm IS
    'Granja incluída mesmo quando não possui metas.';
COMMENT ON COLUMN public.goals_progress.id_enterprise IS
    'Empresa atual da granja; alterações cadastrais podem reclassificar o histórico.';
COMMENT ON COLUMN public.goals_progress.region IS
    'Região atual da granja; alterações cadastrais podem reclassificar o histórico.';
COMMENT ON COLUMN public.goals_progress.goals_count IS
    'Total de metas individuais e metas compartilhadas vinculadas à granja; granjas sem metas têm zero.';
COMMENT ON COLUMN public.goals_progress.completed_goals_count IS
    'Metas com status Concluída.';
COMMENT ON COLUMN public.goals_progress.in_progress_goals_count IS
    'Metas com status Em andamento.';
COMMENT ON COLUMN public.goals_progress.pending_goals_count IS
    'Metas com status Pendente.';
COMMENT ON COLUMN public.goals_progress.unknown_status_goals_count IS
    'Metas com qualquer status não reconhecido; esses status pontuam zero.';
COMMENT ON COLUMN public.goals_progress.progress_pct IS
    'Média arredondada a duas casas da pontuação: Concluída 100, Em andamento 50, Pendente ou desconhecido 0; NULL sem metas.';
COMMENT ON COLUMN public.goals_progress.enterprise_progress_rank IS
    'DENSE_RANK por empresa, maior progresso primeiro; NULL para granjas sem metas.';
COMMENT ON COLUMN public.goals_progress.region_progress_rank IS
    'DENSE_RANK por região atual, maior progresso primeiro; NULL para granjas sem metas.';

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
        ) AS previous_payments_value,
        DENSE_RANK() OVER (
            PARTITION BY mp.month ORDER BY mp.payments_value DESC
        ) AS payments_rank
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
        END AS payments_change_pct,
        w.payments_rank
    FROM windowed AS w
)
SELECT
    id_enterprise,
    month,
    payments_count,
    payments_value,
    payments_value_ytd,
    previous_month_payments_value,
    payments_change_pct,
    payments_rank
FROM compared;

COMMENT ON VIEW public.payments_monthly IS
    'Pagamentos registrados por empresa e mês encerrado; a soma não confirma liquidação financeira.';
COMMENT ON COLUMN public.payments_monthly.id_enterprise IS
    'Empresa associada ao pagamento registrado.';
COMMENT ON COLUMN public.payments_monthly.month IS
    'Primeiro dia do mês (DATE); o mês em andamento e datas futuras são excluídos por CURRENT_DATE da sessão.';
COMMENT ON COLUMN public.payments_monthly.payments_count IS
    'Quantidade de pagamentos registrados no mês.';
COMMENT ON COLUMN public.payments_monthly.payments_value IS
    'Soma NUMERIC de payments.value registrada no mês; não representa confirmação de recebimento.';
COMMENT ON COLUMN public.payments_monthly.payments_value_ytd IS
    'Acumulado anual dos valores registrados; meses sem pagamentos não geram linhas.';
COMMENT ON COLUMN public.payments_monthly.previous_month_payments_value IS
    'Valor registrado no mês imediatamente anterior; NULL quando há lacuna ou o mês anterior não existe.';
COMMENT ON COLUMN public.payments_monthly.payments_change_pct IS
    'Variação percentual contra o mês imediatamente anterior; NULL para lacunas ou valor anterior zero.';
COMMENT ON COLUMN public.payments_monthly.payments_rank IS
    'DENSE_RANK decrescente entre empresas por mês; maior valor registrado recebe posição 1.';

REVOKE ALL PRIVILEGES ON TABLE
    public.water_monthly,
    public.energy_monthly,
    public.integrated_monthly,
    public.goals_progress,
    public.payments_monthly
FROM PUBLIC;
