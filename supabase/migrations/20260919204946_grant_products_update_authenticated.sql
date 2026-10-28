-- Allow authenticated users to issue UPDATE on products.
-- Row-level security policies continue to restrict which products
-- a Store Owner can actually modify.

grant update on table public.products to authenticated;
