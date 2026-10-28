-- Hena Auth Phone Lookup - Final
-- Resolves a customer's phone number to the profile identity.
-- Authentication itself remains email/password in Supabase Auth.

create or replace function public.lookup_profile_by_phone(
  p_phone text
)
returns table (
  id uuid,
  email text,
  phone text,
  full_name text,
  role public.user_role
)
language sql
security definer
set search_path = public
as $function$
  select
    p.id,
    p.email,
    p.phone,
    p.full_name,
    p.role
  from public.profiles p
  where p.phone = p_phone
  limit 1;
$function$;

revoke all on function public.lookup_profile_by_phone(text)
from public;

grant execute on function public.lookup_profile_by_phone(text)
to anon, authenticated;
