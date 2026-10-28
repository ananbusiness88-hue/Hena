create table public.user_fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'android',
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  constraint user_fcm_tokens_fcm_token_key unique (fcm_token),
  constraint user_fcm_tokens_platform_check
    check (platform in ('android', 'ios', 'web'))
);

create index user_fcm_tokens_user_id_idx
  on public.user_fcm_tokens (user_id);

alter table public.user_fcm_tokens enable row level security;

grant select, insert, update, delete
  on table public.user_fcm_tokens
  to authenticated;

create policy "users_select_own_fcm_tokens"
  on public.user_fcm_tokens
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users_insert_own_fcm_tokens"
  on public.user_fcm_tokens
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "users_update_own_fcm_tokens"
  on public.user_fcm_tokens
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "users_delete_own_fcm_tokens"
  on public.user_fcm_tokens
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);