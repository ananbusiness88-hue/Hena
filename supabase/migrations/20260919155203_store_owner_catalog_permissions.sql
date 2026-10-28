BEGIN;

-- ============================================================
-- HENA  Store Owner Catalog Permissions
-- ============================================================
-- Store Owner can fully manage the catalog of owned stores:
-- Categories: INSERT / UPDATE / DELETE
-- Products:    INSERT / UPDATE / DELETE
-- Pricing:     INSERT / UPDATE / DELETE
-- ============================================================

-- ------------------------------------------------------------
-- PRODUCT CATEGORIES
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "product_categories_insert_owner"
ON public.product_categories;

CREATE POLICY "product_categories_insert_owner"
ON public.product_categories
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = product_categories.store_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "product_categories_update_owner"
ON public.product_categories;

CREATE POLICY "product_categories_update_owner"
ON public.product_categories
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = product_categories.store_id
          AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = product_categories.store_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "product_categories_delete_owner"
ON public.product_categories;

CREATE POLICY "product_categories_delete_owner"
ON public.product_categories
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = product_categories.store_id
          AND s.owner_id = auth.uid()
    )
);

-- ------------------------------------------------------------
-- PRODUCTS
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "products_delete_owner"
ON public.products;

CREATE POLICY "products_delete_owner"
ON public.products
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.stores s
        WHERE s.id = products.store_id
          AND s.owner_id = auth.uid()
    )
);

-- ------------------------------------------------------------
-- PRODUCT PRICING
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "product_pricing_insert_owner"
ON public.product_pricing;

CREATE POLICY "product_pricing_insert_owner"
ON public.product_pricing
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.products p
        JOIN public.stores s
          ON s.id = p.store_id
        WHERE p.id = product_pricing.product_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "product_pricing_update_owner"
ON public.product_pricing;

CREATE POLICY "product_pricing_update_owner"
ON public.product_pricing
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.products p
        JOIN public.stores s
          ON s.id = p.store_id
        WHERE p.id = product_pricing.product_id
          AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.products p
        JOIN public.stores s
          ON s.id = p.store_id
        WHERE p.id = product_pricing.product_id
          AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "product_pricing_delete_owner"
ON public.product_pricing;

CREATE POLICY "product_pricing_delete_owner"
ON public.product_pricing
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.products p
        JOIN public.stores s
          ON s.id = p.store_id
        WHERE p.id = product_pricing.product_id
          AND s.owner_id = auth.uid()
    )
);

COMMIT;
