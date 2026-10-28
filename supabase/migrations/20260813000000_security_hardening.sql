-- Hena-2 Security Hardening
-- Prevent users from changing their own role

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  if old.role is distinct from new.role then
    raise exception 'Users cannot change their own role';
  end if;

  return new;

end;
$$;


drop trigger if exists prevent_profile_role_change
on public.profiles;


create trigger prevent_profile_role_change
before update on public.profiles
for each row
execute function public.prevent_profile_role_change();