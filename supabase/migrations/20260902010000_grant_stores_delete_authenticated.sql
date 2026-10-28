-- Hena: allow authenticated clients to issue DELETE on stores.
-- RLS remains responsible for row-level authorization.
GRANT DELETE ON TABLE public.stores TO authenticated;
