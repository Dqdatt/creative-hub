-- ============================================================
-- CreativeHub - Admin linked Video Task override
-- Allows admin to edit linked/done Video tháng task rows directly.
-- Creative Manager and Editor workflows remain guarded by the existing trigger.
-- ============================================================

begin;

create or replace function public.prevent_video_task_content_plan_relink()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.content_plan_id is distinct from old.content_plan_id then
    raise exception 'Không được đổi liên kết Content Plan của Video Task.';
  end if;

  if public.is_admin() then
    return new;
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.title is distinct from old.title
      or new.category is distinct from old.category
      or new.air_date is distinct from old.air_date
    )
    and not public.is_content_plan_assignment_context() then
    raise exception 'Thông tin kế hoạch của Task liên kết được quản lý từ Content Plan.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.order_team is distinct from old.order_team
      or new.priority is distinct from old.priority
      or new.resize_reqs is distinct from old.resize_reqs
    )
    and not public.is_linked_video_task_execution_update_context() then
    raise exception 'Hãy cập nhật thông tin thực hiện Task liên kết qua thao tác Lưu thay đổi.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and new.editor_id is distinct from old.editor_id
    and not public.is_content_plan_assignment_context() then
    raise exception 'Hãy đổi Editor của Task liên kết từ Content Plan.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status = 'Chờ'
    and (
      new.status is distinct from old.status
      or new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not public.is_linked_video_task_acceptance_context() then
    raise exception 'Hãy nhận Task liên kết qua thao tác Nhận Task.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status in ('Đang làm', 'Đã xong')
    and new.status is distinct from old.status
    and not public.is_linked_video_task_completion_context() then
    raise exception 'Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status in ('Đang làm', 'Đã xong')
    and (
      new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not (
      public.is_linked_video_task_execution_update_context()
      or public.is_linked_video_task_completion_context()
    ) then
    raise exception 'Hãy cập nhật thông tin thực hiện Task liên kết qua thao tác Lưu thay đổi.';
  end if;

  return new;
end;
$$;

drop trigger if exists video_tasks_content_plan_id_immutable_guard on public.video_tasks;
create trigger video_tasks_content_plan_id_immutable_guard
before update on public.video_tasks
for each row execute function public.prevent_video_task_content_plan_relink();

comment on function public.prevent_video_task_content_plan_relink() is
  'Guards linked Video Task fields for non-admin workflow users; admin can override linked/done task rows.';

commit;
