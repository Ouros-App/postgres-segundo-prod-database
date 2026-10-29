-- Tabela para persistir cenários de simulação criados na web
CREATE TABLE IF NOT EXISTS public.farm_simulations (
    id BIGSERIAL PRIMARY KEY,
    id_farm BIGINT NOT NULL,
    id_enterprise BIGINT NOT NULL,
    id_lot VARCHAR(50) NOT NULL,
    current_cgi NUMERIC(8, 4) NOT NULL,
    target_cgi NUMERIC(8, 4) NOT NULL,
    water_price NUMERIC(10, 2) NOT NULL,
    energy_price NUMERIC(10, 2) NOT NULL,
    poultry_quantity INTEGER NOT NULL,
    target_energy_kwh NUMERIC(8, 4) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_farm_simulations_farm FOREIGN KEY (id_farm) REFERENCES public.farms(id) ON DELETE CASCADE,
    CONSTRAINT fk_farm_simulations_enterprise FOREIGN KEY (id_enterprise) REFERENCES public.enterprises(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_farm_simulations_enterprise ON public.farm_simulations(id_enterprise);
CREATE INDEX IF NOT EXISTS idx_farm_simulations_farm ON public.farm_simulations(id_farm);
