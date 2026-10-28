ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS is_available boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.products.is_available IS
'Controls temporary product availability independently of administrative activation.';

NOTIFY pgrst, 'reload schema';
