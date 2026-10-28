-- Hena: Reconcile orders SELECT authorization.
--
-- Anonymous clients must never have direct SELECT access.
-- Authenticated clients may SELECT, while RLS controls rows.

REVOKE SELECT ON TABLE public.orders FROM anon;

GRANT SELECT ON TABLE public.orders TO authenticated;

DROP POLICY IF EXISTS "orders_select_admin"
ON public.orders;

CREATE POLICY "orders_select_admin"
ON public.orders
FOR SELECT
TO authenticated
USING (
  is_admin()
);
