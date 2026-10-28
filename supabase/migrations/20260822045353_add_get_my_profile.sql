create or replace function public.get_my_profile()
returns table (
  id uuid,
  full_name text,
  phone text,
  email text,
  role public.user_role,
  avatar_url text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $function$
  select
    p.id,
    p.full_name,
    p.phone,
    p.email,
    p.role,
    p.avatar_url,
    p.is_active,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$function$;

grant execute on function public.get_my_profile() to authenticated;
