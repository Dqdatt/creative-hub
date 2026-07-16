-- ============================================================
-- Video Ops - Activity Log schema
-- Phase 12: nền tảng activity trước khi xây notification
-- Safe to run trong Supabase SQL Editor sau khi đã chạy setup.sql.
-- ============================================================

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  entity_type text not null,
  entity_id uuid,
  action text not null,
  title text,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.activity_logs
  add column if not exists actor_id uuid references public.profiles(id) on delete set null,
  add column if not exists entity_type text,
  add column if not exists entity_id uuid,
  add column if not exists action text,
  add column if not exists title text,
  add column if not exists description text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default timezone('utc'::text, now());

update public.activity_logs
set entity_type = 'profile'
where entity_type is null;

update public.activity_logs
set action = 'updated'
where action is null;

update public.activity_logs
set metadata = '{}'::jsonb
where metadata is null;

alter table public.activity_logs
  alter column id set default gen_random_uuid(),
  alter column entity_type set not null,
  alter column action set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  alter column created_at set default timezone('utc'::text, now()),
  alter column created_at set not null;

alter table public.activity_logs drop constraint if exists activity_logs_entity_type_check;
alter table public.activity_logs
  add constraint activity_logs_entity_type_check
  check (entity_type in ('video_task', 'shoot', 'content_plan', 'profile'));

alter table public.activity_logs drop constraint if exists activity_logs_action_check;
alter table public.activity_logs
  add constraint activity_logs_action_check
  check (action in (
    'created',
    'updated',
    'deleted',
    'status_changed',
    'assigned',
    'uploaded',
    'password_changed',
    'content_plan_assigned',
    'content_plan_reassigned',
    'video_task_generated',
    'video_task_editor_changed',
    'video_task_accepted',
    'video_task_execution_updated',
    'video_task_completed',
    'content_plan_completed'
  ));

create index if not exists activity_logs_actor_id_idx
  on public.activity_logs (actor_id);

create index if not exists activity_logs_entity_idx
  on public.activity_logs (entity_type, entity_id);

create index if not exists activity_logs_created_at_desc_idx
  on public.activity_logs (created_at desc);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.activity_logs enable row level security;

drop policy if exists "activity_logs_select_authenticated" on public.activity_logs;
drop policy if exists "activity_logs_insert_authenticated" on public.activity_logs;
drop policy if exists "activity_logs_delete_admin" on public.activity_logs;

-- Tất cả user đã đăng nhập được xem activity để phục vụ dashboard/notification sau này.
create policy "activity_logs_select_authenticated"
on public.activity_logs
for select
to authenticated
using (true);

-- App client được ghi log cho chính user hiện tại.
create policy "activity_logs_insert_authenticated"
on public.activity_logs
for insert
to authenticated
with check (actor_id = auth.uid());

-- Chỉ admin được xóa log. Bình thường không nên xóa activity log.
create policy "activity_logs_delete_admin"
on public.activity_logs
for delete
to authenticated
using (public.current_profile_role() = 'admin');

-- ------------------------------------------------------------
-- Grants
-- RLS vẫn là lớp quyết định ai được làm gì.
-- ------------------------------------------------------------

grant usage on schema public to authenticated;
grant select, insert, delete on public.activity_logs to authenticated;

-- ------------------------------------------------------------
-- Comments
-- ------------------------------------------------------------

comment on table public.activity_logs is 'Nhật ký hoạt động dùng làm nền cho notification.';
comment on column public.activity_logs.actor_id is 'User thực hiện hành động, tham chiếu profiles.id.';
comment on column public.activity_logs.entity_type is 'Loại dữ liệu bị tác động: video_task, shoot, content_plan, profile.';
comment on column public.activity_logs.entity_id is 'ID dòng dữ liệu bị tác động nếu có.';
comment on column public.activity_logs.action is 'Hành động: created, updated, deleted, status_changed, assigned, uploaded, password_changed.';
comment on column public.activity_logs.metadata is 'Thông tin phụ dạng JSON để notification dùng sau này.';
