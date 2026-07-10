-- ============================================================
-- Video Ops - User Management patch
-- Phase 13: chuẩn bị hồ sơ, role và quyền admin quản lý thành viên
-- Safe to run trong Supabase SQL Editor sau khi đã chạy setup.sql.
-- Không tự động tạo Auth user. Auth user nên tạo qua Edge Function create-user.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. Bổ sung cột phục vụ quản lý thành viên
-- ------------------------------------------------------------

alter table public.profiles
  add column if not exists phone text,
  add column if not exists department text not null default 'Team Marketing',
  add column if not exists display_name text,
  add column if not exists editor_code text,
  add column if not exists crew_key text,
  add column if not exists active boolean not null default true,
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now());

update public.profiles
set is_active = active
where active is not null;

update public.profiles
set active = is_active
where active is distinct from is_active;

alter table public.profiles
  alter column role set default 'editor',
  alter column department set default 'Team Marketing',
  alter column active set default true,
  alter column is_active set default true,
  alter column updated_at set default timezone('utc'::text, now());

-- ------------------------------------------------------------
-- 2. Chuẩn hóa role theo workflow thật
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
  add constraint profiles_role_check
  check (role in ('admin', 'creative_manager', 'content_creator', 'editor'));

create unique index if not exists profiles_editor_code_unique_idx
  on public.profiles (lower(editor_code))
  where editor_code is not null;

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_active_idx on public.profiles (active);
create index if not exists profiles_is_active_idx on public.profiles (is_active);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 3. Helper functions
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

-- Backward compatibility cho setup.sql/policy cũ.
create or replace function public.is_admin_or_team_lead()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('admin', 'creative_manager'), false);
$$;

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

-- User mới lấy role từ auth metadata nếu hợp lệ.
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
    role,
    active,
    is_active
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
    end,
    true,
    true
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ------------------------------------------------------------
-- 4. RLS cho profiles
-- ------------------------------------------------------------

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_insert_admin_team_lead" on public.profiles;
drop policy if exists "profiles_insert_admin" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_update_admin_team_lead" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;
drop policy if exists "profiles_delete_admin" on public.profiles;

-- Mọi user đăng nhập được đọc danh sách team cho chip/assignment.
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

-- Chỉ admin tạo hồ sơ thủ công.
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

-- Admin cập nhật tất cả hồ sơ, gồm role và trạng thái hoạt động.
create policy "profiles_update_admin"
on public.profiles
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Chỉ admin được xóa hồ sơ nội bộ.
create policy "profiles_delete_admin"
on public.profiles
for delete
to authenticated
using (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;

-- ------------------------------------------------------------
-- Comments
-- ------------------------------------------------------------

comment on column public.profiles.is_active is 'Trạng thái hoạt động cho User Management. Đồng bộ với active để tương thích dữ liệu cũ.';
comment on column public.profiles.editor_code is 'Mã editor ngắn để map task/content: dat, hai, minh...';
comment on column public.profiles.crew_key is 'Từ khóa ekip để match lịch quay: ĐẠT, HẢI, MINH...';

commit;
