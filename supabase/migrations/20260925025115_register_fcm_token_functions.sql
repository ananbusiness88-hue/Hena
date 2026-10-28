create or replace function public.register_fcm_token(
  p_fcm_token text,
  p_platform text default 'android'
)
returns uuid
language plpgsql
security invoker
set search_path = public
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

create or replace function public.unregister_fcm_token(
  p_fcm_token text
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_deleted integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.user_fcm_tokens
  where user_id = auth.uid()
    and fcm_token = btrim(p_fcm_token);

  get diagnostics v_deleted = row_count;

  return v_deleted;
end;
$$;

revoke all on function public.register_fcm_token(text, text) from public;
revoke all on function public.unregister_fcm_token(text) from public;

grant execute on function public.register_fcm_token(text, text)
  to authenticated;

grant execute on function public.unregister_fcm_token(text)
  to authenticated;