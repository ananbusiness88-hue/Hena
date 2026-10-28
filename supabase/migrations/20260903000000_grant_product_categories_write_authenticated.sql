-- Hena: allow authenticated clients to perform category management.
-- RLS policies remain responsible for row-level authorization.
GRANT INSERT, UPDATE, DELETE ON TABLE public.product_categories TO authenticated;
