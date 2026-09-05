-- ============================================================
-- CreativeHub - APNs device token registry
-- Phase 11 Fix 03: token storage only. APNs provider credentials
-- and delivery stay server-side (Edge Function / webhook).
-- Safe to run after profiles/auth foundation.
-- ============================================================

begin;

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_token text not null,
  platform text not null default 'ios',
  environment text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  last_seen_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.push_device_tokens
  add column if not exists user_id uuid references public.profiles(id) on delete cascade,
  add column if not exists device_token text,
  add column if not exists platform text not null default 'ios',
  add column if not exists environment text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists last_seen_at timestamptz not null default timezone('utc'::text, now());

alter table public.push_device_tokens
  alter column user_id set not null,
  alter column device_token set not null,
  alter column platform set default 'ios',
  alter column platform set not null,
  alter column environment set not null,
  alter column is_active set default true,
  alter column is_active set not null,
  alter column created_at set default timezone('utc'::text, now()),
  alter column created_at set not null,
  alter column updated_at set default timezone('utc'::text, now()),
  alter column updated_at set not null,
  alter column last_seen_at set default timezone('utc'::text, now()),
  alter column last_seen_at set not null;

alter table public.push_device_tokens drop constraint if exists push_device_tokens_platform_check;
alter table public.push_device_tokens
  add constraint push_device_tokens_platform_check
  check (platform in ('ios', 'ipados'));

alter table public.push_device_tokens drop constraint if exists push_device_tokens_environment_check;
alter table public.push_device_tokens
  add constraint push_device_tokens_environment_check
  check (environment in ('development', 'production'));

alter table public.push_device_tokens drop constraint if exists push_device_tokens_token_format_check;
alter table public.push_device_tokens
  add constraint push_device_tokens_token_format_check
  check (device_token ~ '^[0-9a-f]{32,400}$');

create unique index if not exists push_device_tokens_token_env_unique
  on public.push_device_tokens (device_token, environment);

create index if not exists push_device_tokens_user_active_idx
  on public.push_device_tokens (user_id, is_active)
  where is_active = true;

create or replace function public.touch_push_device_tokens_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists push_device_tokens_touch_updated_at on public.push_device_tokens;
create trigger push_device_tokens_touch_updated_at
before update on public.push_device_tokens
for each row execute function public.touch_push_device_tokens_updated_at();

alter table public.push_device_tokens enable row level security;

drop policy if exists "push_device_tokens_select_own" on public.push_device_tokens;
drop policy if exists "push_device_tokens_update_own" on public.push_device_tokens;
drop policy if exists "push_device_tokens_delete_own" on public.push_device_tokens;

create policy "push_device_tokens_select_own"
on public.push_device_tokens
for select
to authenticated
using (user_id = auth.uid());

create policy "push_device_tokens_update_own"
on public.push_device_tokens
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "push_device_tokens_delete_own"
on public.push_device_tokens
for delete
to authenticated
using (user_id = auth.uid());

create or replace function public.register_push_device_token(
  p_device_token text,
  p_platform text default 'ios',
  p_environment text default 'development'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := lower(btrim(coalesce(p_device_token, '')));
  v_platform text := lower(btrim(coalesce(p_platform, 'ios')));
  v_environment text := lower(btrim(coalesce(p_environment, 'development')));
  v_token_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  if v_token !~ '^[0-9a-f]{32,400}$' then
    raise exception 'invalid device token';
  end if;

  if v_platform not in ('ios', 'ipados') then
    raise exception 'invalid platform';
  end if;

  if v_environment not in ('development', 'production') then
    raise exception 'invalid environment';
  end if;

  update public.push_device_tokens
  set is_active = false,
      last_seen_at = timezone('utc'::text, now())
  where device_token = v_token
    and environment = v_environment
    and user_id is distinct from v_user_id;

  insert into public.push_device_tokens (
    user_id,
    device_token,
    platform,
    environment,
    is_active,
    last_seen_at
  )
  values (
    v_user_id,
    v_token,
    v_platform,
    v_environment,
    true,
    timezone('utc'::text, now())
  )
  on conflict (device_token, environment)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    is_active = true,
    last_seen_at = timezone('utc'::text, now())
  returning id into v_token_id;

  return v_token_id;
end;
$$;

create or replace function public.deactivate_push_device_token(
  p_device_token text,
  p_platform text default 'ios',
  p_environment text default 'development'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := lower(btrim(coalesce(p_device_token, '')));
  v_environment text := lower(btrim(coalesce(p_environment, 'development')));
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  update public.push_device_tokens
  set is_active = false,
      last_seen_at = timezone('utc'::text, now())
  where user_id = v_user_id
    and device_token = v_token
    and environment = v_environment;
end;
$$;

revoke all on public.push_device_tokens from anon;
grant select, update, delete on public.push_device_tokens to authenticated;
revoke all on function public.register_push_device_token(text, text, text) from public;
revoke all on function public.register_push_device_token(text, text, text) from anon;
revoke all on function public.deactivate_push_device_token(text, text, text) from public;
revoke all on function public.deactivate_push_device_token(text, text, text) from anon;
grant execute on function public.register_push_device_token(text, text, text) to authenticated;
grant execute on function public.deactivate_push_device_token(text, text, text) to authenticated;

commit;
