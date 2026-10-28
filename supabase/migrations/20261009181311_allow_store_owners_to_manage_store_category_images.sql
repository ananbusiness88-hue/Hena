CREATE POLICY "store_images_owner_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'store-images'
  AND EXISTS (
    SELECT 1
    FROM public.stores AS s
    WHERE s.id::text = (storage.foldername(name))[1]
      AND s.owner_id = (SELECT auth.uid())
  )
);

CREATE POLICY "store_images_owner_select"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'store-images'
  AND EXISTS (
    SELECT 1
    FROM public.stores AS s
    WHERE s.id::text = (storage.foldername(name))[1]
      AND s.owner_id = (SELECT auth.uid())
  )
);

CREATE POLICY "store_images_owner_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'store-images'
  AND EXISTS (
    SELECT 1
    FROM public.stores AS s
    WHERE s.id::text = (storage.foldername(name))[1]
      AND s.owner_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  bucket_id = 'store-images'
  AND EXISTS (
    SELECT 1
    FROM public.stores AS s
    WHERE s.id::text = (storage.foldername(name))[1]
      AND s.owner_id = (SELECT auth.uid())
  )
);;
