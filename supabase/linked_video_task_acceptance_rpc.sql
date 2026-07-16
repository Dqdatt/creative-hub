-- ============================================================
-- CreativeHub - Linked Video Task acceptance
-- Run after:
-- - supabase/content_plan_task_assignment_rpc.sql
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

drop trigger if exists video_tasks_content_plan_id_immutable_guard on public.video_tasks;
create trigger video_tasks_content_plan_id_immutable_guard
before update on public.video_tasks
for each row execute function public.prevent_video_task_content_plan_relink();

create or replace function public.accept_linked_video_task(
  p_video_task_id uuid,
  p_receive_date date,
  p_return_date date
)
returns table (
  video_task_id uuid,
  content_plan_id uuid,
  status text,
  receive_date date,
  return_date date,
  air_date date,
  editor_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_task public.video_tasks%rowtype;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để nhận Task.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_actor_id
      and coalesce(p.active, true) = true
      and p.is_editor_member = true
      and nullif(trim(coalesce(p.editor_code, '')), '') is not null
  ) then
    raise exception 'Tài khoản Editor hiện không đủ điều kiện nhận Task.';
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
    raise exception 'Task thủ công không sử dụng thao tác Nhận Task.';
  end if;

  if v_task.editor_id is null or v_task.editor_id <> v_actor_id then
    raise exception 'Bạn không phải Editor được giao Task này.';
  end if;

  if v_task.status <> 'Chờ' then
    raise exception 'Task này đã được nhận hoặc trạng thái đã thay đổi.';
  end if;

  if p_receive_date is null
    or p_return_date is null
    or p_return_date < p_receive_date then
    raise exception 'Ngày nhận và Ngày trả chưa hợp lệ.';
  end if;

  perform set_config('app.linked_video_task_acceptance', 'on', true);

  update public.video_tasks
  set status = 'Đang làm',
      receive_date = p_receive_date,
      return_date = p_return_date,
      updated_by = v_actor_id
  where id = p_video_task_id
  returning
    id,
    public.video_tasks.content_plan_id,
    public.video_tasks.status,
    public.video_tasks.receive_date,
    public.video_tasks.return_date,
    public.video_tasks.air_date,
    public.video_tasks.editor_id
  into
    video_task_id,
    content_plan_id,
    status,
    receive_date,
    return_date,
    air_date,
    editor_id;

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
    'video_task_accepted',
    v_task.title,
    'Editor đã nhận Video Task liên kết.',
    jsonb_build_object(
      'video_task_id', p_video_task_id,
      'content_plan_id', v_task.content_plan_id,
      'editor_id', v_actor_id,
      'receive_date', p_receive_date,
      'return_date', p_return_date,
      'previous_status', 'Chờ',
      'new_status', 'Đang làm',
      'actor_id', v_actor_id,
      'created_at', timezone('utc'::text, now())
    )
  );

  return next;
end;
$$;

revoke all on function public.accept_linked_video_task(uuid, date, date) from public;
revoke all on function public.accept_linked_video_task(uuid, date, date) from anon;
grant execute on function public.accept_linked_video_task(uuid, date, date) to authenticated;

comment on function public.accept_linked_video_task(uuid, date, date) is
  'Assigned editor accepts a linked Video Task and sets execution dates atomically.';

commit;

select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'accept_linked_video_task';
