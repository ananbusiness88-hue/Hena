-- Store Owner product image storage policies.
-- Product path: product-images/{product_id}/main.ext

create policy "product_images_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  storage.objects.bucket_id = 'product-images'
  and exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id::text = (storage.foldername(storage.objects.name))[1]
      and s.owner_id = (select auth.uid())
  )
);

create policy "product_images_owner_select"
on storage.objects
for select
to authenticated
using (
  storage.objects.bucket_id = 'product-images'
  and exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id::text = (storage.foldername(storage.objects.name))[1]
      and s.owner_id = (select auth.uid())
  )
);

create policy "product_images_owner_update"
on storage.objects
for update
to authenticated
using (
  storage.objects.bucket_id = 'product-images'
  and exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id::text = (storage.foldername(storage.objects.name))[1]
      and s.owner_id = (select auth.uid())
  )
)
with check (
  storage.objects.bucket_id = 'product-images'
  and exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id::text = (storage.foldername(storage.objects.name))[1]
      and s.owner_id = (select auth.uid())
  )
);

create policy "product_images_owner_delete"
on storage.objects
for delete
to authenticated
using (
  storage.objects.bucket_id = 'product-images'
  and exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id::text = (storage.foldername(storage.objects.name))[1]
      and s.owner_id = (select auth.uid())
  )
);
