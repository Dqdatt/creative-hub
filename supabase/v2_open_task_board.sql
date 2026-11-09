-- ============================================================
-- CreativeHub v2.0.0 - Task board mở (Content Plan = danh sách Task)
-- Run after all previous patches.
--
-- Luật mới:
-- 1. Không phân quyền: mọi tài khoản đăng nhập đều tạo / sửa / xóa Task
--    và chọn Editor cho Task.
-- 2. Task chưa có Editor = chưa có người nhận. Chọn Editor = nhận Task,
--    Task bắt đầu ngay ở "Đang làm" (bỏ bước Nhận Task / Chờ).
-- 3. Task được tính "Đã xong" khi có link thành phẩm (nhập link ở Task).
-- 4. Bỏ toàn bộ guard workflow cũ (giao việc / nhận / hoàn thành).
-- ============================================================

begin;

create or replace function public.can_edit_content_plan_content()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null;
$$;

create or replace function public.can_assign_content_plan_editor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null;
$$;

create or replace function public.v2_autostart_linked_video_task()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.content_plan_id is not null and new.status = 'Chờ' then
    new.status := 'Đang làm';
    -- Ngày nhận không được sau hạn trả (video_tasks_date_order_check).
    new.receive_date := coalesce(new.receive_date, least((now() at time zone 'Asia/Ho_Chi_Minh')::date, coalesce(new.return_date, new.air_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date)));
    new.return_date := greatest(coalesce(new.return_date, new.air_date, new.receive_date), new.receive_date);
  end if;
  return new;
end;
$$;

drop trigger if exists v2_autostart_linked_video_task on public.video_tasks;
create trigger v2_autostart_linked_video_task
before insert on public.video_tasks
for each row execute function public.v2_autostart_linked_video_task();

-- Bỏ guard workflow cũ trên content_plan.
create or replace function public.enforce_content_plan_field_permissions()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  return new;
end;
$$;

-- Bỏ guard workflow cũ trên video_tasks, chỉ giữ ràng buộc không đổi liên kết.
create or replace function public.prevent_video_task_content_plan_relink()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.content_plan_id is distinct from old.content_plan_id then
    raise exception 'Không được đổi liên kết Content Plan của Video Task.';
  end if;
  return new;
end;
$$;

-- Link thành phẩm ở Task -> đồng bộ sang video_tasks, có link = Đã xong.
create or replace function public.v2_sync_task_link_to_video_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link text := nullif(trim(coalesce(new.link, '')), '');
begin
  update public.video_tasks vt
  set result_link = v_link,
      status = case
        when v_link is not null then 'Đã xong'
        when vt.status = 'Đã xong' then 'Đang làm'
        else vt.status
      end
  where vt.content_plan_id = new.id
    and (vt.result_link is distinct from v_link
      or (v_link is not null and vt.status <> 'Đã xong')
      or (v_link is null and vt.status = 'Đã xong'));
  return new;
end;
$$;

drop trigger if exists v2_sync_task_link_to_video_task on public.content_plan;
create trigger v2_sync_task_link_to_video_task
after update of link on public.content_plan
for each row
when (old.link is distinct from new.link)
execute function public.v2_sync_task_link_to_video_task();

-- Chuyển các Task liên kết đang chờ nhận sang Đang làm.
select set_config('app.linked_video_task_acceptance', 'on', true);

update public.video_tasks
set status = 'Đang làm',
    receive_date = coalesce(receive_date, least((now() at time zone 'Asia/Ho_Chi_Minh')::date, coalesce(return_date, air_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date))),
    return_date = greatest(
      coalesce(return_date, air_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date),
      coalesce(receive_date, least((now() at time zone 'Asia/Ho_Chi_Minh')::date, coalesce(return_date, air_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date)))
    )
where content_plan_id is not null
  and status = 'Chờ';

commit;
