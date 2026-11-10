-- ============================================================
-- CreativeHub v2.0.0 - Chuyển video task tạo tay (luồng cũ) thành Task
-- Run after supabase/v2_task_order_team.sql
--
-- Sau khi lên v2.0.0, nút "Thêm task" ở Workload của admin vẫn tạo video_tasks
-- độc lập (không có content_plan), nên các task này không hiện trong trang Task.
-- Script tạo dòng Task (content_plan) tương ứng cho từng video task đó và gắn liên kết,
-- áp luật mới: có Editor = Đang làm, có link thành phẩm = Đã xong.
--
-- Phạm vi: video task không gắn Task, tạo từ ngày phát hành v2 (09/11/2026, giờ VN).
-- Đổi v_since nếu muốn lấy rộng hơn. Chạy phần XEM TRƯỚC để kiểm tra trước khi chạy.
-- ============================================================

-- XEM TRƯỚC (chạy riêng, không đổi dữ liệu):
-- select id, title, editor_id, status, air_date, result_link, created_at
-- from public.video_tasks
-- where content_plan_id is null
--   and created_at >= timestamptz '2026-11-09 00:00:00+07'
-- order by created_at;

begin;

alter table public.video_tasks disable trigger video_tasks_content_plan_id_immutable_guard;

do $$
declare
  v_since constant timestamptz := timestamptz '2026-11-09 00:00:00+07';
  v_today constant date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_task record;
  v_plan_id uuid;
  v_link text;
  v_count integer := 0;
begin
  for v_task in
    select *
    from public.video_tasks
    where content_plan_id is null
      and created_at >= v_since
    order by created_at
  loop
    v_link := nullif(trim(coalesce(v_task.result_link, '')), '');

    insert into public.content_plan (
      air_date, title, note, category, order_team, editor_id, link,
      created_by, updated_by, created_at
    )
    values (
      coalesce(v_task.air_date, v_task.return_date, v_today),
      v_task.title,
      coalesce(v_task.notes, ''),
      case when v_task.category in ('Video dài', 'Motion') then v_task.category else 'Video dài' end,
      case when v_task.order_team in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR')
        then v_task.order_team else 'BRAND' end,
      v_task.editor_id,
      v_link,
      v_task.created_by,
      v_task.updated_by,
      v_task.created_at
    )
    returning id into v_plan_id;

    update public.video_tasks
    set content_plan_id = v_plan_id,
        air_date = coalesce(air_date, return_date, v_today),
        status = case
          when v_link is not null then 'Đã xong'
          when editor_id is not null and status = 'Chờ' then 'Đang làm'
          else status
        end,
        receive_date = case
          when editor_id is not null and status = 'Chờ'
            then coalesce(receive_date, least(v_today, coalesce(return_date, air_date, v_today)))
          else receive_date
        end
    where id = v_task.id;

    v_count := v_count + 1;
  end loop;

  raise notice 'Đã chuyển % video task thành Task.', v_count;
end;
$$;

alter table public.video_tasks enable trigger video_tasks_content_plan_id_immutable_guard;

commit;
