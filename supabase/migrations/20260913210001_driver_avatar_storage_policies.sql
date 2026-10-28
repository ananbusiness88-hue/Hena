-- =========================================================
-- HENA - DRIVER AVATAR STORAGE POLICIES
-- =========================================================

DROP POLICY IF EXISTS "Drivers can view own avatar"
ON storage.objects;

DROP POLICY IF EXISTS "Drivers can upload own avatar"
ON storage.objects;

DROP POLICY IF EXISTS "Drivers can update own avatar"
ON storage.objects;

DROP POLICY IF EXISTS "Drivers can delete own avatar"
ON storage.objects;

CREATE POLICY "Drivers can view own avatar"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'driver-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

CREATE POLICY "Drivers can upload own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'driver-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

CREATE POLICY "Drivers can update own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'driver-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
)
WITH CHECK (
  bucket_id = 'driver-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

CREATE POLICY "Drivers can delete own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'driver-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);
