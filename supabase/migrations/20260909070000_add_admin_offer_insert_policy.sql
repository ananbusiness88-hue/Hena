-- ============================================================================
-- OFFERS: ALLOW ADMIN INSERT
-- ============================================================================

CREATE POLICY offers_insert_admin
ON public.offers
FOR INSERT
TO authenticated
WITH CHECK (is_admin());
