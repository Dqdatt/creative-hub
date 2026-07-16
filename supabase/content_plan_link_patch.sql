-- ============================================================
-- CreativeHub - Content Plan link field
-- Safe to run in Supabase SQL Editor after content_plan_schema.sql.
-- If user_permission_overrides_patch.sql is installed, run this after it.
-- ============================================================

alter table public.content_plan
  add column if not exists link text;

comment on column public.content_plan.link is 'Link thành phẩm; có link hợp lệ thì dòng được xem là hoàn thành.';

create or replace function public.is_content_plan_assignment_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.content_plan_assignment', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_completion_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_completion', true) = 'on', false);
$$;

create or replace function public.enforce_content_plan_field_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_can_edit_content boolean;
  v_can_assign_editor boolean;
begin
  v_can_edit_content := public.can_edit_content_plan_content();
  v_can_assign_editor := public.can_assign_content_plan_editor();

  if tg_op = 'INSERT' then
    if not v_can_edit_content then
      raise exception 'Không có quyền tạo Content Plan.';
    end if;

    if new.editor_id is not null and not public.is_content_plan_assignment_context() then
      raise exception 'Hãy phân công Editor qua thao tác giao việc Content Plan.';
    end if;

    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.link is distinct from old.link
      and exists (
        select 1
        from public.video_tasks vt
        where vt.content_plan_id = old.id
      )
      and not public.is_linked_video_task_completion_context() then
      raise exception 'Link Content Plan liên kết được đồng bộ từ Video tháng.';
    end if;

    if not v_can_edit_content and (
      new.air_date is distinct from old.air_date
      or new.title is distinct from old.title
      or new.note is distinct from old.note
      or new.category is distinct from old.category
      or (
        new.link is distinct from old.link
        and not public.is_linked_video_task_completion_context()
      )
    ) then
      raise exception 'Không có quyền chỉnh nội dung Content Plan.';
    end if;

    if new.editor_id is distinct from old.editor_id then
      if not v_can_assign_editor then
        raise exception 'Không có quyền phân công editor Content Plan.';
      end if;

      if not public.is_content_plan_assignment_context() then
        raise exception 'Hãy phân công Editor qua thao tác giao việc Content Plan.';
      end if;
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists content_plan_field_permission_guard on public.content_plan;
create trigger content_plan_field_permission_guard
before insert or update on public.content_plan
for each row execute function public.enforce_content_plan_field_permissions();
