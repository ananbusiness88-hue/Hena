create or replace function public.register_fcm_token(
  p_fcm_token text,
  p_platform text default 'android'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_fcm_token is null or btrim(p_fcm_token) = '' then
    raise exception 'FCM token is required';
  end if;

  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'Invalid platform';
  end if;

  insert into public.user_fcm_tokens (
    user_id,
    fcm_token,
    platform,
    last_seen_at
  )
  values (
    v_user_id,
    btrim(p_fcm_token),
    p_platform,
    now()
  )
  on conflict (fcm_token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    last_seen_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute
on function public.register_fcm_token(text, text)
from public, anon, service_role;

grant execute
on function public.register_fcm_token(text, text)
to authenticated;