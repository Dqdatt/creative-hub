-- ============================================================
-- Video Ops - Content Plan schema
-- Phase 9C: schema + RLS only, chưa kết nối CRUD frontend
-- Safe to run in Supabase SQL Editor sau khi đã chạy setup.sql.
-- ============================================================

-- Content Plan là bảng lịch air theo tháng, không liên kết tự động với Video tháng.
-- Cột nghiệp vụ hiện tại:
-- - Ngày Air
-- - Tên video
-- - Thể loại
-- - Editor

create table if not exists public.content_plan (
  id uuid primary key default gen_random_uuid(),
  air_date date not null,
  title text not null,
  category text,
  editor_id uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.content_plan
  add column if not exists air_date date,
  add column if not exists title text,
  add column if not exists category text,
  add column if not exists editor_id uuid references public.profiles(id) on delete set null,
  add column if not exists created_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null,
  add column if not exists created_at timestamptz not null default timezone('utc'::text, now()),
  add column if not exists updated_at timestamptz not null default timezone('utc'::text, now());

update public.content_plan
set air_date = current_date
where air_date is null;

update public.content_plan
set title = 'Chưa đặt tên'
where title is null;

alter table public.content_plan
  alter column id set default gen_random_uuid(),
  alter column air_date set not null,
  alter column title set not null,
  alter column created_at set default timezone('utc'::text, now()),
  alter column updated_at set default timezone('utc'::text, now());

alter table public.content_plan drop constraint if exists content_plan_category_check;
alter table public.content_plan
  add constraint content_plan_category_check
  check (category is null or category in ('Video dài', 'Short/Reels', 'Livestream', 'Ảnh', 'Motion', 'Ads'));

create index if not exists content_plan_air_date_idx on public.content_plan (air_date);
create index if not exists content_plan_month_filter_idx on public.content_plan (air_date);
create index if not exists content_plan_editor_id_idx on public.content_plan (editor_id);
create index if not exists content_plan_category_idx on public.content_plan (category);
create index if not exists content_plan_created_by_idx on public.content_plan (created_by);

drop trigger if exists content_plan_set_audit_fields on public.content_plan;
create trigger content_plan_set_audit_fields
before insert or update on public.content_plan
for each row execute function public.set_audit_fields();

-- Quyền quản lý Content Plan.
-- team_lead chỉ để tương thích dữ liệu cũ trước khi chạy role_permissions_patch.sql.
create or replace function public.can_manage_content_plan()
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
-- RLS
-- ------------------------------------------------------------

alter table public.content_plan enable row level security;

drop policy if exists "content_plan_select_authenticated" on public.content_plan;
drop policy if exists "content_plan_insert_managers" on public.content_plan;
drop policy if exists "content_plan_update_managers" on public.content_plan;
drop policy if exists "content_plan_delete_managers" on public.content_plan;

-- Tất cả user đã đăng nhập được xem lịch air.
create policy "content_plan_select_authenticated"
on public.content_plan
for select
to authenticated
using (true);

-- Admin hiện tại được ghi dữ liệu. creative_manager/content_creator sẵn sàng cho role patch sau.
create policy "content_plan_insert_managers"
on public.content_plan
for insert
to authenticated
with check (
  public.can_manage_content_plan()
  and (created_by is null or created_by = auth.uid())
);

create policy "content_plan_update_managers"
on public.content_plan
for update
to authenticated
using (public.can_manage_content_plan())
with check (public.can_manage_content_plan());

create policy "content_plan_delete_managers"
on public.content_plan
for delete
to authenticated
using (public.can_manage_content_plan());

-- ------------------------------------------------------------
-- Grants
-- RLS vẫn là lớp quyết định ai được làm gì.
-- ------------------------------------------------------------

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.content_plan to authenticated;

-- ------------------------------------------------------------
-- Comments
-- ------------------------------------------------------------

comment on table public.content_plan is 'Lịch air nội dung theo tháng, độc lập với Video tháng.';
comment on column public.content_plan.air_date is 'Ngày Air hiển thị trong Content Plan.';
comment on column public.content_plan.title is 'Tên video trong lịch air.';
comment on column public.content_plan.category is 'Thể loại nội dung: Video dài, Short/Reels, Livestream, Ảnh, Motion, Ads.';
comment on column public.content_plan.editor_id is 'Editor được phân công, tham chiếu profiles.id nếu map được.';
comment on column public.content_plan.created_by is 'Người tạo dòng lịch air.';
comment on column public.content_plan.updated_by is 'Người cập nhật dòng lịch air gần nhất.';
