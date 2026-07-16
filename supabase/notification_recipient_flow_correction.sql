-- ============================================================
-- CreativeHub - Notification recipient flow correction
-- Phase 5.6: Content Plan and linked Video Task recipient rules.
-- Safe to run after Phase 5.1-5.5 notification migrations.
-- ============================================================

begin;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'shoot_created',
    'shoot_updated',
    'shoot_cancelled',
    'shoot_member_added',
    'shoot_member_removed',
    'content_plan_created',
    'content_plan_assigned',
    'content_plan_reassigned',
    'content_plan_deleted',
    'video_task_created',
    'video_task_accepted',
    'video_task_execution_updated',
    'video_task_completed',
    'video_task_deleted'
  ));

create or replace function public.profile_has_effective_permission(
  p_profile_id uuid,
  p_permission_key text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_override public.user_permission_overrides%rowtype;
begin
  select p.role
  into v_role
  from public.profiles p
  where p.id = p_profile_id
    and coalesce(p.active, true) = true
    and coalesce(p.is_active, true) = true;

  if v_role is null then
    return false;
  end if;

  select *
  into v_override
  from public.user_permission_overrides
  where profile_id = p_profile_id
  limit 1;

  if p_permission_key = 'users_manage' and v_role <> 'admin' then
    return false;
  end if;

  if p_permission_key = 'users_manage' and v_role = 'admin' then
    return true;
  end if;

  if v_override.profile_id is null or v_override.access_mode = 'role_default' then
    return public.role_baseline_permission(v_role, p_permission_key);
  end if;

  if v_override.access_mode = 'view_only' then
    return public.role_baseline_permission(v_role, p_permission_key)
      and p_permission_key in (
        'dashboard_view',
        'calendar_view',
        'tasks_view',
        'content_plan_view'
      );
  end if;

  if v_override.access_mode = 'custom' then
    return case p_permission_key
      when 'dashboard_view' then coalesce(v_override.dashboard_view, false)
      when 'calendar_view' then coalesce(v_override.calendar_view, false) or coalesce(v_override.calendar_edit, false)
      when 'calendar_edit' then coalesce(v_override.calendar_edit, false)
      when 'tasks_view' then coalesce(v_override.tasks_view, false) or coalesce(v_override.tasks_edit, false)
      when 'tasks_edit' then coalesce(v_override.tasks_edit, false)
      when 'content_plan_view' then coalesce(v_override.content_plan_view, false)
        or coalesce(v_override.content_plan_edit_content, false)
        or coalesce(v_override.content_plan_assign_editor, false)
      when 'content_plan_edit_content' then coalesce(v_override.content_plan_edit_content, false)
      when 'content_plan_assign_editor' then coalesce(v_override.content_plan_assign_editor, false)
      when 'profile_edit_self' then coalesce(v_override.profile_edit_self, true)
      else false
    end;
  end if;

  return false;
end;
$$;

create or replace function public.content_plan_assignment_notification_recipients(p_actor_id uuid)
returns table (recipient_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.id is distinct from p_actor_id
    and coalesce(p.active, true) = true
    and coalesce(p.is_active, true) = true
    and p.role in ('admin', 'creative_manager')
    and public.profile_has_effective_permission(p.id, 'content_plan_assign_editor')
  order by p.created_at, p.id;
$$;

create or replace function public.create_content_plan_with_notifications(
  p_air_date date,
  p_title text,
  p_note text default null,
  p_category text default null,
  p_link text default null
)
returns table (
  content_plan_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_link text := nullif(btrim(coalesce(p_link, '')), '');
  v_content_plan_id uuid;
  v_notifications_created integer := 0;
  v_recipient_id uuid;
  v_event_at timestamptz := timezone('utc'::text, now());
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để tạo Content Plan.';
  end if;

  if not public.can_edit_content_plan_content() then
    raise exception 'Không có quyền tạo Content Plan.';
  end if;

  if p_air_date is null then
    raise exception 'Ngày Air chưa hợp lệ.';
  end if;

  if v_title = '' then
    raise exception 'Vui lòng nhập tên video.';
  end if;

  if p_category is not null and p_category not in ('Video dài', 'Short/Reels', 'Livestream', 'Ảnh', 'Motion', 'Ads') then
    raise exception 'Thể loại Content Plan chưa hợp lệ.';
  end if;

  if v_link is not null and v_link !~* '^https?://[^[:space:]/?#]+[^[:space:]<>"'']*$' then
    raise exception 'Link Content Plan chưa hợp lệ.';
  end if;

  insert into public.content_plan (
    air_date,
    title,
    note,
    category,
    link,
    editor_id,
    created_by,
    updated_by
  )
  values (
    p_air_date,
    v_title,
    v_note,
    p_category,
    v_link,
    null,
    v_actor_id,
    v_actor_id
  )
  returning id into v_content_plan_id;

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
    'content_plan',
    v_content_plan_id,
    'created',
    v_title,
    'Đã tạo kế hoạch content "' || v_title || '".',
    jsonb_build_object(
      'content_plan_id', v_content_plan_id,
      'air_date', p_air_date,
      'category', p_category,
      'note', v_note,
      'link', v_link,
      'actor_id', v_actor_id,
      'created_at', v_event_at
    )
  );

  for v_recipient_id in
    select r.recipient_id
    from public.content_plan_assignment_notification_recipients(v_actor_id) r
  loop
    perform public.create_internal_notification(
      v_recipient_id,
      v_actor_id,
      'content_plan_created',
      'Content Plan mới cần phân công',
      'Content Plan “' || v_title || '” đang chờ phân công Editor.',
      'content_plan',
      v_content_plan_id,
      '/content-plan?highlight=' || v_content_plan_id::text,
      jsonb_build_object(
        'content_plan_id', v_content_plan_id,
        'air_date', p_air_date,
        'category', p_category
      ),
      'content_plan_created:' || v_content_plan_id::text || ':' || v_recipient_id::text
    );
    v_notifications_created := v_notifications_created + 1;
  end loop;

  content_plan_id := v_content_plan_id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

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
  v_event_at timestamptz := timezone('utc'::text, now());
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
      'created_at', v_event_at
    )
  );

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
  v_event_at timestamptz := timezone('utc'::text, now());
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
        'created_at', v_event_at
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

  perform public.create_content_video_notification(
    v_plan.created_by,
    v_actor_id,
    'video_task_completed',
    'Video đã hoàn thành',
    'Task “' || v_task.title || '” đã hoàn thành và có Link thành phẩm.',
    'video_task',
    p_video_task_id,
    '/content-plan?highlight=' || v_task.content_plan_id::text,
    jsonb_build_object(
      'content_plan_id', v_task.content_plan_id,
      'video_task_id', p_video_task_id,
      'editor_id', v_actor_id,
      'result_link', v_normalized_link,
      'completed_at', v_completed_at
    ),
    'video_task_completed:' || p_video_task_id::text || ':' || coalesce(v_plan.created_by::text, 'none')
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

revoke execute on function public.profile_has_effective_permission(uuid, text) from public, anon, authenticated;
revoke execute on function public.content_plan_assignment_notification_recipients(uuid) from public, anon, authenticated;

revoke all on function public.create_content_plan_with_notifications(date, text, text, text, text) from public;
revoke all on function public.create_content_plan_with_notifications(date, text, text, text, text) from anon;
grant execute on function public.create_content_plan_with_notifications(date, text, text, text, text) to authenticated;

revoke all on function public.accept_linked_video_task(uuid, date, date) from public;
revoke all on function public.accept_linked_video_task(uuid, date, date) from anon;
grant execute on function public.accept_linked_video_task(uuid, date, date) to authenticated;

revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from public;
revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from anon;
grant execute on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) to authenticated;

revoke all on function public.complete_linked_video_task(uuid, text) from public;
revoke all on function public.complete_linked_video_task(uuid, text) from anon;
grant execute on function public.complete_linked_video_task(uuid, text) to authenticated;

comment on function public.profile_has_effective_permission(uuid, text) is
  'Evaluates the existing role/default/custom permission model for a specific active profile.';
comment on function public.content_plan_assignment_notification_recipients(uuid) is
  'Active Admin/Creative Manager recipients who currently retain Content Plan assignment permission, excluding actor.';
comment on function public.create_content_plan_with_notifications(date, text, text, text, text) is
  'Creates one Content Plan, logs creation, and notifies active Admin/Creative Manager assigners in the same transaction.';
comment on function public.accept_linked_video_task(uuid, date, date) is
  'Assigned editor accepts a linked Video Task and writes activity only; no creator notification.';
comment on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) is
  'Assigned editor updates execution-owned fields for a linked Video Task and writes activity only; no creator notification.';
comment on function public.complete_linked_video_task(uuid, text) is
  'Assigned editor completes a linked Video Task, syncs the final link to Content Plan, and notifies the Content Plan creator.';

commit;
