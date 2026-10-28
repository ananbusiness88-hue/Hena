-- Hena Catalog Data API Grants
-- Public catalog is readable by anonymous and authenticated clients.
-- RLS policies remain responsible for row-level filtering.

grant select on public.stores
  to anon, authenticated;

grant select on public.product_categories
  to anon, authenticated;

grant select on public.products
  to anon, authenticated;

grant select on public.product_pricing
  to anon, authenticated;