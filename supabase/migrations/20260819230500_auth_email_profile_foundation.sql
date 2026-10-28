-- Hena Auth Foundation
-- Phone is stored as customer profile data.
-- Email is the authentication/verification identity.
-- Profile is automatically created from auth.users.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  insert into public.profiles (
    id,
    email
  )
  values (
    new.id,
    new.email
  )
  on conflict (id) do update
  set
    email = excluded.email,
    updated_at = now();

  return new;
end;
$function$;

drop policy if exists "Users can create own profile" on public.profiles;

create policy "Users can create own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

create index if not exists profiles_email_idx
on public.profiles (email);
