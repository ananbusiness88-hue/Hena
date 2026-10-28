-- Hena: repair media storage that was marked applied but missing remotely.
-- Public read access is provided by public buckets.
-- Upload/update/delete are restricted to active Super Admins.

INSERT INTO storage.buckets
    (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    (
        'store-images',
        'store-images',
        true,
        5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    ),
    (
        'product-images',
        'product-images',
        true,
        5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    )
ON CONFLICT (id) DO UPDATE
SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "store_images_admin_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'store-images'
    AND public.is_admin()
);

CREATE POLICY "store_images_admin_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'store-images'
    AND public.is_admin()
)
WITH CHECK (
    bucket_id = 'store-images'
    AND public.is_admin()
);

CREATE POLICY "store_images_admin_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'store-images'
    AND public.is_admin()
);

CREATE POLICY "product_images_admin_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'product-images'
    AND public.is_admin()
);

CREATE POLICY "product_images_admin_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND public.is_admin()
)
WITH CHECK (
    bucket_id = 'product-images'
    AND public.is_admin()
);

CREATE POLICY "product_images_admin_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND public.is_admin()
);