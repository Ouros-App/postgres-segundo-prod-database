CREATE OR REPLACE FUNCTION public.atualiza_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'addresses', 'enterprises', 'farms', 'lots',
        'water_registries', 'energy_registries', 'plans',
        'enterprise_plans', 'payments', 'individual_goals',
        'state_goals', 'regions_goals', 'farm_goals',
        'state_goal_regions', 'tips', 'categories',
        'tip_categories', 'reviews'
    ] LOOP
        EXECUTE format(
            'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP',
            table_name
        );
        EXECUTE format(
            'UPDATE public.%I SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL',
            table_name
        );
        EXECUTE format(
            'ALTER TABLE public.%I ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP',
            table_name
        );
        EXECUTE format(
            'ALTER TABLE public.%I ALTER COLUMN updated_at SET NOT NULL',
            table_name
        );
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON public.%I',
            'analytics_updated_at_' || table_name,
            table_name
        );
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.atualiza_updated_at()',
            'analytics_updated_at_' || table_name,
            table_name
        );
    END LOOP;
END
$$;
