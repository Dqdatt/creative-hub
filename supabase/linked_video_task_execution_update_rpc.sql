-- ============================================================
-- CreativeHub - Linked Video Task execution update
-- Run after:
-- - supabase/linked_video_task_completion_rpc.sql
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

create or replace function public.is_linked_video_task_execution_update_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_execution_update', true) = 'on', false);
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
  perform set_config('app.linked_video_task_execution_update', 'on', true);

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

create or replace function public.update_linked_video_task_execution(
  p_video_task_id uuid,
  p_order_team text,
  p_priority text,
  p_resize_reqs text,
  p_receive_date date,
  p_return_date date,
  p_result_link text
)
returns table (
  video_task_id uuid,
  content_plan_id uuid,
  status text,
  order_team text,
  priority text,
  resize_reqs text,
  receive_date date,
  return_date date,
  result_link text,
  editor_id uuid,
  changed_fields text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_task public.video_tasks%rowtype;
  v_order_team text := nullif(btrim(coalesce(p_order_team, '')), '');
  v_priority text := coalesce(p_priority, '');
  v_resize_reqs text := nullif(btrim(coalesce(p_resize_reqs, '')), '');
  v_result_link text := nullif(btrim(coalesce(p_result_link, '')), '');
  v_changed_fields text[] := array[]::text[];
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để lưu thông tin thực hiện Task.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_actor_id
      and coalesce(p.active, true) = true
      and p.is_editor_member = true
      and nullif(trim(coalesce(p.editor_code, '')), '') is not null
  ) then
    raise exception 'Tài khoản Editor hiện không đủ điều kiện cập nhật Task.';
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
    raise exception 'Task thủ công không sử dụng luồng cập nhật từ Content Plan.';
  end if;

  if v_task.editor_id is null or v_task.editor_id <> v_actor_id then
    raise exception 'Bạn không phải Editor được giao Task này.';
  end if;

  if v_task.status <> 'Đang làm' then
    raise exception 'Task này chưa ở trạng thái có thể cập nhật.';
  end if;

  if v_order_team is not null
    and v_order_team not in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR') then
    raise exception 'Team Order chưa hợp lệ.';
  end if;

  if v_priority not in ('', 'Gấp') then
    raise exception 'Độ ưu tiên chưa hợp lệ.';
  end if;

  if p_receive_date is null
    or p_return_date is null
    or p_return_date < p_receive_date then
    raise exception 'Ngày nhận và Ngày trả chưa hợp lệ.';
  end if;

  if v_result_link is not null
    and v_result_link !~* '^https?://[^[:space:]/?#]+[^[:space:]<>"'']*$' then
    raise exception 'Link thành phẩm chưa hợp lệ.';
  end if;

  if v_order_team is distinct from v_task.order_team then
    v_changed_fields := array_append(v_changed_fields, 'order_team');
  end if;
  if v_priority is distinct from v_task.priority then
    v_changed_fields := array_append(v_changed_fields, 'priority');
  end if;
  if v_resize_reqs is distinct from v_task.resize_reqs then
    v_changed_fields := array_append(v_changed_fields, 'resize_reqs');
  end if;
  if p_receive_date is distinct from v_task.receive_date then
    v_changed_fields := array_append(v_changed_fields, 'receive_date');
  end if;
  if p_return_date is distinct from v_task.return_date then
    v_changed_fields := array_append(v_changed_fields, 'return_date');
  end if;
  if v_result_link is distinct from v_task.result_link then
    v_changed_fields := array_append(v_changed_fields, 'result_link');
  end if;

  if cardinality(v_changed_fields) > 0 then
    perform set_config('app.linked_video_task_execution_update', 'on', true);

    update public.video_tasks
    set order_team = v_order_team,
        priority = v_priority,
        resize_reqs = v_resize_reqs,
        receive_date = p_receive_date,
        return_date = p_return_date,
        result_link = v_result_link,
        updated_by = v_actor_id
    where id = p_video_task_id;

    insert into public.activity_logs (
      actor_id,
      entity_type,
      entity_id,
      action,
      title,
      description,
      metadata
    )
    values (
      v_actor_id,
      'video_task',
      p_video_task_id,
      'video_task_execution_updated',
      v_task.title,
      'Editor đã cập nhật thông tin thực hiện Video Task liên kết.',
      jsonb_build_object(
        'video_task_id', p_video_task_id,
        'content_plan_id', v_task.content_plan_id,
        'editor_id', v_actor_id,
        'changed_fields', v_changed_fields,
        'has_result_link', v_result_link is not null,
        'actor_id', v_actor_id,
        'created_at', timezone('utc'::text, now())
      )
    );
  end if;

  video_task_id := p_video_task_id;
  content_plan_id := v_task.content_plan_id;
  status := v_task.status;
  order_team := v_order_team;
  priority := v_priority;
  resize_reqs := v_resize_reqs;
  receive_date := p_receive_date;
  return_date := p_return_date;
  result_link := v_result_link;
  editor_id := v_actor_id;
  changed_fields := v_changed_fields;
  return next;
end;
$$;

revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from public;
revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from anon;
grant execute on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) to authenticated;

comment on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) is
  'Assigned editor updates execution-owned fields for a linked Video Task without completing it or syncing Content Plan link.';

commit;

select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_linked_video_task_execution';
