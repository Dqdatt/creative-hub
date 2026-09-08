-- ============================================================
-- CreativeHub - Task sinh từ Content Plan mặc định thuộc BRAND
-- Trigger đặt mặc định lúc insert nên không phụ thuộc phiên bản RPC phân công.
-- ============================================================

begin;

create or replace function public.set_linked_video_task_default_order_team()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.content_plan_id is not null
    and (new.order_team is null or btrim(new.order_team) = '') then
    new.order_team := 'BRAND';
  end if;

  return new;
end;
$$;

drop trigger if exists video_tasks_linked_default_order_team on public.video_tasks;
create trigger video_tasks_linked_default_order_team
before insert on public.video_tasks
for each row execute function public.set_linked_video_task_default_order_team();

-- Gán BRAND cho các task liên kết cũ đang bỏ trống phòng ban order.
-- Bỏ đoạn này nếu bạn muốn giữ nguyên dữ liệu cũ.
select set_config('app.linked_video_task_execution_update', 'on', true);

update public.video_tasks
set order_team = 'BRAND'
where content_plan_id is not null
  and (order_team is null or btrim(order_team) = '');

comment on function public.set_linked_video_task_default_order_team() is
  'Task sinh từ Content Plan mặc định order_team = BRAND khi chưa chỉ định.';

commit;
