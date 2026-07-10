-- ============================================================
-- Video Ops - Editor membership + shoot editor assignments
-- Phase 13.4: tách vai trò khỏi tư cách thành viên team editor
-- Safe to run trong Supabase SQL Editor sau setup.sql và user_management_patch.sql.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. profiles: editor membership độc lập với role
-- ------------------------------------------------------------

alter table public.profiles
  add column if not exists is_editor_member boolean not null default false;

update public.profiles
set is_editor_member = true
where role = 'editor'
   or editor_code is not null;

alter table public.profiles
  alter column is_editor_member set default false,
  alter column is_editor_member set not null;

create index if not exists profiles_is_editor_member_idx
  on public.profiles (is_editor_member);

comment on column public.profiles.is_editor_member is
  'True nếu user tham gia team editor và xuất hiện trong dropdown phân công/workload. Độc lập với role.';

comment on column public.profiles.crew_key is
  'Giữ để tương thích dữ liệu cũ. Không dùng làm tiêu chí editor membership mới.';

-- ------------------------------------------------------------
-- 2. Helper quyền quản lý lịch quay
-- ------------------------------------------------------------

create or replace function public.can_manage_shoots()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_profile_role() in ('admin', 'creative_manager', 'content_creator', 'team_lead'),
    false
  );
$$;

-- ------------------------------------------------------------
-- 3. shoot_editors: editor được phân công vào lịch quay
-- ------------------------------------------------------------

create table if not exists public.shoot_editors (
  shoot_id uuid not null references public.shoots(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  created_by uuid references public.profiles(id) on delete set null,
  primary key (shoot_id, profile_id)
);

create index if not exists shoot_editors_shoot_id_idx
  on public.shoot_editors (shoot_id);

create index if not exists shoot_editors_profile_id_idx
  on public.shoot_editors (profile_id);

alter table public.shoot_editors enable row level security;

drop policy if exists "shoot_editors_select_authenticated" on public.shoot_editors;
drop policy if exists "shoot_editors_insert_managers" on public.shoot_editors;
drop policy if exists "shoot_editors_delete_managers" on public.shoot_editors;

-- Mọi user đăng nhập xem được editor được gán cho lịch quay.
create policy "shoot_editors_select_authenticated"
on public.shoot_editors
for select
to authenticated
using (true);

-- Admin/Creative Manager/Content Creator quản lý phân công editor cho lịch quay.
create policy "shoot_editors_insert_managers"
on public.shoot_editors
for insert
to authenticated
with check (
  public.can_manage_shoots()
  and (created_by is null or created_by = auth.uid())
);

create policy "shoot_editors_delete_managers"
on public.shoot_editors
for delete
to authenticated
using (public.can_manage_shoots());

grant select, insert, delete on public.shoot_editors to authenticated;
grant execute on function public.can_manage_shoots() to authenticated;

-- ------------------------------------------------------------
-- 4. Vá quyền CRUD cho bảng shoots theo workflow hiện tại
--    Không cần chạy role_permissions_patch.sql lớn.
-- ------------------------------------------------------------

drop policy if exists "shoots_insert_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_created_by" on public.shoots;
drop policy if exists "shoots_delete_admin_team_lead" on public.shoots;
drop policy if exists "shoots_insert_managers" on public.shoots;
drop policy if exists "shoots_update_managers" on public.shoots;
drop policy if exists "shoots_delete_managers" on public.shoots;

-- Admin/Creative Manager/Content Creator được tạo lịch quay.
create policy "shoots_insert_managers"
on public.shoots
for insert
to authenticated
with check (
  public.can_manage_shoots()
  and (created_by is null or created_by = auth.uid())
);

-- Admin/Creative Manager/Content Creator được cập nhật lịch quay.
create policy "shoots_update_managers"
on public.shoots
for update
to authenticated
using (public.can_manage_shoots())
with check (public.can_manage_shoots());

-- Admin/Creative Manager/Content Creator được xóa lịch quay.
create policy "shoots_delete_managers"
on public.shoots
for delete
to authenticated
using (public.can_manage_shoots());

-- Realtime cho dashboard/calendar khi phân công editor lịch quay thay đổi.
do $$
begin
  alter publication supabase_realtime add table public.shoot_editors;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;

comment on table public.shoot_editors is
  'Bảng nối lịch quay với editor được phân công, dùng cho calendar và workload.';
comment on column public.shoot_editors.shoot_id is 'Lịch quay được phân công editor.';
comment on column public.shoot_editors.profile_id is 'Profile editor member được phân công.';

commit;
