-- ============================================================
-- CreativeHub - Video Task completion timestamp & deadline
-- Thêm video_tasks.completed_at: mốc task chuyển sang "Đã xong" (kèm link
-- thành phẩm). Trigger đóng dấu mốc này cho TOÀN BỘ task - task thủ công,
-- task liên kết Content Plan lẫn thao tác override của admin - để dashboard
-- admin so mốc hoàn thành với Ngày Air và tính trễ deadline.
--
-- Chạy lại nhiều lần đều an toàn: thêm cột có if not exists, backfill chỉ
-- đụng dòng đang trống, trigger và index đều drop/replace trước khi tạo.
--
-- Run after:
-- - supabase/linked_task_field_lock_patch.sql
-- - supabase/remove_pending_ads_add_paused_video_tasks_patch.sql
-- ============================================================

begin;

-- Bỏ qua các guard của task liên kết: backfill chỉ đụng tới completed_at.
select set_config('app.content_plan_assignment', 'on', true);
select set_config('app.linked_video_task_acceptance', 'on', true);
select set_config('app.linked_video_task_execution_update', 'on', true);
select set_config('app.linked_video_task_completion', 'on', true);

alter table public.video_tasks
  add column if not exists completed_at timestamptz;

comment on column public.video_tasks.completed_at is
  'Mốc task chuyển sang "Đã xong". Do trigger quản lý, ứng dụng không ghi trực tiếp.';

-- ------------------------------------------------------------
-- Backfill từ activity_logs.
-- Gỡ trigger trước: nếu nó đang tồn tại (lần chạy thứ hai trở đi) thì với dòng
-- vốn đã "Đã xong" nó sẽ giữ lại completed_at cũ, tức ghi đè null lên đúng giá
-- trị vừa backfill và biến cả bước này thành vô tác dụng.
-- Lấy lần đầu tiên task được ghi nhận hoàn thành, kể cả khi sau đó bị sửa lại.
-- ------------------------------------------------------------
drop trigger if exists video_tasks_zz_completed_at_stamp on public.video_tasks;

with completion_events as (
  select
    l.entity_id as task_id,
    min(l.created_at) as completed_at
  from public.activity_logs l
  where l.entity_type = 'video_task'
    and l.entity_id is not null
    and (
      l.action = 'video_task_completed'
      or l.metadata->>'new_status' = 'Đã xong'
      or l.metadata->>'status' = 'Đã xong'
    )
  group by l.entity_id
)
update public.video_tasks t
set completed_at = e.completed_at
from completion_events e
where t.id = e.task_id
  and t.status = 'Đã xong'
  and t.completed_at is null;

-- Task đã xong nhưng không có log tương ứng (dữ liệu trước khi có activity log)
-- giữ completed_at = null và được dashboard xếp vào nhóm "chưa rõ mốc hoàn thành",
-- thay vì đoán một mốc sai làm lệch số liệu trễ deadline.

-- ------------------------------------------------------------
-- Trigger đóng dấu mốc hoàn thành
-- ------------------------------------------------------------
create or replace function public.stamp_video_task_completed_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'Đã xong' then
      new.completed_at := coalesce(new.completed_at, timezone('utc'::text, now()));
    else
      new.completed_at := null;
    end if;

    return new;
  end if;

  if new.status = 'Đã xong' then
    if old.status is distinct from 'Đã xong' then
      new.completed_at := timezone('utc'::text, now());
    else
      -- Giữ nguyên mốc hoàn thành đầu tiên: sửa link hay ghi chú sau đó
      -- không được đẩy deadline sang ngày khác.
      new.completed_at := old.completed_at;
    end if;
  else
    new.completed_at := null;
  end if;

  return new;
end;
$$;

-- Tên có tiền tố zz để chạy sau các trigger chuẩn hoá nhãn trạng thái
-- (trigger BEFORE trên cùng bảng chạy theo thứ tự alphabet).
create trigger video_tasks_zz_completed_at_stamp
before insert or update on public.video_tasks
for each row execute function public.stamp_video_task_completed_at();

create index if not exists video_tasks_completed_at_idx
  on public.video_tasks (completed_at);

commit;
