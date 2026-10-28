insert into storage.buckets (id, name, public)
values ('driver-avatars', 'driver-avatars', false)
on conflict (id) do update
set public = false;

create policy "Drivers can view own avatar"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'driver-avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Drivers can upload own avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'driver-avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Drivers can update own avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'driver-avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'driver-avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Drivers can delete own avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'driver-avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
