-- Driver profile images storage

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'driver-images',
  'driver-images',
  true,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists driver_images_insert on storage.objects;
drop policy if exists driver_images_select on storage.objects;
drop policy if exists driver_images_update on storage.objects;
drop policy if exists driver_images_delete on storage.objects;

create policy driver_images_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'driver-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy driver_images_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'driver-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy driver_images_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'driver-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'driver-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy driver_images_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'driver-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
