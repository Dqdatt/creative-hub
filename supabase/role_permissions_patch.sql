-- ============================================================
-- Video Ops - Role permissions patch
-- Phase 8.5B: cập nhật role thật và RLS cho workflow hiện tại.
-- Safe to run sau supabase/setup.sql và supabase/seed.sql.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. Chuẩn hóa role trong profiles
-- ------------------------------------------------------------

alter table public.profiles drop constraint if exists profiles_role_check;

update public.profiles
set role = 'creative_manager'
where role = 'team_lead';

update public.profiles
set role = 'editor'
where role is null
   or role not in ('admin', 'creative_manager', 'content_creator', 'editor');

alter table public.profiles
  alter column role set default 'editor';

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('admin', 'creative_manager', 'content_creator', 'editor'));

-- ------------------------------------------------------------
-- 2. Helper functions
-- Dùng SECURITY DEFINER để policy đọc được profiles mà không tự lặp RLS.
-- ------------------------------------------------------------

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p.role = 'team_lead' then 'creative_manager'
    when p.role in ('admin', 'creative_manager', 'content_creator', 'editor') then p.role
    else null
  end
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() = 'admin', false);
$$;

create or replace function public.is_creative_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() = 'creative_manager', false);
$$;

create or replace function public.can_manage_video_tasks()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'creative_manager'), false);
$$;

create or replace function public.can_manage_shoots()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'creative_manager', 'content_creator'), false);
$$;

create or replace function public.can_read_video_tasks()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'creative_manager', 'editor'), false);
$$;

create or replace function public.can_read_shoots()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'creative_manager', 'content_creator', 'editor'), false);
$$;

-- Backward compatibility cho setup.sql cũ hoặc policy cũ.
create or replace function public.is_admin_or_team_lead()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_video_tasks();
$$;

-- Trigger bảo vệ role: user tự cập nhật hồ sơ không được tự nâng quyền.
create or replace function public.prevent_self_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'Không có quyền thay đổi vai trò người dùng.';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_prevent_self_role_escalation on public.profiles;
create trigger profiles_prevent_self_role_escalation
before update on public.profiles
for each row execute function public.prevent_self_role_escalation();

-- User mới lấy role từ auth metadata nếu hợp lệ, map team_lead cũ sang creative_manager.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_full_name text;
  meta_display_name text;
  meta_role text;
begin
  meta_full_name := coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1));
  meta_display_name := coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name', meta_full_name);
  meta_role := new.raw_user_meta_data->>'role';

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
      when meta_role = 'team_lead' then 'creative_manager'
      when meta_role in ('admin', 'creative_manager', 'content_creator', 'editor') then meta_role
      else 'editor'
    end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ------------------------------------------------------------
-- 3. RLS policies
-- ------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.video_tasks enable row level security;
alter table public.shoots enable row level security;

-- Xóa policy cũ và policy patch để file chạy lại an toàn.
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
drop policy if exists "profiles_insert_admin" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;

drop policy if exists "video_tasks_select_authenticated" on public.video_tasks;
drop policy if exists "video_tasks_insert_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_update_assigned_or_created" on public.video_tasks;
drop policy if exists "video_tasks_delete_admin_team_lead" on public.video_tasks;
drop policy if exists "video_tasks_select_allowed_roles" on public.video_tasks;
drop policy if exists "video_tasks_insert_managers" on public.video_tasks;
drop policy if exists "video_tasks_update_managers" on public.video_tasks;
drop policy if exists "video_tasks_delete_managers" on public.video_tasks;

drop policy if exists "shoots_select_authenticated" on public.shoots;
drop policy if exists "shoots_insert_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_created_by" on public.shoots;
drop policy if exists "shoots_delete_admin_team_lead" on public.shoots;
drop policy if exists "shoots_select_allowed_roles" on public.shoots;
drop policy if exists "shoots_insert_managers" on public.shoots;
drop policy if exists "shoots_update_managers" on public.shoots;
drop policy if exists "shoots_delete_managers" on public.shoots;

-- profiles: mọi user đăng nhập được đọc dữ liệu team cần cho chip/assignment.
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

-- User có thể tạo hồ sơ chính mình nếu trigger auth chưa chạy.
create policy "profiles_insert_self"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and role = 'editor'
);

-- Chỉ admin tạo hồ sơ nhân sự thủ công.
create policy "profiles_insert_admin"
on public.profiles
for insert
to authenticated
with check (public.is_admin());

-- User cập nhật hồ sơ chính mình. Trigger chặn tự đổi role.
create policy "profiles_update_self"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Admin cập nhật mọi hồ sơ.
create policy "profiles_update_admin"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Chỉ admin xóa hồ sơ nội bộ.
create policy "profiles_delete_admin"
on public.profiles
for delete
to authenticated
using (public.is_admin());

-- video_tasks:
-- admin/creative_manager/editor đọc toàn bộ bảng editor team.
-- content_creator không có quyền đọc bảng video_tasks.
create policy "video_tasks_select_allowed_roles"
on public.video_tasks
for select
to authenticated
using (public.can_read_video_tasks());

-- admin/creative_manager quản lý CRUD video tasks.
create policy "video_tasks_insert_managers"
on public.video_tasks
for insert
to authenticated
with check (
  public.can_manage_video_tasks()
  and (created_by is null or created_by = auth.uid())
);

create policy "video_tasks_update_managers"
on public.video_tasks
for update
to authenticated
using (public.can_manage_video_tasks())
with check (public.can_manage_video_tasks());

create policy "video_tasks_delete_managers"
on public.video_tasks
for delete
to authenticated
using (public.can_manage_video_tasks());

-- shoots:
-- tất cả role đọc lịch quay, editor chỉ đọc.
create policy "shoots_select_allowed_roles"
on public.shoots
for select
to authenticated
using (public.can_read_shoots());

-- admin/creative_manager/content_creator quản lý lịch quay.
create policy "shoots_insert_managers"
on public.shoots
for insert
to authenticated
with check (
  public.can_manage_shoots()
  and (created_by is null or created_by = auth.uid())
);

create policy "shoots_update_managers"
on public.shoots
for update
to authenticated
using (public.can_manage_shoots())
with check (public.can_manage_shoots());

create policy "shoots_delete_managers"
on public.shoots
for delete
to authenticated
using (public.can_manage_shoots());

-- ------------------------------------------------------------
-- 4. Grants và comments
-- RLS là lớp quyết định cuối cùng.
-- ------------------------------------------------------------

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.video_tasks to authenticated;
grant select, insert, update, delete on public.shoots to authenticated;
grant usage, select on all sequences in schema public to authenticated;

grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_creative_manager() to authenticated;
grant execute on function public.can_manage_video_tasks() to authenticated;
grant execute on function public.can_manage_shoots() to authenticated;
grant execute on function public.can_read_video_tasks() to authenticated;
grant execute on function public.can_read_shoots() to authenticated;
grant execute on function public.is_admin_or_team_lead() to authenticated;

comment on column public.profiles.role is 'Vai trò ứng dụng: admin, creative_manager, content_creator, editor.';
comment on function public.current_profile_role() is 'Role ứng dụng của user hiện tại, đã chuẩn hóa team_lead cũ.';
comment on function public.can_manage_video_tasks() is 'Admin và creative_manager được quản lý Video tháng.';
comment on function public.can_manage_shoots() is 'Admin, creative_manager và content_creator được quản lý Lịch quay.';

commit;

-- ------------------------------------------------------------
-- Kiểm tra nhanh sau khi chạy patch
-- ------------------------------------------------------------

select role, count(*) as total
from public.profiles
group by role
order by role;

select policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'video_tasks', 'shoots')
order by tablename, policyname;
