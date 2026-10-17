-- Calcula o saldo diário de aves a partir de um saldo inicial conhecido.
-- Cada lote é contabilizado em delivery_date: recebidas entram; entregues e
-- perdidas saem. chicken_left registra saídas adicionais e não deve repetir
-- perdas já contabilizadas em lots.losts.
--
-- Exemplo usando o saldo atual da fazenda como ponto inicial:
-- SELECT timeline.*
-- FROM public.farms AS farm
-- CROSS JOIN LATERAL public.farm_chicken_stock_timeline(
--     farm.id, CURRENT_DATE, farm.chickens_now, CURRENT_DATE + 7
-- ) AS timeline
-- WHERE farm.id = 1;

CREATE OR REPLACE FUNCTION public.farm_chicken_stock_timeline(
    p_farm_id INTEGER,
    p_start_date DATE,
    p_starting_stock INTEGER,
    p_until_date DATE
)
RETURNS TABLE (
    farm_id INTEGER,
    farm_name TEXT,
    stock_date DATE,
    chickens_in BIGINT,
    chickens_out BIGINT,
    stock_after_day BIGINT
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $function$
WITH RECURSIVE farm_context AS (
    SELECT
        farm.id,
        farm.name::TEXT AS name,
        p_start_date AS start_date,
        p_starting_stock::BIGINT AS starting_stock
    FROM public.farms AS farm
    WHERE farm.id = p_farm_id
      AND p_start_date IS NOT NULL
      AND p_starting_stock >= 0
      AND p_until_date >= p_start_date
), movement_events AS (
    SELECT
        lot.delivery_date AS movement_date,
        lot.received_chickens::BIGINT AS chickens_in,
        lot.delivered_chickens::BIGINT + lot.losts::BIGINT AS chickens_out
    FROM farm_context
    JOIN public.lots AS lot
      ON lot.id_farm = farm_context.id
    WHERE lot.delivery_date > farm_context.start_date
      AND lot.delivery_date <= p_until_date

    UNION ALL

    SELECT
        exit_record.exit_date AS movement_date,
        0::BIGINT AS chickens_in,
        exit_record.chickens_count::BIGINT AS chickens_out
    FROM farm_context
    JOIN public.chicken_left AS exit_record
      ON exit_record.id_farm = farm_context.id
    WHERE exit_record.exit_date > farm_context.start_date
      AND exit_record.exit_date <= p_until_date
), daily_movements AS (
    SELECT
        movement_events.movement_date,
        pg_catalog.sum(movement_events.chickens_in)::BIGINT AS chickens_in,
        pg_catalog.sum(movement_events.chickens_out)::BIGINT AS chickens_out
    FROM movement_events
    GROUP BY movement_events.movement_date
), daily_steps AS (
    SELECT
        farm_context.start_date + date_step.day_number AS stock_date,
        COALESCE(daily_movements.chickens_in, 0) AS chickens_in,
        COALESCE(daily_movements.chickens_out, 0) AS chickens_out
    FROM farm_context
    CROSS JOIN LATERAL pg_catalog.generate_series(
        1,
        p_until_date - farm_context.start_date
    ) AS date_step(day_number)
    LEFT JOIN daily_movements
      ON daily_movements.movement_date = farm_context.start_date + date_step.day_number
), stock_by_day(
    day_number,
    farm_id,
    farm_name,
    stock_date,
    chickens_in,
    chickens_out,
    stock_after_day
) AS (
    SELECT
        0,
        farm_context.id,
        farm_context.name,
        farm_context.start_date,
        0::BIGINT,
        0::BIGINT,
        farm_context.starting_stock
    FROM farm_context

    UNION ALL

    SELECT
        stock_by_day.day_number + 1,
        stock_by_day.farm_id,
        stock_by_day.farm_name,
        daily_steps.stock_date,
        daily_steps.chickens_in,
        daily_steps.chickens_out,
        stock_by_day.stock_after_day
            + daily_steps.chickens_in
            - daily_steps.chickens_out
    FROM stock_by_day
    JOIN daily_steps
      ON daily_steps.stock_date = stock_by_day.stock_date + 1
)
SELECT
    stock_by_day.farm_id,
    stock_by_day.farm_name,
    stock_by_day.stock_date,
    stock_by_day.chickens_in,
    stock_by_day.chickens_out,
    stock_by_day.stock_after_day
FROM stock_by_day
ORDER BY stock_by_day.day_number;
$function$;

COMMENT ON FUNCTION public.farm_chicken_stock_timeline(INTEGER, DATE, INTEGER, DATE) IS
    'Evolução diária por CTE recursiva a partir do saldo de fechamento informado; movimentos de lotes usam delivery_date e saídas adicionais usam chicken_left.exit_date.';
