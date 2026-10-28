-- Allow signed-in users to create their own addresses.
-- Row ownership remains enforced by addresses RLS.

grant insert on table public.addresses to authenticated;
