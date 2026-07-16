-- ============================================================
-- CreativeHub - Linked Video Task completion
-- Run after:
-- - supabase/linked_video_task_acceptance_rpc.sql
-- ============================================================

begin;

alter table public.activity_logs drop constraint if exists activity_logs_action_check;
alter table public.activity_logs
  add constraint activity_logs_action_check
  check (action in (
    'created',
    'updated',
    'deleted',
    'status_changed',
    'assigned',
    'uploaded',
    'password_changed',
    'content_plan_assigned',
    'content_plan_reassigned',
    'video_task_generated',
    'video_task_editor_changed',
    'video_task_accepted',
    'video_task_execution_updated',
    'video_task_completed',
    'content_plan_completed'
  ));

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

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.title is distinct from old.title
      or new.order_team is distinct from old.order_team
      or new.category is distinct from old.category
      or new.priority is distinct from old.priority
      or new.resize_reqs is distinct from old.resize_reqs
      or new.air_date is distinct from old.air_date
    )
    and not public.is_content_plan_assignment_context() then
    raise exception 'Thông tin kế hoạch của Task liên kết được quản lý từ Content Plan.';
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
    and (
      new.status is distinct from old.status
      or new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not public.is_linked_video_task_completion_context() then
    raise exception 'Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.';
  end if;

  return new;
end;
$$;

drop trigger if exists content_plan_field_permission_guard on public.content_plan;
create trigger content_plan_field_permission_guard
before insert or update on public.content_plan
for each row execute function public.enforce_content_plan_field_permissions();

drop trigger if exists video_tasks_content_plan_id_immutable_guard on public.video_tasks;
create trigger video_tasks_content_plan_id_immutable_guard
before update on public.video_tasks
for each row execute function public.prevent_video_task_content_plan_relink();

create or replace function public.complete_linked_video_task(
  p_video_task_id uuid,
  p_result_link text
)
returns table (
  video_task_id uuid,
  content_plan_id uuid,
  status text,
  result_link text,
  content_plan_link text,
  completed_at timestamptz,
  editor_id uuid,
  air_date date
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_task public.video_tasks%rowtype;
  v_plan public.content_plan%rowtype;
  v_normalized_link text;
  v_completed_at timestamptz := timezone('utc'::text, now());
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để hoàn thành Task.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_actor_id
      and coalesce(p.active, true) = true
      and p.is_editor_member = true
      and nullif(trim(coalesce(p.editor_code, '')), '') is not null
  ) then
    raise exception 'Tài khoản Editor hiện không đủ điều kiện hoàn thành Task.';
  end if;

  select *
  into v_task
  from public.video_tasks
  where id = p_video_task_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Task.';
  end if;

  if v_task.content_plan_id is null then
    raise exception 'Task thủ công không sử dụng luồng hoàn thành từ Content Plan.';
  end if;

  if v_task.editor_id is null or v_task.editor_id <> v_actor_id then
    raise exception 'Bạn không phải Editor được giao Task này.';
  end if;

  if v_task.status = 'Đã xong' then
    raise exception 'Task này đã hoàn thành hoặc trạng thái đã thay đổi.';
  end if;

  if v_task.status <> 'Đang làm' then
    raise exception 'Task này chưa ở trạng thái có thể hoàn thành.';
  end if;

  v_normalized_link := btrim(coalesce(p_result_link, ''));

  if v_normalized_link = ''
    or v_normalized_link !~* '^https?://[^[:space:]/?#]+[^[:space:]<>"'']*$' then
    raise exception 'Link thành phẩm chưa hợp lệ.';
  end if;

  select *
  into v_plan
  from public.content_plan
  where id = v_task.content_plan_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Content Plan liên kết.';
  end if;

  perform set_config('app.linked_video_task_completion', 'on', true);

  update public.video_tasks
  set status = 'Đã xong',
      result_link = v_normalized_link,
      updated_by = v_actor_id
  where id = p_video_task_id;

  update public.content_plan
  set link = v_normalized_link,
      updated_by = v_actor_id
  where id = v_task.content_plan_id;

  insert into public.activity_logs (
    actor_id,
    entity_type,
    entity_id,
    action,
    title,
    description,
    metadata
  )
  values
    (
      v_actor_id,
      'video_task',
      p_video_task_id,
      'video_task_completed',
      v_task.title,
      'Editor đã hoàn thành Video Task liên kết.',
      jsonb_build_object(
        'video_task_id', p_video_task_id,
        'content_plan_id', v_task.content_plan_id,
        'editor_id', v_actor_id,
        'previous_status', 'Đang làm',
        'new_status', 'Đã xong',
        'has_result_link', true,
        'actor_id', v_actor_id,
        'created_at', v_completed_at
      )
    ),
    (
      v_actor_id,
      'content_plan',
      v_task.content_plan_id,
      'content_plan_completed',
      v_plan.title,
      'Content Plan đã nhận link hoàn thành từ Video tháng.',
      jsonb_build_object(
        'video_task_id', p_video_task_id,
        'content_plan_id', v_task.content_plan_id,
        'editor_id', v_actor_id,
        'previous_status', 'Đang làm',
        'new_status', 'Đã xong',
        'has_result_link', true,
        'actor_id', v_actor_id,
        'created_at', v_completed_at
      )
    );

  video_task_id := p_video_task_id;
  content_plan_id := v_task.content_plan_id;
  status := 'Đã xong';
  result_link := v_normalized_link;
  content_plan_link := v_normalized_link;
  completed_at := v_completed_at;
  editor_id := v_actor_id;
  air_date := v_task.air_date;
  return next;
end;
$$;

revoke all on function public.complete_linked_video_task(uuid, text) from public;
revoke all on function public.complete_linked_video_task(uuid, text) from anon;
grant execute on function public.complete_linked_video_task(uuid, text) to authenticated;

comment on function public.complete_linked_video_task(uuid, text) is
  'Assigned editor completes a linked Video Task and synchronizes the final link to Content Plan atomically.';

commit;

select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'complete_linked_video_task';
