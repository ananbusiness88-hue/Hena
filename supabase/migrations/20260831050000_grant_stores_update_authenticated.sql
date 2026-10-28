-- Hena: allow authenticated clients to issue UPDATE on stores.
-- RLS policies remain responsible for row-level authorization.
GRANT UPDATE ON TABLE public.stores TO authenticated;
