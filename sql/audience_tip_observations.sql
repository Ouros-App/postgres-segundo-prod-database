CREATE TABLE IF NOT EXISTS public.farm_tip_observations (
    farm_id INTEGER NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    tip_id INTEGER NOT NULL REFERENCES public.tips(id) ON DELETE CASCADE,
    observed_at TIMESTAMPTZ NOT NULL,
    signals JSONB NOT NULL CHECK (jsonb_typeof(signals) = 'object'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (farm_id, tip_id)
);


COMMENT ON TABLE public.farm_tip_observations IS
    'Latest admin-supplied farm-level signal snapshot per tip; contains no member IDs.';

GRANT SELECT ON public.farms, public.tips TO audience_metadata;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.audience_snapshot_refs TO audience_metadata;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tip_audience_refs TO audience_metadata;
GRANT SELECT, INSERT, UPDATE ON public.farm_tip_observations TO audience_metadata;
