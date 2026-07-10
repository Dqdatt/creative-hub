-- ============================================================
-- Video Ops - Shoot editor assignment RLS patch
-- Phase 13.6: đảm bảo Admin/Creative Manager/Content Creator
-- đều lưu được phân công editor cho Lịch quay.
--
-- Safe to run trong Supabase SQL Editor sau:
-- 1. supabase/setup.sql
-- 2. supabase/user_management_patch.sql
-- 3. supabase/editor_membership_patch.sql
-- ============================================================

begin;

-- Role helper dùng bởi shoots và shoot_editors.
-- Giữ team_lead để tương thích dữ liệu cũ, nhưng workflow mới dùng creative_manager.
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

grant execute on function public.can_manage_shoots() to authenticated;

-- ------------------------------------------------------------
-- shoot_editors: mọi user đăng nhập được xem,
-- chỉ Admin/Creative Manager/Content Creator được ghi/xóa.
-- ------------------------------------------------------------

alter table public.shoot_editors enable row level security;

drop policy if exists "shoot_editors_select_authenticated" on public.shoot_editors;
drop policy if exists "shoot_editors_insert_managers" on public.shoot_editors;
drop policy if exists "shoot_editors_delete_managers" on public.shoot_editors;

create policy "shoot_editors_select_authenticated"
on public.shoot_editors
for select
to authenticated
using (true);

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

-- ------------------------------------------------------------
-- shoots: vá lại CRUD lịch quay theo workflow hiện tại.
-- ------------------------------------------------------------

drop policy if exists "shoots_insert_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_admin_team_lead" on public.shoots;
drop policy if exists "shoots_update_created_by" on public.shoots;
drop policy if exists "shoots_delete_admin_team_lead" on public.shoots;
drop policy if exists "shoots_insert_managers" on public.shoots;
drop policy if exists "shoots_update_managers" on public.shoots;
drop policy if exists "shoots_delete_managers" on public.shoots;

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

-- Realtime để Calendar/Dashboard tự refetch khi phân công thay đổi.
do $$
begin
  alter publication supabase_realtime add table public.shoot_editors;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;

commit;
