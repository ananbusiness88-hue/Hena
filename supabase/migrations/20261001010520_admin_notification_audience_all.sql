-- ============================================================
-- HENA ADMIN NOTIFICATION CENTER
-- Support audience_scope = role / all
-- ============================================================

alter table public.admin_notification_campaigns
  add column if not exists audience_scope text not null default 'role';

alter table public.admin_notification_campaigns
  alter column audience_role drop not null;

alter table public.admin_notification_campaigns
  drop constraint if exists admin_notification_campaigns_audience;

alter table public.admin_notification_campaigns
  add constraint admin_notification_campaigns_audience
  check (
    (
      audience_scope = 'all'
      and audience_role is null
    )
    or
    (
      audience_scope = 'role'
      and audience_role in ('customer', 'store_owner', 'driver')
    )
  );

drop function if exists public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text
);

create or replace function public.admin_send_notification(
  p_target_role public.user_role,
  p_title text,
  p_body text,
  p_image_url text default null,
  p_target_type text default 'none',
  p_target_id uuid default null,
  p_target_name text default null,
  p_audience_scope text default 'role'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_campaign_id uuid;
  v_count integer := 0;
begin
  v_admin_id := auth.uid();

  if v_admin_id is null or not public.is_admin() then
    raise exception 'Only admins can send notifications';
  end if;

  if p_audience_scope not in ('role', 'all') then
    raise exception 'Invalid notification audience scope';
  end if;

  if p_audience_scope = 'role' then
    if p_target_role is null
       or p_target_role not in ('customer', 'store_owner', 'driver') then
      raise exception 'Unsupported notification audience';
    end if;
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'Notification title is required';
  end if;

  if nullif(trim(p_body), '') is null then
    raise exception 'Notification body is required';
  end if;

  if p_target_type not in ('none', 'store', 'product') then
    raise exception 'Invalid target type';
  end if;

  insert into public.admin_notification_campaigns (
    audience_scope,
    audience_role,
    title,
    body,
    image_url,
    target_type,
    target_id,
    target_name,
    created_by
  )
  values (
    p_audience_scope,
    case
      when p_audience_scope = 'all' then null
      else p_target_role
    end,
    trim(p_title),
    trim(p_body),
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_target_type,
    p_target_id,
    nullif(trim(coalesce(p_target_name, '')), ''),
    v_admin_id
  )
  returning id into v_campaign_id;

  insert into public.notifications (
    recipient_user_id,
    title,
    body,
    type,
    data,
    is_read,
    created_by
  )
  select
    p.id,
    trim(p_title),
    trim(p_body),
    'admin_broadcast',
    jsonb_build_object(
      'campaign_id', v_campaign_id,
      'audience_scope', p_audience_scope,
      'audience_role', p_target_role::text,
      'image_url', nullif(trim(coalesce(p_image_url, '')), ''),
      'target_type', p_target_type,
      'target_id', p_target_id,
      'target_name', nullif(trim(coalesce(p_target_name, '')), '')
    ),
    false,
    v_admin_id
  from public.profiles p
  where p.is_active = true
    and (
      p_audience_scope = 'all'
      or p.role = p_target_role
    );

  get diagnostics v_count = row_count;

  update public.admin_notification_campaigns
  set recipient_count = v_count
  where id = v_campaign_id;

  return v_count;
end;
$$;

revoke all on function public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text,
  text
) from public;

grant execute on function public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text,
  text
) to authenticated;