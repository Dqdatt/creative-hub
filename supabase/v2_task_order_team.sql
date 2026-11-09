-- ============================================================
-- CreativeHub v2.0.0 - Phòng ban order cho Task (content_plan)
-- Run after supabase/v2_open_task_board.sql
-- ============================================================

begin;

alter table public.content_plan
  add column if not exists order_team text not null default 'BRAND';

alter table public.content_plan drop constraint if exists content_plan_order_team_check;
alter table public.content_plan
  add constraint content_plan_order_team_check
  check (order_team in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR'));

-- Lấy phòng ban từ Task liên kết đã có.
update public.content_plan cp
set order_team = vt.order_team
from public.video_tasks vt
where vt.content_plan_id = cp.id
  and vt.order_team in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR')
  and cp.order_team is distinct from vt.order_team;

-- Task sinh ra khi chọn Editor: bắt đầu ngay + lấy phòng ban từ content_plan.
create or replace function public.v2_autostart_linked_video_task()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.content_plan_id is not null then
    select cp.order_team into new.order_team
    from public.content_plan cp
    where cp.id = new.content_plan_id;
  end if;

  if new.content_plan_id is not null and new.status = 'Chờ' then
    new.status := 'Đang làm';
    -- Ngày nhận không được sau hạn trả (video_tasks_date_order_check).
    new.receive_date := coalesce(new.receive_date, least((now() at time zone 'Asia/Ho_Chi_Minh')::date, coalesce(new.return_date, new.air_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date)));
    new.return_date := greatest(coalesce(new.return_date, new.air_date, new.receive_date), new.receive_date);
  end if;
  return new;
end;
$$;

-- Đổi phòng ban ở Task -> đồng bộ sang video_tasks.
create or replace function public.v2_sync_task_order_team_to_video_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.video_tasks
  set order_team = new.order_team
  where content_plan_id = new.id
    and order_team is distinct from new.order_team;
  return new;
end;
$$;

drop trigger if exists v2_sync_task_order_team_to_video_task on public.content_plan;
create trigger v2_sync_task_order_team_to_video_task
after update of order_team on public.content_plan
for each row
when (old.order_team is distinct from new.order_team)
execute function public.v2_sync_task_order_team_to_video_task();

commit;
