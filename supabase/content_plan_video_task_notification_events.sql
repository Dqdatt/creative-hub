-- ============================================================
-- CreativeHub - Content Plan and linked Video Task notifications
-- Phase 5.3: trusted notification producers only.
-- Safe to run after Phase 5.1 notification foundation and linked task RPCs.
-- ============================================================

begin;

create or replace function public.normalize_content_video_text(p_value text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(btrim(regexp_replace(coalesce(p_value, ''), '\s+', ' ', 'g')), '');
$$;

create or replace function public.format_content_video_date(p_date date)
returns text
language sql
stable
set search_path = public
as $$
  select case when p_date is null then '' else to_char(p_date, 'DD/MM/YYYY') end;
$$;

create or replace function public.content_video_change_summary(p_labels text[])
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_count integer;
begin
  v_count := cardinality(coalesce(p_labels, '{}'::text[]));

  if v_count = 0 then
    return '';
  end if;

  if v_count = 1 then
    return p_labels[1];
  end if;

  if v_count = 2 then
    return p_labels[1] || ' và ' || p_labels[2];
  end if;

  return array_to_string(p_labels[1:v_count - 1], ', ') || ' và ' || p_labels[v_count];
end;
$$;

create or replace function public.create_content_video_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_entity_type text,
  p_entity_id uuid,
  p_action_url text,
  p_metadata jsonb,
  p_event_key text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := p_type;
  v_title text := p_title;
  v_body text := p_body;
  v_action_url text := p_action_url;
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_content_plan_id text := nullif(v_metadata->>'content_plan_id', '');
  v_video_task_id text := nullif(v_metadata->>'video_task_id', '');
  v_title_from_body text := nullif(substring(p_body from '“([^”]+)”'), '');
begin
  if p_recipient_id is null then
    return 0;
  end if;

  if p_actor_id is not null and p_recipient_id = p_actor_id then
    return 0;
  end if;

  if p_type = 'video_task_created' then
    return 0;
  end if;

  if p_type = 'content_plan_assigned' then
    v_body := 'Task “' || coalesce(v_title_from_body, p_title) || '” đã được thêm vào Video tháng.';
    if v_video_task_id is not null then
      v_action_url := '/tasks?highlight=' || v_video_task_id;
    elsif p_entity_type = 'video_task' then
      v_action_url := '/tasks?highlight=' || p_entity_id::text;
    elsif v_content_plan_id is not null then
      v_action_url := '/content-plan?highlight=' || v_content_plan_id;
    end if;
  elsif p_type = 'content_plan_reassigned' and p_title = 'Bạn được giao Video mới' then
    v_type := 'content_plan_assigned';
    v_body := 'Task “' || coalesce(v_title_from_body, p_title) || '” đã được thêm vào Video tháng.';
    if v_video_task_id is not null then
      v_action_url := '/tasks?highlight=' || v_video_task_id;
    end if;
  elsif p_type = 'content_plan_reassigned' then
    v_body := 'Task “' || coalesce(v_title_from_body, p_title) || '” đã được chuyển cho Editor khác.';
    if v_content_plan_id is not null then
      v_action_url := '/content-plan?highlight=' || v_content_plan_id;
    end if;
  elsif p_type = 'video_task_accepted' then
    if v_content_plan_id is not null then
      v_action_url := '/content-plan?highlight=' || v_content_plan_id;
    end if;
  elsif p_type = 'video_task_execution_updated' then
    if v_video_task_id is not null then
      v_action_url := '/tasks?highlight=' || v_video_task_id;
    end if;
  elsif p_type = 'video_task_completed' then
    if v_content_plan_id is not null then
      v_action_url := '/content-plan?highlight=' || v_content_plan_id;
    end if;
  elsif p_type = 'content_plan_deleted' then
    v_action_url := '/content-plan';
  elsif p_type = 'video_task_deleted' then
    if v_content_plan_id is not null then
      v_action_url := '/content-plan?highlight=' || v_content_plan_id;
    else
      v_action_url := '/content-plan';
    end if;
  end if;

  perform public.create_internal_notification(
    p_recipient_id,
    p_actor_id,
    v_type,
    v_title,
    v_body,
    p_entity_type,
    p_entity_id,
    v_action_url,
    v_metadata,
    p_event_key
  );

  return 1;
end;
$$;

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
  v_event_at timestamptz := timezone('utc'::text, now());
  v_notifications_created integer := 0;
  v_assignment_kind text;
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
    v_assignment_kind := 'content_plan_assigned';

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
          'created_at', v_event_at
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
          'created_at', v_event_at
        )
      );

    v_notifications_created := v_notifications_created + public.create_content_video_notification(
      p_editor_id,
      v_actor_id,
      'content_plan_assigned',
      'Bạn được giao Video mới',
      'Bạn được giao video “' || v_plan.title || '” trong Content Plan.',
      'content_plan',
      p_content_plan_id,
      '/tasks?highlight=' || v_video_task_id::text,
      jsonb_build_object(
        'content_plan_id', p_content_plan_id,
        'video_task_id', v_video_task_id,
        'air_date', v_plan.air_date,
        'category', v_plan.category
      ),
      'content_plan_assigned:' || p_content_plan_id::text || ':' || p_editor_id::text
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
      v_assignment_kind := case when v_task.editor_id is null then 'content_plan_assigned' else 'content_plan_reassigned' end;

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
            'created_at', v_event_at
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
            'created_at', v_event_at
          )
        );

      if v_task.editor_id is not null then
        v_notifications_created := v_notifications_created + public.create_content_video_notification(
          v_task.editor_id,
          v_actor_id,
          'content_plan_reassigned',
          'Task đã được chuyển',
          'Task “' || v_plan.title || '” đã được chuyển sang editor khác.',
          'content_plan',
          p_content_plan_id,
          '/content-plan?highlight=' || p_content_plan_id::text,
          jsonb_build_object(
            'content_plan_id', p_content_plan_id,
            'video_task_id', v_video_task_id,
            'previous_editor_id', v_task.editor_id,
            'editor_id', p_editor_id,
            'changed_at', v_event_at
          ),
          'content_plan_reassigned:old:' || p_content_plan_id::text || ':' || v_task.editor_id::text || ':' || p_editor_id::text || ':' || extract(epoch from v_event_at)::text
        );
      end if;

      v_notifications_created := v_notifications_created + public.create_content_video_notification(
        p_editor_id,
        v_actor_id,
        v_assignment_kind,
        'Bạn được giao Video mới',
        'Bạn được giao video “' || v_plan.title || '” trong Content Plan.',
        'content_plan',
        p_content_plan_id,
        '/tasks?highlight=' || v_video_task_id::text,
        jsonb_build_object(
          'content_plan_id', p_content_plan_id,
          'video_task_id', v_video_task_id,
          'previous_editor_id', v_task.editor_id,
          'editor_id', p_editor_id,
          'changed_at', v_event_at
        ),
        v_assignment_kind || ':new:' || p_content_plan_id::text || ':' || p_editor_id::text || ':' || extract(epoch from v_event_at)::text
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

create or replace function public.delete_content_plan_with_notifications(p_content_plan_id uuid)
returns table (
  content_plan_id uuid,
  video_task_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_plan public.content_plan%rowtype;
  v_task public.video_tasks%rowtype;
  v_notifications_created integer := 0;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa Content Plan.';
  end if;

  if not public.can_edit_content_plan_content() then
    raise exception 'Bạn không có quyền xóa Content Plan.';
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

  if v_task.id is not null and v_task.editor_id is not null then
    v_notifications_created := v_notifications_created + public.create_content_video_notification(
      v_task.editor_id,
      v_actor_id,
      'content_plan_deleted',
      'Task đã bị hủy',
      'Task “' || v_plan.title || '” từ Content Plan đã bị hủy.',
      'content_plan',
      p_content_plan_id,
      '/content-plan',
      jsonb_build_object(
        'content_plan_id', p_content_plan_id,
        'video_task_id', v_task.id,
        'editor_id', v_task.editor_id,
        'air_date', v_plan.air_date
      ),
      'content_plan_deleted:' || p_content_plan_id::text || ':' || v_task.id::text || ':' || v_task.editor_id::text
    );
  end if;

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
    p_content_plan_id,
    'deleted',
    v_plan.title,
    'Đã xóa kế hoạch content "' || v_plan.title || '".',
    jsonb_build_object(
      'content_plan_id', p_content_plan_id,
      'video_task_id', v_task.id,
      'had_linked_task', v_task.id is not null
    )
  );

  delete from public.content_plan
  where id = p_content_plan_id;

  content_plan_id := p_content_plan_id;
  video_task_id := v_task.id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

create or replace function public.delete_video_task_with_notifications(p_video_task_id uuid)
returns table (
  video_task_id uuid,
  content_plan_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_task public.video_tasks%rowtype;
  v_plan public.content_plan%rowtype;
  v_notifications_created integer := 0;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa Task.';
  end if;

  if not public.can_edit_video_tasks() then
    raise exception 'Bạn không có quyền xóa Task.';
  end if;

  select *
  into v_task
  from public.video_tasks
  where id = p_video_task_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Task.';
  end if;

  if v_task.content_plan_id is not null then
    select *
    into v_plan
    from public.content_plan
    where id = v_task.content_plan_id
    for update;

    v_notifications_created := v_notifications_created + public.create_content_video_notification(
      v_plan.created_by,
      v_actor_id,
      'video_task_deleted',
      'Video Task đã bị hủy',
      'Video Task “' || v_task.title || '” đã bị hủy.',
      'video_task',
      p_video_task_id,
      '/content-plan?highlight=' || v_task.content_plan_id::text,
      jsonb_build_object(
        'content_plan_id', v_task.content_plan_id,
        'video_task_id', p_video_task_id,
        'editor_id', v_task.editor_id
      ),
      'video_task_deleted:' || p_video_task_id::text || ':' || coalesce(v_plan.created_by::text, 'none')
    );
  end if;

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
    'deleted',
    v_task.title,
    'Đã xóa video task "' || v_task.title || '".',
    jsonb_build_object(
      'video_task_id', p_video_task_id,
      'content_plan_id', v_task.content_plan_id,
      'linked_task', v_task.content_plan_id is not null
    )
  );

  delete from public.video_tasks
  where id = p_video_task_id;

  video_task_id := p_video_task_id;
  content_plan_id := v_task.content_plan_id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

revoke execute on function public.normalize_content_video_text(text) from public, anon, authenticated;
revoke execute on function public.format_content_video_date(date) from public, anon, authenticated;
revoke execute on function public.content_video_change_summary(text[]) from public, anon, authenticated;
revoke execute on function public.create_content_video_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from public, anon, authenticated;

revoke all on function public.assign_content_plan_editor(uuid, uuid) from public;
revoke all on function public.assign_content_plan_editor(uuid, uuid) from anon;
grant execute on function public.assign_content_plan_editor(uuid, uuid) to authenticated;

revoke all on function public.accept_linked_video_task(uuid, date, date) from public;
revoke all on function public.accept_linked_video_task(uuid, date, date) from anon;
grant execute on function public.accept_linked_video_task(uuid, date, date) to authenticated;

revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from public;
revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from anon;
grant execute on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) to authenticated;

revoke all on function public.complete_linked_video_task(uuid, text) from public;
revoke all on function public.complete_linked_video_task(uuid, text) from anon;
grant execute on function public.complete_linked_video_task(uuid, text) to authenticated;

revoke all on function public.delete_content_plan_with_notifications(uuid) from public;
revoke all on function public.delete_content_plan_with_notifications(uuid) from anon;
grant execute on function public.delete_content_plan_with_notifications(uuid) to authenticated;

revoke all on function public.delete_video_task_with_notifications(uuid) from public;
revoke all on function public.delete_video_task_with_notifications(uuid) from anon;
grant execute on function public.delete_video_task_with_notifications(uuid) to authenticated;

comment on function public.assign_content_plan_editor(uuid, uuid) is
  'Atomically assigns/reassigns a Content Plan editor, creates/updates its linked Video Task, and emits Phase 5.3 notifications.';
comment on function public.accept_linked_video_task(uuid, date, date) is
  'Assigned editor accepts a linked Video Task and writes activity only; no creator notification.';
comment on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) is
  'Assigned editor updates execution-owned fields for a linked Video Task and writes activity only; no creator notification.';
comment on function public.complete_linked_video_task(uuid, text) is
  'Assigned editor completes a linked Video Task, syncs the final link to Content Plan, and emits one completion notification.';
comment on function public.delete_content_plan_with_notifications(uuid) is
  'Deletes one Content Plan and notifies the assigned editor when a linked task is cancelled by cascade.';
comment on function public.delete_video_task_with_notifications(uuid) is
  'Deletes one Video Task and notifies the source Content Plan creator only for linked tasks.';

commit;
