-- Fix admin policies:
-- Admin policies must only apply to authenticated users.
-- This prevents the anon role from evaluating profiles-based
-- admin checks and avoids granting anon SELECT access to profiles.

DROP POLICY IF EXISTS "Admins manage product categories"
ON public.product_categories;

CREATE POLICY "Admins manage product categories"
ON public.product_categories
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);


DROP POLICY IF EXISTS "Admins manage product pricing"
ON public.product_pricing;

CREATE POLICY "Admins manage product pricing"
ON public.product_pricing
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);


DROP POLICY IF EXISTS "Admins manage products"
ON public.products;

CREATE POLICY "Admins manage products"
ON public.products
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);


DROP POLICY IF EXISTS "Admins manage store categories"
ON public.store_categories;

CREATE POLICY "Admins manage store categories"
ON public.store_categories
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);


DROP POLICY IF EXISTS "Admins manage store settings"
ON public.store_settings;

CREATE POLICY "Admins manage store settings"
ON public.store_settings
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);


DROP POLICY IF EXISTS "Admins manage stores"
ON public.stores;

CREATE POLICY "Admins manage stores"
ON public.stores
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'::public.user_role
  )
);
-- Public catalog access
-- store_categories is intentionally readable by anonymous users.

GRANT SELECT ON public.store_categories TO anon;
GRANT SELECT ON public.store_categories TO authenticated;
