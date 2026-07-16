-- ============================================================
-- CreativeHub - Content Plan assignment to Video Task
-- Run after:
-- - supabase/content_plan_schema.sql
-- - supabase/user_permission_overrides_patch.sql
-- - supabase/content_plan_video_task_relation_patch.sql
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

create or replace function public.is_content_plan_assignment_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.content_plan_assignment', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_acceptance_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_acceptance', true) = 'on', false);
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

create or replace function public.assign_content_plan_editor(
  p_content_plan_id uuid,
  p_editor_id uuid
)
returns table (
  content_plan_id uuid,
  video_task_id uuid,
  editor_id uuid,
  task_created boolean,
  task_status text,
  air_date date
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_plan public.content_plan%rowtype;
  v_task public.video_tasks%rowtype;
  v_previous_editor_id uuid;
  v_video_task_id uuid;
  v_task_status text;
  v_task_created boolean := false;
  v_task_category text;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để phân công Content Plan.';
  end if;

  if not public.can_assign_content_plan_editor() then
    raise exception 'Bạn không có quyền giao việc từ Content Plan.';
  end if;

  select *
  into v_plan
  from public.content_plan
  where id = p_content_plan_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Content Plan.';
  end if;

  select *
  into v_task
  from public.video_tasks
  where video_tasks.content_plan_id = p_content_plan_id
  for update;

  v_previous_editor_id := v_plan.editor_id;

  if p_editor_id is null then
    if found then
      raise exception 'Content Plan đã sinh Task. Hãy xóa Content Plan hoặc dùng thao tác hủy giao việc trong phase sau.';
    end if;

    perform set_config('app.content_plan_assignment', 'on', true);

    update public.content_plan
    set editor_id = null,
        updated_by = v_actor_id
    where id = p_content_plan_id;

    content_plan_id := p_content_plan_id;
    video_task_id := null;
    editor_id := null;
    task_created := false;
    task_status := null;
    air_date := v_plan.air_date;
    return next;
    return;
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_editor_id
      and coalesce(p.active, true) = true
      and p.is_editor_member = true
      and nullif(trim(coalesce(p.editor_code, '')), '') is not null
  ) then
    raise exception 'Editor đã chọn không còn hoạt động hoặc không thuộc team editor.';
  end if;

  if v_plan.category is null or v_plan.category in ('Video dài', 'Motion', 'Ads') then
    v_task_category := v_plan.category;
  else
    raise exception 'Thể loại Content Plan chưa tương thích với Video tháng.';
  end if;

  perform set_config('app.content_plan_assignment', 'on', true);

  if v_task.id is null then
    update public.content_plan
    set editor_id = p_editor_id,
        updated_by = v_actor_id
    where id = p_content_plan_id;

    insert into public.video_tasks (
      content_plan_id,
      title,
      editor_id,
      status,
      category,
      priority,
      resize_reqs,
      order_team,
      receive_date,
      return_date,
      air_date,
      result_link,
      created_by,
      updated_by
    )
    values (
      p_content_plan_id,
      v_plan.title,
      p_editor_id,
      'Chờ',
      v_task_category,
      '',
      null,
      null,
      null,
      null,
      v_plan.air_date,
      null,
      v_actor_id,
      v_actor_id
    )
    returning id, status
    into v_video_task_id, v_task_status;

    v_task_created := true;

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
        'content_plan',
        p_content_plan_id,
        'content_plan_assigned',
        v_plan.title,
        'Đã phân công editor cho Content Plan.',
        jsonb_build_object(
          'content_plan_id', p_content_plan_id,
          'video_task_id', v_video_task_id,
          'previous_editor_id', v_previous_editor_id,
          'editor_id', p_editor_id,
          'actor_id', v_actor_id,
          'created_at', timezone('utc'::text, now())
        )
      ),
      (
        v_actor_id,
        'video_task',
        v_video_task_id,
        'video_task_generated',
        v_plan.title,
        'Đã sinh Video Task từ Content Plan.',
        jsonb_build_object(
          'content_plan_id', p_content_plan_id,
          'video_task_id', v_video_task_id,
          'editor_id', p_editor_id,
          'actor_id', v_actor_id,
          'created_at', timezone('utc'::text, now())
        )
      );
  else
    if v_task.status <> 'Chờ' and v_task.editor_id is distinct from p_editor_id then
      raise exception 'Không thể đổi Editor vì Task đã được bắt đầu.';
    end if;

    update public.content_plan
    set editor_id = p_editor_id,
        updated_by = v_actor_id
    where id = p_content_plan_id;

    update public.video_tasks
    set editor_id = p_editor_id,
        updated_by = v_actor_id
    where id = v_task.id;

    v_video_task_id := v_task.id;
    v_task_status := v_task.status;

    if v_task.editor_id is distinct from p_editor_id then
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
          'content_plan',
          p_content_plan_id,
          'content_plan_reassigned',
          v_plan.title,
          'Đã đổi editor của Content Plan.',
          jsonb_build_object(
            'content_plan_id', p_content_plan_id,
            'video_task_id', v_video_task_id,
            'previous_editor_id', v_task.editor_id,
            'editor_id', p_editor_id,
            'actor_id', v_actor_id,
            'created_at', timezone('utc'::text, now())
          )
        ),
        (
          v_actor_id,
          'video_task',
          v_video_task_id,
          'video_task_editor_changed',
          v_plan.title,
          'Đã đổi editor của Video Task liên kết.',
          jsonb_build_object(
            'content_plan_id', p_content_plan_id,
            'video_task_id', v_video_task_id,
            'previous_editor_id', v_task.editor_id,
            'editor_id', p_editor_id,
            'actor_id', v_actor_id,
            'created_at', timezone('utc'::text, now())
          )
        );
    end if;
  end if;

  content_plan_id := p_content_plan_id;
  video_task_id := v_video_task_id;
  editor_id := p_editor_id;
  task_created := v_task_created;
  task_status := v_task_status;
  air_date := v_plan.air_date;
  return next;
end;
$$;

revoke all on function public.assign_content_plan_editor(uuid, uuid) from public;
revoke all on function public.assign_content_plan_editor(uuid, uuid) from anon;
grant execute on function public.assign_content_plan_editor(uuid, uuid) to authenticated;

comment on function public.assign_content_plan_editor(uuid, uuid) is
  'Atomically assigns/reassigns a Content Plan editor and creates or updates its linked Video Task.';

commit;

select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'assign_content_plan_editor';
