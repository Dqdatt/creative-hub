-- ============================================================
-- CreativeHub - KPI tổng của team order BRAND
-- Mỗi tháng một dòng chỉ tiêu, admin nhập tay trên dashboard. Tháng nào chưa
-- nhập thì không có dòng, dashboard chỉ hiện số đếm được.
--
-- Chạy lại nhiều lần đều an toàn.
--
-- Run after:
-- - supabase/setup.sql
-- ============================================================

begin;

create table if not exists public.brand_kpi_targets (
  -- Dạng 'YYYY-MM', trùng đúng giá trị tháng mà giao diện đang dùng.
  month_value text primary key,
  long_videos_target integer not null default 0,
  motion_target integer not null default 0,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  updated_by uuid references public.profiles(id) on delete set null
);

alter table public.brand_kpi_targets
  drop constraint if exists brand_kpi_targets_month_value_check;
alter table public.brand_kpi_targets
  add constraint brand_kpi_targets_month_value_check
  check (month_value ~ '^\d{4}-(0[1-9]|1[0-2])$');

alter table public.brand_kpi_targets
  drop constraint if exists brand_kpi_targets_non_negative_check;
alter table public.brand_kpi_targets
  add constraint brand_kpi_targets_non_negative_check
  check (long_videos_target >= 0 and motion_target >= 0);

drop trigger if exists brand_kpi_targets_set_updated_at on public.brand_kpi_targets;
create trigger brand_kpi_targets_set_updated_at
before update on public.brand_kpi_targets
for each row execute function public.set_updated_at();

alter table public.brand_kpi_targets enable row level security;

-- Ai đăng nhập cũng đọc được; chỉ admin mới sửa được chỉ tiêu.
drop policy if exists "brand_kpi_targets_select_authenticated" on public.brand_kpi_targets;
create policy "brand_kpi_targets_select_authenticated"
on public.brand_kpi_targets
for select
to authenticated
using (true);

drop policy if exists "brand_kpi_targets_insert_admin" on public.brand_kpi_targets;
create policy "brand_kpi_targets_insert_admin"
on public.brand_kpi_targets
for insert
to authenticated
with check (public.current_profile_role() = 'admin');

drop policy if exists "brand_kpi_targets_update_admin" on public.brand_kpi_targets;
create policy "brand_kpi_targets_update_admin"
on public.brand_kpi_targets
for update
to authenticated
using (public.current_profile_role() = 'admin')
with check (public.current_profile_role() = 'admin');

drop policy if exists "brand_kpi_targets_delete_admin" on public.brand_kpi_targets;
create policy "brand_kpi_targets_delete_admin"
on public.brand_kpi_targets
for delete
to authenticated
using (public.current_profile_role() = 'admin');

comment on table public.brand_kpi_targets is
  'Chỉ tiêu KPI tổng của team order BRAND theo từng tháng, admin nhập tay.';

commit;
