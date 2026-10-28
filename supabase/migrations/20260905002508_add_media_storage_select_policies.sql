-- Hena: allow active Super Admins to read managed media objects.

DROP POLICY IF EXISTS "store_images_admin_select" ON storage.objects;

CREATE POLICY "store_images_admin_select"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'store-images'
    AND public.is_admin()
);

DROP POLICY IF EXISTS "product_images_admin_select" ON storage.objects;

CREATE POLICY "product_images_admin_select"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'product-images'
    AND public.is_admin()
);