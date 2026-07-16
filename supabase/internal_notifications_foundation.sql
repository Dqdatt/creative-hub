-- ============================================================
-- CreativeHub - Internal notification foundation
-- Phase 5.1: internal storage, read-state RPCs, and Realtime readiness.
-- Safe to run in Supabase SQL Editor after setup.sql and role/profile patches.
-- ============================================================

begin;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  action_url text,
  metadata jsonb not null default '{}'::jsonb,
  event_key text,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.notifications
  add column if not exists recipient_id uuid references public.profiles(id) on delete cascade,
  add column if not exists actor_id uuid references public.profiles(id) on delete set null,
  add column if not exists type text,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists entity_type text,
  add column if not exists entity_id uuid,
  add column if not exists action_url text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists event_key text,
  add column if not exists read_at timestamptz,
  add column if not exists created_at timestamptz not null default timezone('utc'::text, now());

update public.notifications
set metadata = '{}'::jsonb
where metadata is null;

alter table public.notifications
  alter column id set default gen_random_uuid(),
  alter column recipient_id set not null,
  alter column type set not null,
  alter column title set not null,
  alter column body set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  alter column created_at set default timezone('utc'::text, now()),
  alter column created_at set not null;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'shoot_created',
    'shoot_updated',
    'shoot_cancelled',
    'shoot_member_added',
    'shoot_member_removed',
    'content_plan_created',
    'content_plan_assigned',
    'content_plan_reassigned',
    'content_plan_deleted',
    'video_task_created',
    'video_task_accepted',
    'video_task_execution_updated',
    'video_task_completed',
    'video_task_deleted'
  ));

alter table public.notifications drop constraint if exists notifications_entity_type_check;
alter table public.notifications
  add constraint notifications_entity_type_check
  check (entity_type is null or entity_type in ('shoot', 'content_plan', 'video_task'));

alter table public.notifications drop constraint if exists notifications_entity_pair_check;
alter table public.notifications
  add constraint notifications_entity_pair_check
  check (
    (entity_type is null and entity_id is null)
    or (entity_type is not null and entity_id is not null)
  );

alter table public.notifications drop constraint if exists notifications_action_url_internal_check;
alter table public.notifications
  add constraint notifications_action_url_internal_check
  check (action_url is null or action_url ~ '^/[A-Za-z0-9/_?=&.%:-]*$');

alter table public.notifications drop constraint if exists notifications_metadata_object_check;
alter table public.notifications
  add constraint notifications_metadata_object_check
  check (jsonb_typeof(metadata) = 'object');

create index if not exists notifications_recipient_created_at_desc_idx
  on public.notifications (recipient_id, created_at desc);

create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id)
  where read_at is null;

create unique index if not exists notifications_recipient_event_key_unique
  on public.notifications (recipient_id, event_key)
  where event_key is not null;

create index if not exists notifications_entity_idx
  on public.notifications (entity_type, entity_id)
  where entity_type is not null and entity_id is not null;

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;

create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

-- Kept restrictive as a defense-in-depth policy. Table UPDATE is not granted
-- to app clients; read state changes go through dedicated RPCs below.
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

-- ------------------------------------------------------------
-- Internal creation helper for future trusted business RPCs.
-- Not granted to anon/authenticated clients.
-- ------------------------------------------------------------

create or replace function public.create_internal_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_entity_type text default null,
  p_entity_id uuid default null,
  p_action_url text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_event_key text default null
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification public.notifications;
begin
  if p_recipient_id is null then
    raise exception 'recipient_id is required';
  end if;

  if not exists (select 1 from public.profiles where id = p_recipient_id) then
    raise exception 'recipient profile not found';
  end if;

  if p_actor_id is not null and not exists (select 1 from public.profiles where id = p_actor_id) then
    raise exception 'actor profile not found';
  end if;

  if p_title is null or btrim(p_title) = '' then
    raise exception 'notification title is required';
  end if;

  if p_body is null or btrim(p_body) = '' then
    raise exception 'notification body is required';
  end if;

  if p_action_url is not null and p_action_url !~ '^/[A-Za-z0-9/_?=&.%:-]*$' then
    raise exception 'notification action_url must be an internal route';
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    action_url,
    metadata,
    event_key
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_type,
    btrim(p_title),
    btrim(p_body),
    p_entity_type,
    p_entity_id,
    p_action_url,
    coalesce(p_metadata, '{}'::jsonb),
    nullif(btrim(coalesce(p_event_key, '')), '')
  )
  on conflict (recipient_id, event_key) where event_key is not null
  do update set event_key = excluded.event_key
  returning * into v_notification;

  return v_notification;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_read_at timestamptz;
begin
  if p_notification_id is null then
    raise exception 'notification_id is required';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, timezone('utc'::text, now()))
  where id = p_notification_id
    and recipient_id = auth.uid()
  returning read_at into v_read_at;

  if v_read_at is null then
    raise exception 'notification not found';
  end if;

  return v_read_at;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.notifications
  set read_at = timezone('utc'::text, now())
  where recipient_id = auth.uid()
    and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.delete_notification(p_notification_id uuid)
returns table (
  notification_id uuid,
  was_unread boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa thông báo.' using errcode = '42501';
  end if;

  if p_notification_id is null then
    raise exception 'notification_id is required';
  end if;

  select n.id, n.read_at is null
  into notification_id, was_unread
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_id = v_actor_id;

  if notification_id is null then
    raise exception 'Không tìm thấy thông báo.' using errcode = '42501';
  end if;

  delete from public.notifications n
  where n.id = notification_id
    and n.recipient_id = v_actor_id;

  return next;
end;
$$;

create or replace function public.delete_notifications_older_than(p_days integer default 15)
returns table (
  deleted_count integer,
  unread_deleted_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_days integer;
  v_cutoff timestamptz;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa thông báo.' using errcode = '42501';
  end if;

  v_days := least(greatest(coalesce(p_days, 15), 1), 365);
  v_cutoff := timezone('utc'::text, now()) - make_interval(days => v_days);

  with deleted as (
    delete from public.notifications n
    where n.recipient_id = v_actor_id
      and n.created_at < v_cutoff
    returning n.read_at
  )
  select count(*)::integer,
         count(*) filter (where read_at is null)::integer
  into deleted_count,
       unread_deleted_count
  from deleted;

  return next;
end;
$$;

-- ------------------------------------------------------------
-- Grants
-- ------------------------------------------------------------

grant usage on schema public to authenticated;
grant select on public.notifications to authenticated;
revoke all on public.notifications from public;
revoke all on public.notifications from anon;
revoke insert, update, delete on public.notifications from anon, authenticated;

revoke execute on function public.create_internal_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from public;
revoke execute on function public.create_internal_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from anon;
revoke execute on function public.create_internal_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from authenticated;

revoke execute on function public.mark_notification_read(uuid) from public;
revoke execute on function public.mark_all_notifications_read() from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
revoke execute on function public.mark_notification_read(uuid) from anon;
revoke execute on function public.mark_all_notifications_read() from anon;
revoke execute on function public.delete_notification(uuid) from public;
revoke execute on function public.delete_notifications_older_than(integer) from public;
grant execute on function public.delete_notification(uuid) to authenticated;
grant execute on function public.delete_notifications_older_than(integer) to authenticated;
revoke execute on function public.delete_notification(uuid) from anon;
revoke execute on function public.delete_notifications_older_than(integer) from anon;

-- ------------------------------------------------------------
-- Realtime publication
-- ------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- ------------------------------------------------------------
-- Comments
-- ------------------------------------------------------------

comment on table public.notifications is 'Internal per-recipient notifications for CreativeHub. No browser push in Phase 5.1.';
comment on column public.notifications.recipient_id is 'Profile that owns and may read this notification.';
comment on column public.notifications.actor_id is 'Profile whose action caused the notification. Null for system-generated notifications.';
comment on column public.notifications.type is 'Canonical internal notification type.';
comment on column public.notifications.action_url is 'Internal CreativeHub route for future deep linking.';
comment on column public.notifications.event_key is 'Optional backend-generated idempotency key unique per recipient.';
comment on function public.mark_notification_read(uuid) is 'Marks one notification read for auth.uid(); does not alter notification content.';
comment on function public.mark_all_notifications_read() is 'Marks all unread notifications for auth.uid() as read.';
comment on function public.delete_notification(uuid) is 'Deletes one notification owned by auth.uid(); does not grant generic table DELETE.';
comment on function public.delete_notifications_older_than(integer) is 'Deletes notifications owned by auth.uid() where created_at is older than the clamped day cutoff.';
comment on function public.create_internal_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) is 'Trusted SQL helper for future business RPCs; not executable by browser clients.';

commit;

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'notifications'
order by ordinal_position;

select
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename = 'notifications'
order by policyname;
