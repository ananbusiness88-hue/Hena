BEGIN;

-- ============================================================
-- HENA  Offers Owner Approval Workflow
-- ============================================================

-- ------------------------------------------------------------
-- APPROVAL STATUS
-- ------------------------------------------------------------

ALTER TABLE public.offers
ADD COLUMN IF NOT EXISTS approval_status text
NOT NULL DEFAULT 'pending';

ALTER TABLE public.offers
DROP CONSTRAINT IF EXISTS offers_approval_status_check;

ALTER TABLE public.offers
ADD CONSTRAINT offers_approval_status_check
CHECK (
    approval_status IN ('pending', 'approved', 'rejected')
);

-- Existing offers are treated as approved so the new workflow
-- does not unexpectedly hide already-existing approved offers.
UPDATE public.offers
SET approval_status = 'approved'
WHERE approval_status = 'pending';

-- ------------------------------------------------------------
-- CUSTOMER VISIBILITY
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "offers_select_active"
ON public.offers;

CREATE POLICY "offers_select_active"
ON public.offers
FOR SELECT
TO anon, authenticated
USING (
    approval_status = 'approved'
    AND is_active = true
    AND start_date <= now()
    AND end_date > now()
    AND EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = offers.store_id
          AND s.is_active = true
    )
);

-- ------------------------------------------------------------
-- STORE OWNER INSERT
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "offers_insert_owner"
ON public.offers;

CREATE POLICY "offers_insert_owner"
ON public.offers
FOR INSERT
TO authenticated
WITH CHECK (
    approval_status = 'pending'
    AND is_active = false
    AND EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = offers.store_id
          AND s.owner_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1
        FROM public.products p
        WHERE p.id = offers.product_id
          AND p.store_id = offers.store_id
    )
);

-- ------------------------------------------------------------
-- STORE OWNER UPDATE
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "offers_update_owner"
ON public.offers;

CREATE POLICY "offers_update_owner"
ON public.offers
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = offers.store_id
          AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    approval_status = 'pending'
    AND is_active = false
    AND EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = offers.store_id
          AND s.owner_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1
        FROM public.products p
        WHERE p.id = offers.product_id
          AND p.store_id = offers.store_id
    )
);

-- ------------------------------------------------------------
-- STORE OWNER CANNOT DELETE OFFERS
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "offers_delete_owner"
ON public.offers;

-- ------------------------------------------------------------
-- ADMIN INSERT / UPDATE
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "offers_insert_admin"
ON public.offers;

CREATE POLICY "offers_insert_admin"
ON public.offers
FOR INSERT
TO authenticated
WITH CHECK (
    is_admin()
);

DROP POLICY IF EXISTS "offers_update_admin"
ON public.offers;

CREATE POLICY "offers_update_admin"
ON public.offers
FOR UPDATE
TO authenticated
USING (
    is_admin()
)
WITH CHECK (
    is_admin()
);

COMMENT ON COLUMN public.offers.approval_status
IS 'Offer approval workflow: pending, approved, rejected. Store owners create pending offers; only admins can approve or reject.';

COMMIT;
