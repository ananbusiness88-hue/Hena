-- STEP C: durable store-order print jobs + store-owner notification event
-- Does not change any existing order status transition.

create table public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  order_store_part_id uuid not null
    references public.order_store_parts(id) on delete cascade,
  order_id uuid not null
    references public.orders(id) on delete cascade,
  store_id uuid not null
    references public.stores(id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'printing', 'printed', 'failed')),
  attempts integer not null default 0
    check (attempts >= 0),
  last_error text,
  queued_at timestamptz not null default now(),
  printed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint print_jobs_order_store_part_key
    unique (order_store_part_id)
);

create index print_jobs_store_status_created_idx
  on public.print_jobs (store_id, status, created_at asc);

create index print_jobs_order_id_idx
  on public.print_jobs (order_id);

alter table public.print_jobs enable row level security;

grant select, update on table public.print_jobs to authenticated;

create policy "store_owners_select_own_print_jobs"
  on public.print_jobs
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.stores s
      where s.id = print_jobs.store_id
        and s.owner_id = (select auth.uid())
    )
  );

create policy "store_owners_update_own_print_jobs"
  on public.print_jobs
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.stores s
      where s.id = print_jobs.store_id
        and s.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.stores s
      where s.id = print_jobs.store_id
        and s.owner_id = (select auth.uid())
    )
  );

-- Prevent duplicate new-store-order notifications for the same store portion.
create unique index notifications_store_order_part_unique_idx
  on public.notifications (
    recipient_user_id,
    type,
    ((data ->> 'order_store_part_id'))
  );

create or replace function private.handle_new_store_order_part()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_owner_id uuid;
  v_notification_id uuid;
  v_order_number text;
  v_webhook_url text;
  v_webhook_secret text;
  v_request_id bigint;
begin
  if new.status is distinct from 'preparing' then
    return new;
  end if;

  -- Durable print job: one job per store portion.
  insert into public.print_jobs (
    order_store_part_id,
    order_id,
    store_id
  )
  values (
    new.id,
    new.order_id,
    new.store_id
  )
  on conflict (order_store_part_id) do nothing;

  -- Only the owner of the affected store is notified.
  select s.owner_id
    into v_owner_id
  from public.stores s
  where s.id = new.store_id
    and s.is_active = true;

  if v_owner_id is null then
    raise warning 'No active owner found for store %', new.store_id;
    return new;
  end if;

  select coalesce(
    nullif(o.unified_order_number, ''),
    left(new.order_id::text, 8)
  )
    into v_order_number
  from public.orders o
  where o.id = new.order_id;

  v_order_number := coalesce(
    v_order_number,
    left(new.order_id::text, 8)
  );

  -- Durable in-app notification log.
  insert into public.notifications (
    recipient_user_id,
    title,
    body,
    type,
    data,
    is_read,
    created_by,
    created_at
  )
  values (
    v_owner_id,
    U&'\0637\0644\0628 \062c\062f\064a\062f',
    U&'\0644\062f\064a\0643 \0637\0644\0628 \062c\062f\064a\062f \0631\0642\0645 ' || v_order_number,
    'new_store_order',
    jsonb_build_object(
      'event', 'new_store_order',
      'order_store_part_id', new.id,
      'order_id', new.order_id,
      'store_id', new.store_id,
      'order_number', v_order_number
    ),
    false,
    null,
    now()
  )
  on conflict do nothing
  returning id into v_notification_id;

  -- Idempotency: an already-existing event must not produce another FCM.
  if v_notification_id is null then
    return new;
  end if;

  -- Webhook URL and secret are stored in Supabase Vault.
  select ds.decrypted_secret
    into v_webhook_url
  from vault.decrypted_secrets ds
  where ds.name = 'STORE_ORDER_FCM_WEBHOOK_URL'
  limit 1;

  select ds.decrypted_secret
    into v_webhook_secret
  from vault.decrypted_secrets ds
  where ds.name = 'STORE_ORDER_FCM_WEBHOOK_SECRET'
  limit 1;

  if v_webhook_url is null or v_webhook_secret is null then
    raise warning
      'Store-order FCM webhook is not configured for store part %',
      new.id;
    return new;
  end if;

  -- Asynchronous request; FCM delivery is handled by the Edge Function.
  select net.http_post(
    url := v_webhook_url,
    body := jsonb_build_object(
      'event', 'new_store_order',
      'notification_id', v_notification_id,
      'order_store_part_id', new.id,
      'order_id', new.order_id,
      'store_id', new.store_id,
      'order_number', v_order_number,
      'recipient_user_id', v_owner_id
    ),
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_webhook_secret
    ),
    timeout_milliseconds := 5000
  )
    into v_request_id;

  return new;
end;
$$;

revoke all on function private.handle_new_store_order_part()
from public;

drop trigger if exists trg_handle_new_store_order_part
on public.order_store_parts;

create trigger trg_handle_new_store_order_part
after insert on public.order_store_parts
for each row
when (new.status = 'preparing')
execute function private.handle_new_store_order_part();
