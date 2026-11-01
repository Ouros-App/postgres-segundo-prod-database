CREATE INDEX IF NOT EXISTS farm_tip_observations_tip_farm_idx
    ON public.farm_tip_observations (tip_id, farm_id);
