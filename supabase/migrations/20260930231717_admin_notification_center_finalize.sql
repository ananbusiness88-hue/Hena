-- ============================================================
-- HENA ADMIN NOTIFICATION CENTER - FINALIZE
-- Repair/finalize migration for the notification center schema.
-- ============================================================

-- ============================================================
-- Campaign table
-- ============================================================

create table if not exists public.admin_notification_campaigns (
  id uuid primary key default gen_random_uuid(),

  audience_role public.user_role not null,

  title text not null,
  body text not null,

  image_url text,

  target_type text not null default 'none',
  target_id uuid,
  target_name text,

  recipient_count integer not null default 0,

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  created_at timestamptz not null default now(),

  constraint admin_notification_campaigns_target_type
    check (target_type in ('none', 'store', 'product')),

  constraint admin_notification_campaigns_audience
    check (audience_role in ('customer', 'store_owner', 'driver'))
);

create index if not exists idx_admin_notification_campaigns_created_by
  on public.admin_notification_campaigns(created_by, created_at desc);

create index if not exists idx_admin_notification_campaigns_created_at
  on public.admin_notification_campaigns(created_at desc);

alter table public.admin_notification_campaigns
  enable row level security;

grant select on table public.admin_notification_campaigns
  to authenticated;

drop policy if exists admin_notification_campaigns_select_admin
on public.admin_notification_campaigns;

create policy admin_notification_campaigns_select_admin
on public.admin_notification_campaigns
for select
to authenticated
using (
  public.is_admin()
  and created_by = auth.uid()
);

-- ============================================================
-- Notification image bucket
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'notification-images',
  'notification-images',
  true,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists notification_images_admin_insert
on storage.objects;

drop policy if exists notification_images_admin_select
on storage.objects;

drop policy if exists notification_images_admin_update
on storage.objects;

drop policy if exists notification_images_admin_delete
on storage.objects;

create policy notification_images_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'notification-images'
  and public.is_admin()
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy notification_images_admin_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'notification-images'
  and public.is_admin()
);

create policy notification_images_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'notification-images'
  and public.is_admin()
)
with check (
  bucket_id = 'notification-images'
  and public.is_admin()
);

create policy notification_images_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'notification-images'
  and public.is_admin()
);

-- ============================================================
-- Admin broadcast RPC
-- ============================================================

create or replace function public.admin_send_notification(
  p_target_role public.user_role,
  p_title text,
  p_body text,
  p_image_url text default null,
  p_target_type text default 'none',
  p_target_id uuid default null,
  p_target_name text default null
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

  if p_target_role not in ('customer', 'store_owner', 'driver') then
    raise exception 'Unsupported notification audience';
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
    p_target_role,
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
      'audience_role', p_target_role::text,
      'image_url', nullif(trim(coalesce(p_image_url, '')), ''),
      'target_type', p_target_type,
      'target_id', p_target_id,
      'target_name', nullif(trim(coalesce(p_target_name, '')), '')
    ),
    false,
    v_admin_id
  from public.profiles p
  where p.role = p_target_role
    and p.is_active = true;

  get diagnostics v_count = row_count;

  update public.admin_notification_campaigns
  set recipient_count = v_count
  where id = v_campaign_id;

  return v_count;
end;
$$;

-- Explicitly lock the RPC down.
revoke all on function public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text
) from public;

revoke all on function public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text
) from anon;

grant execute on function public.admin_send_notification(
  public.user_role,
  text,
  text,
  text,
  text,
  uuid,
  text
) to authenticated;

-- ============================================================
-- End
-- ============================================================