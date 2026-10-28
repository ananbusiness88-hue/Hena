-- Allow signed-in users to read their own addresses.
-- Row visibility remains controlled by addresses RLS policies.

grant select on table public.addresses to authenticated;
