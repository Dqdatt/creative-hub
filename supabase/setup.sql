-- ============================================================
-- Video Ops - Supabase database readiness
-- Phase 7A: schema + RLS only, chưa kết nối CRUD frontend
-- Safe to run in Supabase SQL Editor.
-- ============================================================

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

create or replace function public.set_audit_fields()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.created_by is null then
      new.created_by = auth.uid();
    end if;
    if new.updated_by is null then
      new.updated_by = coalesce(auth.uid(), new.created_by);
    end if;
  elsif tg_op = 'UPDATE' then
    new.updated_by = coalesce(auth.uid(), new.updated_by);
  end if;

  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

-- ------------------------------------------------------------
-- profiles
-- Một dòng hồ sơ nội bộ cho mỗi auth.users.
-- role:
-- - admin: toàn quyền dữ liệu nội bộ
-- - team_lead: quản lý task và lịch quay
-- - editor: đọc dữ liệu, cập nhật task được giao
-- ------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  short_name text not null,
  role text not null default 'editor',
  avatar_url text,
  ui_color text,
  created_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists phone text,
  add column if not exists department text not null default 'Team Marketing',
  add column if not exists display_name text,
  add column if not exists editor_code text,
  add column if not exists crew_key text,
  add column if not exists active boolean not null default true,
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now());

alter table public.profiles
  alter column role set default 'editor',
  alter column department set default 'Team Marketing',
  alter column active set default true,
  alter column updated_at set default timezone('utc'::text, now());

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('admin', 'team_lead', 'editor'));

alter table public.profiles drop constraint if exists profiles_ui_color_check;
alter table public.profiles
  add constraint profiles_ui_color_check
  check (ui_color is null or ui_color ~ '^#[0-9A-Fa-f]{6}$');

create unique index if not exists profiles_email_unique_idx
  on public.profiles (lower(email))
  where email is not null;

create unique index if not exists profiles_editor_code_unique_idx
  on public.profiles (lower(editor_code))
  where editor_code is not null;

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_active_idx on public.profiles (active);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Vai trò ứng dụng của user hiện tại.
-- Dùng SECURITY DEFINER để policy có thể đọc profiles mà không tự lặp RLS.
create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$$;

create or replace function public.is_admin_or_team_lead()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'team_lead'), false);
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_full_name text;
  meta_display_name text;
begin
  meta_full_name := coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1));
  meta_display_name := coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name', meta_full_name);

  insert into public.profiles (
    id,
    email,
    full_name,
    short_name,
    display_name,
    avatar_url,
    phone,
    department,
    role
  )
  values (
    new.id,
    new.email,
    meta_full_name,
    meta_display_name,
    meta_display_name,
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'department', 'Team Marketing'),
    case
      when new.raw_user_meta_data->>'role' in ('admin', 'team_lead', 'editor')
        then new.raw_user_meta_data->>'role'
      else 'editor'
    end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- ------------------------------------------------------------
-- video_tasks
-- Task video theo tháng, giữ nhãn tiếng Việt để frontend hiện tại dễ map.
-- ------------------------------------------------------------

create table if not exists public.video_tasks (
  id uuid primary key default gen_random_uuid(),
  stt bigserial unique,
  title text not null,
  editor_id uuid references public.profiles(id) on delete set null,
  status text not null default 'Chờ',
  order_team text,
  category text,
  priority text not null default '',
  resize_reqs text,
  receive_date date,
  return_date date,
  air_date date,
  result_link text,
  content_plan_id uuid,
  created_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.video_tasks
  add column if not exists content_plan_id uuid,
  add column if not exists created_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists notes text;

alter table public.video_tasks
  alter column status set default 'Chờ',
  alter column priority set default '',
  alter column updated_at set default timezone('utc'::text, now());

-- Chuẩn hóa dữ liệu nếu đã từng chạy setup cũ với status tiếng Anh.
update public.video_tasks
set status = case status
  when 'pending' then 'Chờ'
  when 'in_progress' then 'Đang làm'
  when 'done' then 'Đã xong'
  when 'Chờ' then 'Chờ'
  when 'Đang làm' then 'Đang làm'
  when 'Đã xong' then 'Đã xong'
  else 'Chờ'
end
where status is null or status not in ('Chờ', 'Đang làm', 'Đã xong');

update public.video_tasks
set priority = ''
where priority is null;

update public.video_tasks
set category = null
where category is not null and category not in ('Video dài', 'Motion', 'Ads');

update public.video_tasks
set order_team = null
where order_team is not null and order_team not in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR');

alter table public.video_tasks drop constraint if exists video_tasks_status_check;
alter table public.video_tasks
  add constraint video_tasks_status_check
  check (status in ('Chờ', 'Đang làm', 'Đã xong'));

alter table public.video_tasks drop constraint if exists video_tasks_priority_check;
alter table public.video_tasks
  add constraint video_tasks_priority_check
  check (priority in ('', 'Gấp'));

alter table public.video_tasks drop constraint if exists video_tasks_category_check;
alter table public.video_tasks
  add constraint video_tasks_category_check
  check (category is null or category in ('Video dài', 'Motion', 'Ads'));

alter table public.video_tasks drop constraint if exists video_tasks_order_team_check;
alter table public.video_tasks
  add constraint video_tasks_order_team_check
  check (order_team is null or order_team in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR'));

alter table public.video_tasks drop constraint if exists video_tasks_date_order_check;
alter table public.video_tasks
  add constraint video_tasks_date_order_check
  check (
    return_date is null
    or receive_date is null
    or return_date >= receive_date
  );

create index if not exists video_tasks_editor_id_idx on public.video_tasks (editor_id);
create index if not exists video_tasks_created_by_idx on public.video_tasks (created_by);
create index if not exists video_tasks_status_idx on public.video_tasks (status);
create index if not exists video_tasks_priority_idx on public.video_tasks (priority);
create index if not exists video_tasks_order_team_idx on public.video_tasks (order_team);
create index if not exists video_tasks_receive_date_idx on public.video_tasks (receive_date);
create index if not exists video_tasks_return_date_idx on public.video_tasks (return_date);
create index if not exists video_tasks_air_date_idx on public.video_tasks (air_date);
create index if not exists video_tasks_month_filter_idx
  on public.video_tasks (coalesce(air_date, return_date, receive_date));
create unique index if not exists video_tasks_content_plan_id_unique
  on public.video_tasks (content_plan_id)
  where content_plan_id is not null;

create or replace function public.is_content_plan_assignment_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.content_plan_assignment', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_acceptance_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_acceptance', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_completion_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_completion', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_execution_update_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_execution_update', true) = 'on', false);
$$;

drop trigger if exists video_tasks_set_updated_at on public.video_tasks;
drop trigger if exists video_tasks_set_audit_fields on public.video_tasks;
create trigger video_tasks_set_audit_fields
before insert or update on public.video_tasks
for each row execute function public.set_audit_fields();

create or replace function public.prevent_video_task_content_plan_relink()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.content_plan_id is distinct from old.content_plan_id then
    raise exception 'Không được đổi liên kết Content Plan của Video Task.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.title is distinct from old.title
      or new.category is distinct from old.category
      or new.air_date is distinct from old.air_date
    )
    and not public.is_content_plan_assignment_context() then
    raise exception 'Thông tin kế hoạch của Task liên kết được quản lý từ Content Plan.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.order_team is distinct from old.order_team
      or new.priority is distinct from old.priority
      or new.resize_reqs is distinct from old.resize_reqs
    )
    and not public.is_linked_video_task_execution_update_context() then
    raise exception 'Hãy cập nhật thông tin thực hiện Task liên kết qua thao tác Lưu thay đổi.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and new.editor_id is distinct from old.editor_id
    and not public.is_content_plan_assignment_context() then
    raise exception 'Hãy đổi Editor của Task liên kết từ Content Plan.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status = 'Chờ'
    and (
      new.status is distinct from old.status
      or new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not public.is_linked_video_task_acceptance_context() then
    raise exception 'Hãy nhận Task liên kết qua thao tác Nhận Task.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status in ('Đang làm', 'Đã xong')
    and new.status is distinct from old.status
    and not public.is_linked_video_task_completion_context() then
    raise exception 'Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status in ('Đang làm', 'Đã xong')
    and (
      new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not (
      public.is_linked_video_task_execution_update_context()
      or public.is_linked_video_task_completion_context()
    ) then
    raise exception 'Hãy cập nhật thông tin thực hiện Task liên kết qua thao tác Lưu thay đổi.';
  end if;

  return new;
end;
$$;

drop trigger if exists video_tasks_content_plan_id_immutable_guard on public.video_tasks;
create trigger video_tasks_content_plan_id_immutable_guard
before update on public.video_tasks
for each row execute function public.prevent_video_task_content_plan_relink();

-- ------------------------------------------------------------
-- shoots
-- Lịch quay/livestream/on set theo ngày.
-- ------------------------------------------------------------

create table if not exists public.shoots (
  id uuid primary key default gen_random_uuid(),
  shoot_date date not null,
  shoot_type text not null,
  crew text,
  time_slot text,
  location text,
  content_note text,
  created_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.shoots
  add column if not exists created_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists status text not null default 'scheduled',
  add column if not exists priority text not null default '';

alter table public.shoots
  alter column status set default 'scheduled',
  alter column priority set default '',
  alter column updated_at set default timezone('utc'::text, now());

alter table public.shoots drop constraint if exists shoots_type_check;
alter table public.shoots drop constraint if exists shoots_shoot_type_check;
alter table public.shoots
  add constraint shoots_shoot_type_check
  check (shoot_type in ('livestream', 'lichquay', 'onset', 'other'));

alter table public.shoots drop constraint if exists shoots_status_check;
alter table public.shoots
  add constraint shoots_status_check
  check (status in ('scheduled', 'done', 'cancelled'));

alter table public.shoots drop constraint if exists shoots_priority_check;
alter table public.shoots
  add constraint shoots_priority_check
  check (priority in ('', 'Gấp'));

create index if not exists shoots_shoot_date_idx on public.shoots (shoot_date);
create index if not exists shoots_month_filter_idx on public.shoots (shoot_date);
create index if not exists shoots_type_idx on public.shoots (shoot_type);
create index if not exists shoots_status_idx on public.shoots (status);
create index if not exists shoots_created_by_idx on public.shoots (created_by);

drop trigger if exists shoots_set_updated_at on public.shoots;
drop trigger if exists shoots_set_audit_fields on public.shoots;
create trigger shoots_set_audit_fields
before insert or update on public.shoots
for each row execute function public.set_audit_fields();

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.video_tasks enable row level security;
alter table public.shoots enable row level security;

-- Xóa policy cũ để file có thể chạy lại nhiều lần.
drop policy if exists "Allow authenticated users to read profiles" on public.profiles;
drop policy if exists "Allow authenticated users to update profiles" on public.profiles;
drop policy if exists "Allow authenticated users to do all on video_tasks" on public.video_tasks;
drop policy if exists "Allow authenticated users to do all on shoots" on public.shoots;

drop policy if exists "profiles_select_authenticated" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_insert_admin_team_lead" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_update_admin_team_lead" on public.profiles;
drop policy if exists "profiles_delete_admin" on public.profiles;

drop policy if exists "video_tasks_select_authenticated" on public.video_tasks;
drop policy if exists "video_tasks_insert_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_assigned_or_created" on public.video_tasks;
drop policy if exists "video_tasks_delete_admin_team_lead" on public.video_tasks;

drop policy if exists "shoots_select_authenticated" on public.shoots;
drop policy if exists "shoots_insert_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_created_by" on public.shoots;
drop policy if exists "shoots_delete_admin_team_lead" on public.shoots;

-- profiles: user đã đăng nhập được xem danh sách nhân sự.
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

-- User có thể tạo hồ sơ cho chính mình nếu trigger chưa chạy.
create policy "profiles_insert_self"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and role = 'editor'
);

-- Admin/Team Lead có thể tạo hồ sơ nhân sự.
create policy "profiles_insert_admin_team_lead"
on public.profiles
for insert
to authenticated
with check (public.is_admin_or_team_lead());

-- User được cập nhật hồ sơ của chính mình.
create policy "profiles_update_self"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Admin/Team Lead quản lý hồ sơ nhân sự.
create policy "profiles_update_admin_team_lead"
on public.profiles
for update
to authenticated
using (public.is_admin_or_team_lead())
with check (public.is_admin_or_team_lead());

-- Chỉ admin được xóa hồ sơ nội bộ.
create policy "profiles_delete_admin"
on public.profiles
for delete
to authenticated
using (public.current_profile_role() = 'admin');

-- video_tasks: mọi user đã đăng nhập được đọc task.
create policy "video_tasks_select_authenticated"
on public.video_tasks
for select
to authenticated
using (true);

-- Chỉ Admin/Team Lead được tạo task.
create policy "video_tasks_insert_admin_team_lead"
on public.video_tasks
for insert
to authenticated
with check (
  public.is_admin_or_team_lead()
  and (created_by is null or created_by = auth.uid())
);

-- Admin/Team Lead được cập nhật mọi task.
create policy "video_tasks_update_admin_team_lead"
on public.video_tasks
for update
to authenticated
using (public.is_admin_or_team_lead())
with check (public.is_admin_or_team_lead());

-- Editor được cập nhật task được giao hoặc task do mình tạo.
-- Lưu ý: RLS giới hạn theo dòng, frontend/RPC nên giới hạn field khi cần chặt hơn.
create policy "video_tasks_update_assigned_or_created"
on public.video_tasks
for update
to authenticated
using (
  editor_id = auth.uid()
  or created_by = auth.uid()
)
with check (
  editor_id = auth.uid()
  or created_by = auth.uid()
);

-- Xóa task chỉ dành cho Admin/Team Lead.
create policy "video_tasks_delete_admin_team_lead"
on public.video_tasks
for delete
to authenticated
using (public.is_admin_or_team_lead());

-- shoots: mọi user đã đăng nhập được xem lịch.
create policy "shoots_select_authenticated"
on public.shoots
for select
to authenticated
using (true);

-- Tạo lịch quay dành cho Admin/Team Lead.
create policy "shoots_insert_admin_team_lead"
on public.shoots
for insert
to authenticated
with check (
  public.is_admin_or_team_lead()
  and (created_by is null or created_by = auth.uid())
);

-- Admin/Team Lead được cập nhật mọi lịch.
create policy "shoots_update_admin_team_lead"
on public.shoots
for update
to authenticated
using (public.is_admin_or_team_lead())
with check (public.is_admin_or_team_lead());

-- Người tạo lịch được chỉnh lịch do mình tạo.
create policy "shoots_update_created_by"
on public.shoots
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

-- Xóa lịch quay chỉ dành cho Admin/Team Lead.
create policy "shoots_delete_admin_team_lead"
on public.shoots
for delete
to authenticated
using (public.is_admin_or_team_lead());

-- ------------------------------------------------------------
-- Grants
-- RLS vẫn là lớp quyết định ai được làm gì.
-- ------------------------------------------------------------

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.video_tasks to authenticated;
grant select, insert, update, delete on public.shoots to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Content Plan is installed by supabase/content_plan_schema.sql in this project.
-- Keep existing environments aligned if setup.sql is re-run after Content Plan exists.
do $$
begin
  if to_regclass('public.content_plan') is not null then
    execute 'alter table public.content_plan add column if not exists link text';
    execute 'comment on column public.content_plan.link is ''Link thành phẩm; có link hợp lệ thì dòng được xem là hoàn thành.''';
    execute 'alter table public.video_tasks add column if not exists content_plan_id uuid';

    if not exists (
      select 1
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace nsp on nsp.oid = rel.relnamespace
      where nsp.nspname = 'public'
        and rel.relname = 'video_tasks'
        and con.conname = 'video_tasks_content_plan_id_fkey'
    ) then
      execute 'alter table public.video_tasks add constraint video_tasks_content_plan_id_fkey foreign key (content_plan_id) references public.content_plan(id) on delete cascade';
    end if;

    execute 'create unique index if not exists video_tasks_content_plan_id_unique on public.video_tasks (content_plan_id) where content_plan_id is not null';
    execute 'comment on column public.video_tasks.content_plan_id is ''Optional source Content Plan. Null means manual Video tháng task; non-null generated from Content Plan and cascades on Content Plan delete.''';
  end if;
end $$;

-- ------------------------------------------------------------
-- Internal notifications foundation
-- Phase 5.1: no producers, no push, read-state RPCs only.
-- ------------------------------------------------------------

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

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;

create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

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

comment on table public.profiles is 'Hồ sơ nhân sự nội bộ, gắn 1-1 với auth.users.';
comment on column public.profiles.role is 'Vai trò ứng dụng: admin, team_lead, editor.';
comment on column public.profiles.editor_code is 'Mã editor ngắn để map dữ liệu cũ: dat, hai, minh...';
comment on column public.profiles.crew_key is 'Từ khóa ekip để match lịch quay: ĐẠT, HẢI, MINH...';

comment on table public.video_tasks is 'Danh sách video task theo tháng.';
comment on column public.video_tasks.stt is 'Số thứ tự hiển thị trong bảng task.';
comment on column public.video_tasks.status is 'Trạng thái UI tiếng Việt: Chờ, Đang làm, Đã xong.';
comment on column public.video_tasks.priority is 'Độ ưu tiên UI tiếng Việt: rỗng hoặc Gấp.';
comment on column public.video_tasks.editor_id is 'Editor được giao task, tham chiếu profiles.id.';
comment on column public.video_tasks.content_plan_id is 'Optional source Content Plan. Null means manual Video tháng task; non-null generated from Content Plan and cascades on Content Plan delete.';
comment on column public.video_tasks.created_by is 'Người tạo task.';

comment on table public.shoots is 'Lịch quay, livestream, on set theo ngày.';
comment on column public.shoots.shoot_type is 'Loại lịch: livestream, lichquay, onset, other.';
comment on column public.shoots.status is 'Trạng thái lịch: scheduled, done, cancelled.';
comment on column public.shoots.created_by is 'Người tạo lịch quay.';

comment on table public.notifications is 'Internal per-recipient notifications for CreativeHub. No browser push in Phase 5.1.';
comment on column public.notifications.recipient_id is 'Profile that owns and may read this notification.';
comment on column public.notifications.actor_id is 'Profile whose action caused the notification. Null for system-generated notifications.';
comment on column public.notifications.type is 'Canonical internal notification type.';
comment on column public.notifications.action_url is 'Internal CreativeHub route for future deep linking.';
comment on column public.notifications.event_key is 'Optional backend-generated idempotency key unique per recipient.';
comment on function public.delete_notification(uuid) is 'Deletes one notification owned by auth.uid(); does not grant generic table DELETE.';
comment on function public.delete_notifications_older_than(integer) is 'Deletes notifications owned by auth.uid() where created_at is older than the clamped day cutoff.';

-- Phase 5.2 Calendar notification producer RPCs are maintained in:
-- supabase/calendar_notification_events.sql
-- Run that narrow migration after setup.sql, editor membership, activity logs,
-- permission patches, and the notification foundation for fresh installations.

-- Phase 5.3 Content Plan and linked Video Task notification producer RPCs are maintained in:
-- supabase/content_plan_video_task_notification_events.sql
-- Run that narrow migration after the linked task workflow RPCs and Phase 5.1 notification foundation.
