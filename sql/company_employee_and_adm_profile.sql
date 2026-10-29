-- Adiciona suporte a foto/avatar para o funcionário da integradora
ALTER TABLE public.company_employees 
ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);

-- Adiciona suporte a nome e foto para o administrador do sistema
ALTER TABLE public.adms 
ADD COLUMN IF NOT EXISTS name VARCHAR(100) DEFAULT 'Administrador';

ALTER TABLE public.adms 
ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);

COMMENT ON COLUMN public.company_employees.photo_url IS 'URL pública ou storage HTTPS da foto de avatar do colaborador';
COMMENT ON COLUMN public.adms.photo_url IS 'URL pública ou storage HTTPS da foto de avatar do administrador';
