-- ============================================================
-- CreativeHub - User permission overrides
-- Phase 17.5: quyền xem/chỉnh theo từng tài khoản, nằm trên role baseline.
-- Safe to run trong Supabase SQL Editor sau:
-- 1. supabase/setup.sql
-- 2. supabase/user_management_patch.sql
-- 3. supabase/editor_membership_patch.sql
-- 4. supabase/content_plan_schema.sql
-- ============================================================

begin;

create table if not exists public.user_permission_overrides (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  access_mode text not null default 'role_default',
  dashboard_view boolean,
  calendar_view boolean,
  calendar_edit boolean,
  tasks_view boolean,
  tasks_edit boolean,
  content_plan_view boolean,
  content_plan_edit_content boolean,
  content_plan_assign_editor boolean,
  users_manage boolean,
  profile_edit_self boolean,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  updated_by uuid references public.profiles(id) on delete set null
);

alter table public.user_permission_overrides
  add column if not exists access_mode text not null default 'role_default',
  add column if not exists dashboard_view boolean,
  add column if not exists calendar_view boolean,
  add column if not exists calendar_edit boolean,
  add column if not exists tasks_view boolean,
  add column if not exists tasks_edit boolean,
  add column if not exists content_plan_view boolean,
  add column if not exists content_plan_edit_content boolean,
  add column if not exists content_plan_assign_editor boolean,
  add column if not exists users_manage boolean,
  add column if not exists profile_edit_self boolean,
  add column if not exists created_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists updated_by uuid references public.profiles(id) on delete set null;

alter table public.user_permission_overrides drop constraint if exists user_permission_overrides_access_mode_check;
alter table public.user_permission_overrides
  add constraint user_permission_overrides_access_mode_check
  check (access_mode in ('role_default', 'view_only', 'custom'));

create index if not exists user_permission_overrides_access_mode_idx
  on public.user_permission_overrides (access_mode);

drop trigger if exists user_permission_overrides_set_updated_at on public.user_permission_overrides;
create trigger user_permission_overrides_set_updated_at
before update on public.user_permission_overrides
for each row execute function public.set_updated_at();

create or replace function public.current_user_permission_override()
returns table (
  access_mode text,
  dashboard_view boolean,
  calendar_view boolean,
  calendar_edit boolean,
  tasks_view boolean,
  tasks_edit boolean,
  content_plan_view boolean,
  content_plan_edit_content boolean,
  content_plan_assign_editor boolean,
  users_manage boolean,
  profile_edit_self boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(upo.access_mode, 'role_default') as access_mode,
    upo.dashboard_view,
    upo.calendar_view,
    upo.calendar_edit,
    upo.tasks_view,
    upo.tasks_edit,
    upo.content_plan_view,
    upo.content_plan_edit_content,
    upo.content_plan_assign_editor,
    upo.users_manage,
    upo.profile_edit_self
  from public.profiles p
  left join public.user_permission_overrides upo on upo.profile_id = p.id
  where p.id = auth.uid()
  limit 1;
$$;

create or replace function public.role_baseline_permission(role_name text, permission_key text)
returns boolean
language sql
stable
as $$
  select case
    when permission_key = 'profile_edit_self' then true
    when role_name = 'admin' then true
    when role_name = 'creative_manager' then permission_key in (
      'dashboard_view',
      'calendar_view',
      'calendar_edit',
      'tasks_view',
      'tasks_edit',
      'content_plan_view',
      'content_plan_assign_editor'
    )
    when role_name = 'content_creator' then permission_key in (
      'calendar_view',
      'calendar_edit',
      'content_plan_view',
      'content_plan_edit_content'
    )
    when role_name = 'editor' then permission_key in (
      'dashboard_view',
      'calendar_view',
      'tasks_view',
      'tasks_edit',
      'content_plan_view'
    )
    else false
  end;
$$;

create or replace function public.has_effective_permission(permission_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_override public.user_permission_overrides%rowtype;
begin
  v_role := public.current_profile_role();

  if v_role is null then
    return false;
  end if;

  select *
  into v_override
  from public.user_permission_overrides
  where profile_id = auth.uid()
  limit 1;

  -- users_manage là quyền nhạy cảm: chỉ admin mới có thể có.
  if permission_key = 'users_manage' and v_role <> 'admin' then
    return false;
  end if;

  -- Admin luôn giữ quyền quản lý thành viên để tránh tự khóa hệ thống.
  if permission_key = 'users_manage' and v_role = 'admin' then
    return true;
  end if;

  if v_override.profile_id is null or v_override.access_mode = 'role_default' then
    return public.role_baseline_permission(v_role, permission_key);
  end if;

  if v_override.access_mode = 'view_only' then
    return public.role_baseline_permission(v_role, permission_key)
      and permission_key in (
        'dashboard_view',
        'calendar_view',
        'tasks_view',
        'content_plan_view'
      );
  end if;

  if v_override.access_mode = 'custom' then
    return case permission_key
      when 'dashboard_view' then coalesce(v_override.dashboard_view, false)
      when 'calendar_view' then coalesce(v_override.calendar_view, false) or coalesce(v_override.calendar_edit, false)
      when 'calendar_edit' then coalesce(v_override.calendar_edit, false)
      when 'tasks_view' then coalesce(v_override.tasks_view, false) or coalesce(v_override.tasks_edit, false)
      when 'tasks_edit' then coalesce(v_override.tasks_edit, false)
      when 'content_plan_view' then coalesce(v_override.content_plan_view, false)
        or coalesce(v_override.content_plan_edit_content, false)
        or coalesce(v_override.content_plan_assign_editor, false)
      when 'content_plan_edit_content' then coalesce(v_override.content_plan_edit_content, false)
      when 'content_plan_assign_editor' then coalesce(v_override.content_plan_assign_editor, false)
      when 'profile_edit_self' then coalesce(v_override.profile_edit_self, true)
      else false
    end;
  end if;

  return false;
end;
$$;

create or replace function public.can_edit_video_tasks()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_effective_permission('tasks_edit');
$$;

create or replace function public.can_edit_shoots()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_effective_permission('calendar_edit');
$$;

create or replace function public.can_manage_shoots()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_edit_shoots();
$$;

create or replace function public.can_edit_content_plan_content()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_effective_permission('content_plan_edit_content');
$$;

create or replace function public.can_assign_content_plan_editor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_effective_permission('content_plan_assign_editor');
$$;

create or replace function public.can_manage_content_plan()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_edit_content_plan_content() or public.can_assign_content_plan_editor();
$$;

create or replace function public.enforce_content_plan_field_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_can_edit_content boolean;
  v_can_assign_editor boolean;
begin
  v_can_edit_content := public.can_edit_content_plan_content();
  v_can_assign_editor := public.can_assign_content_plan_editor();

  if tg_op = 'INSERT' then
    if not v_can_edit_content then
      raise exception 'Không có quyền tạo Content Plan.';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if not v_can_edit_content and (
      new.air_date is distinct from old.air_date
      or new.title is distinct from old.title
      or new.note is distinct from old.note
      or new.category is distinct from old.category
    ) then
      raise exception 'Không có quyền chỉnh nội dung Content Plan.';
    end if;

    if not v_can_assign_editor and new.editor_id is distinct from old.editor_id then
      raise exception 'Không có quyền phân công editor Content Plan.';
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists content_plan_field_permission_guard on public.content_plan;
create trigger content_plan_field_permission_guard
before insert or update on public.content_plan
for each row execute function public.enforce_content_plan_field_permissions();

create or replace function public.prevent_self_permission_override()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_admin_count integer;
begin
  if new.profile_id = auth.uid() then
    raise exception 'Không thể tự thay đổi quyền sử dụng của chính mình.';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id = new.profile_id
      and p.role = 'admin'
  ) then
    select count(*)
    into v_active_admin_count
    from public.profiles p
    where p.role = 'admin'
      and coalesce(p.is_active, p.active, true) = true;

    if v_active_admin_count <= 1 and new.access_mode <> 'role_default' then
      raise exception 'Không thể giới hạn quyền của admin hoạt động cuối cùng.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists user_permission_overrides_prevent_self on public.user_permission_overrides;
create trigger user_permission_overrides_prevent_self
before insert or update on public.user_permission_overrides
for each row execute function public.prevent_self_permission_override();

alter table public.user_permission_overrides enable row level security;

drop policy if exists "user_permission_overrides_select_admin_or_self" on public.user_permission_overrides;
drop policy if exists "user_permission_overrides_insert_admin" on public.user_permission_overrides;
drop policy if exists "user_permission_overrides_update_admin" on public.user_permission_overrides;
drop policy if exists "user_permission_overrides_delete_admin" on public.user_permission_overrides;

create policy "user_permission_overrides_select_admin_or_self"
on public.user_permission_overrides
for select
to authenticated
using (public.is_admin() or profile_id = auth.uid());

create policy "user_permission_overrides_insert_admin"
on public.user_permission_overrides
for insert
to authenticated
with check (public.is_admin() and profile_id <> auth.uid());

create policy "user_permission_overrides_update_admin"
on public.user_permission_overrides
for update
to authenticated
using (public.is_admin() and profile_id <> auth.uid())
with check (public.is_admin() and profile_id <> auth.uid());

create policy "user_permission_overrides_delete_admin"
on public.user_permission_overrides
for delete
to authenticated
using (public.is_admin() and profile_id <> auth.uid());

-- Hồ sơ cá nhân: vẫn admin quản lý tất cả, user tự sửa hồ sơ nếu effective permission cho phép.
drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles
for update
to authenticated
using (id = auth.uid() and public.has_effective_permission('profile_edit_self'))
with check (id = auth.uid() and public.has_effective_permission('profile_edit_self'));

-- ------------------------------------------------------------
-- RLS: video_tasks
-- ------------------------------------------------------------

drop policy if exists "video_tasks_select_authenticated" on public.video_tasks;
drop policy if exists "video_tasks_insert_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_assigned_or_created" on public.video_tasks;
drop policy if exists "video_tasks_delete_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_select_effective" on public.video_tasks;
drop policy if exists "video_tasks_insert_effective" on public.video_tasks;
drop policy if exists "video_tasks_update_effective" on public.video_tasks;
drop policy if exists "video_tasks_delete_effective" on public.video_tasks;

create policy "video_tasks_select_effective"
on public.video_tasks
for select
to authenticated
using (public.has_effective_permission('tasks_view'));

create policy "video_tasks_insert_effective"
on public.video_tasks
for insert
to authenticated
with check (
  public.can_edit_video_tasks()
  and (created_by is null or created_by = auth.uid())
);

create policy "video_tasks_update_effective"
on public.video_tasks
for update
to authenticated
using (public.can_edit_video_tasks())
with check (public.can_edit_video_tasks());

create policy "video_tasks_delete_effective"
on public.video_tasks
for delete
to authenticated
using (public.can_edit_video_tasks());

-- ------------------------------------------------------------
-- RLS: shoots + shoot_editors
-- ------------------------------------------------------------

drop policy if exists "shoots_select_authenticated" on public.shoots;
drop policy if exists "shoots_insert_managers" on public.shoots;
drop policy if exists "shoots_update_managers" on public.shoots;
drop policy if exists "shoots_delete_managers" on public.shoots;
drop policy if exists "shoots_select_effective" on public.shoots;
drop policy if exists "shoots_insert_effective" on public.shoots;
drop policy if exists "shoots_update_effective" on public.shoots;
drop policy if exists "shoots_delete_effective" on public.shoots;

create policy "shoots_select_effective"
on public.shoots
for select
to authenticated
using (public.has_effective_permission('calendar_view'));

create policy "shoots_insert_effective"
on public.shoots
for insert
to authenticated
with check (
  public.can_edit_shoots()
  and (created_by is null or created_by = auth.uid())
);

create policy "shoots_update_effective"
on public.shoots
for update
to authenticated
using (public.can_edit_shoots())
with check (public.can_edit_shoots());

create policy "shoots_delete_effective"
on public.shoots
for delete
to authenticated
using (public.can_edit_shoots());

drop policy if exists "shoot_editors_select_authenticated" on public.shoot_editors;
drop policy if exists "shoot_editors_insert_managers" on public.shoot_editors;
drop policy if exists "shoot_editors_delete_managers" on public.shoot_editors;
drop policy if exists "shoot_editors_select_effective" on public.shoot_editors;
drop policy if exists "shoot_editors_insert_effective" on public.shoot_editors;
drop policy if exists "shoot_editors_delete_effective" on public.shoot_editors;

create policy "shoot_editors_select_effective"
on public.shoot_editors
for select
to authenticated
using (public.has_effective_permission('calendar_view'));

create policy "shoot_editors_insert_effective"
on public.shoot_editors
for insert
to authenticated
with check (
  public.can_edit_shoots()
  and (created_by is null or created_by = auth.uid())
);

create policy "shoot_editors_delete_effective"
on public.shoot_editors
for delete
to authenticated
using (public.can_edit_shoots());

-- ------------------------------------------------------------
-- RLS: content_plan
-- ------------------------------------------------------------

drop policy if exists "content_plan_select_authenticated" on public.content_plan;
drop policy if exists "content_plan_insert_managers" on public.content_plan;
drop policy if exists "content_plan_update_managers" on public.content_plan;
drop policy if exists "content_plan_delete_managers" on public.content_plan;
drop policy if exists "content_plan_select_effective" on public.content_plan;
drop policy if exists "content_plan_insert_effective" on public.content_plan;
drop policy if exists "content_plan_update_effective" on public.content_plan;
drop policy if exists "content_plan_delete_effective" on public.content_plan;

create policy "content_plan_select_effective"
on public.content_plan
for select
to authenticated
using (public.has_effective_permission('content_plan_view'));

create policy "content_plan_insert_effective"
on public.content_plan
for insert
to authenticated
with check (
  public.can_edit_content_plan_content()
  and (created_by is null or created_by = auth.uid())
);

create policy "content_plan_update_effective"
on public.content_plan
for update
to authenticated
using (public.can_edit_content_plan_content() or public.can_assign_content_plan_editor())
with check (public.can_edit_content_plan_content() or public.can_assign_content_plan_editor());

create policy "content_plan_delete_effective"
on public.content_plan
for delete
to authenticated
using (public.can_edit_content_plan_content());

grant select, insert, update, delete on public.user_permission_overrides to authenticated;
grant execute on function public.current_user_permission_override() to authenticated;
grant execute on function public.has_effective_permission(text) to authenticated;
grant execute on function public.can_edit_video_tasks() to authenticated;
grant execute on function public.can_edit_shoots() to authenticated;
grant execute on function public.can_edit_content_plan_content() to authenticated;
grant execute on function public.can_assign_content_plan_editor() to authenticated;

comment on table public.user_permission_overrides is 'Quyền sử dụng theo từng tài khoản, nằm trên role baseline.';
comment on column public.user_permission_overrides.access_mode is 'role_default, view_only hoặc custom.';
comment on column public.user_permission_overrides.users_manage is 'Quyền quản lý thành viên. Helper vẫn khóa admin-only.';

commit;
