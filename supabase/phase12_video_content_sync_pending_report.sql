-- ============================================================
-- CreativeHub Phase 12 - Video Task <-> Content Plan sync
-- Pending status + linked task atomic update contract.
--
-- Idempotent migration. It preserves legacy linked rows whose
-- status is still 'Chờ'; no historical status-label backfill.
-- ============================================================

begin;

alter table public.video_tasks drop constraint if exists video_tasks_status_check;
alter table public.video_tasks
  add constraint video_tasks_status_check
  check (status in ('Pending', 'Chờ', 'Đang làm', 'Đã xong'));

create or replace function public.is_linked_video_task_execution_update_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_execution_update', true) = 'on', false);
$$;

create or replace function public.is_linked_video_task_sync_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_sync', true) = 'on', false);
$$;

create or replace function public.normalize_new_linked_video_task_pending()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT'
    and new.content_plan_id is not null
    and new.status = 'Chờ' then
    new.status := 'Pending';
  end if;

  return new;
end;
$$;

drop trigger if exists video_tasks_linked_pending_normalize on public.video_tasks;
create trigger video_tasks_linked_pending_normalize
before insert on public.video_tasks
for each row execute function public.normalize_new_linked_video_task_pending();

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
    and new.notes is distinct from old.notes
    and not (
      public.is_content_plan_assignment_context()
      or public.is_linked_video_task_sync_context()
    ) then
    raise exception 'Ghi chú Task liên kết được đồng bộ giữa Content Plan và Video tháng.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.order_team is distinct from old.order_team
      or new.priority is distinct from old.priority
      or new.resize_reqs is distinct from old.resize_reqs
    )
    and not (
      public.is_linked_video_task_execution_update_context()
      or public.is_linked_video_task_sync_context()
    ) then
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
    and old.status in ('Chờ', 'Pending')
    and (
      new.status is distinct from old.status
      or new.receive_date is distinct from old.receive_date
      or new.return_date is distinct from old.return_date
      or new.result_link is distinct from old.result_link
    )
    and not (
      public.is_linked_video_task_acceptance_context()
      or public.is_linked_video_task_sync_context()
    ) then
    raise exception 'Hãy nhận Task liên kết qua thao tác Nhận Task.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and old.status in ('Đang làm', 'Đã xong')
    and new.status is distinct from old.status
    and not (
      public.is_linked_video_task_completion_context()
      or public.is_linked_video_task_sync_context()
    ) then
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
      or public.is_linked_video_task_sync_context()
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
    'content_plan_completed',
    'video_task_content_plan_synced'
  ));

create or replace function public.sync_linked_video_task_from_video_month(
  p_video_task_id uuid,
  p_status text,
  p_order_team text,
  p_priority text,
  p_resize_reqs text,
  p_receive_date date,
  p_return_date date,
  p_result_link text,
  p_note text
)
returns table (
  video_task_id uuid,
  content_plan_id uuid,
  status text,
  result_link text,
  content_plan_link text,
  note text,
  changed_fields text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_role text := public.current_profile_role();
  v_task public.video_tasks%rowtype;
  v_plan public.content_plan%rowtype;
  v_status text := coalesce(nullif(btrim(p_status), ''), 'Pending');
  v_order_team text := nullif(btrim(coalesce(p_order_team, '')), '');
  v_priority text := coalesce(p_priority, '');
  v_resize_reqs text := nullif(btrim(coalesce(p_resize_reqs, '')), '');
  v_result_link text := nullif(btrim(coalesce(p_result_link, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_changed_fields text[] := array[]::text[];
  v_event_at timestamptz := timezone('utc'::text, now());
begin
  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để đồng bộ Task liên kết.';
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
    raise exception 'Task thủ công không có Content Plan liên kết để đồng bộ.';
  end if;

  select *
  into v_plan
  from public.content_plan
  where id = v_task.content_plan_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Content Plan liên kết.';
  end if;

  if not (
    v_role in ('admin', 'creative_manager', 'content_creator', 'team_lead')
    or exists (
      select 1
      from public.profiles p
      where p.id = v_actor_id
        and p.id = v_task.editor_id
        and coalesce(p.active, true) = true
        and coalesce(p.is_active, true) = true
        and p.is_editor_member = true
    )
  ) then
    raise exception 'Bạn không có quyền đồng bộ Task liên kết.';
  end if;

  if v_status not in ('Pending', 'Chờ', 'Đang làm', 'Đã xong') then
    raise exception 'Trạng thái Task chưa hợp lệ.';
  end if;

  if v_task.status in ('Chờ', 'Pending') and v_status in ('Chờ', 'Pending') then
    v_status := v_task.status;
  elsif v_task.status in ('Chờ', 'Pending') and v_status not in ('Chờ', 'Pending') then
    raise exception 'Hãy nhận Task liên kết qua thao tác Nhận Task.';
  elsif v_task.status = 'Đang làm' and v_status not in ('Đang làm', 'Đã xong') then
    raise exception 'Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.';
  elsif v_task.status = 'Đã xong' and v_status <> 'Đã xong' then
    raise exception 'Task này đã hoàn thành hoặc trạng thái đã thay đổi.';
  end if;

  if length(coalesce(v_note, '')) > 2000 then
    raise exception 'Ghi chú tối đa 2000 ký tự.';
  end if;

  if v_order_team is not null
    and v_order_team not in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR') then
    raise exception 'Team Order chưa hợp lệ.';
  end if;

  if v_priority not in ('', 'Gấp') then
    raise exception 'Độ ưu tiên chưa hợp lệ.';
  end if;

  if p_receive_date is not null and p_return_date is not null and p_return_date < p_receive_date then
    raise exception 'Ngày nhận và Ngày trả chưa hợp lệ.';
  end if;

  if v_result_link is not null
    and v_result_link !~* '^https?://[^[:space:]/?#]+[^[:space:]<>"'']*$' then
    raise exception 'Link thành phẩm chưa hợp lệ.';
  end if;

  if v_status is distinct from v_task.status then v_changed_fields := array_append(v_changed_fields, 'status'); end if;
  if v_order_team is distinct from v_task.order_team then v_changed_fields := array_append(v_changed_fields, 'order_team'); end if;
  if v_priority is distinct from v_task.priority then v_changed_fields := array_append(v_changed_fields, 'priority'); end if;
  if v_resize_reqs is distinct from v_task.resize_reqs then v_changed_fields := array_append(v_changed_fields, 'resize_reqs'); end if;
  if p_receive_date is distinct from v_task.receive_date then v_changed_fields := array_append(v_changed_fields, 'receive_date'); end if;
  if p_return_date is distinct from v_task.return_date then v_changed_fields := array_append(v_changed_fields, 'return_date'); end if;
  if v_result_link is distinct from v_task.result_link then v_changed_fields := array_append(v_changed_fields, 'result_link'); end if;
  if v_note is distinct from v_plan.note then v_changed_fields := array_append(v_changed_fields, 'note'); end if;

  perform set_config('app.linked_video_task_sync', 'on', true);
  perform set_config('app.linked_video_task_execution_update', 'on', true);
  if v_task.status = 'Đang làm' and v_status = 'Đã xong' then
    perform set_config('app.linked_video_task_completion', 'on', true);
  end if;

  update public.content_plan
  set note = v_note,
      link = v_result_link,
      updated_by = v_actor_id
  where id = v_task.content_plan_id;

  update public.video_tasks
  set status = v_status,
      order_team = v_order_team,
      priority = v_priority,
      resize_reqs = v_resize_reqs,
      receive_date = p_receive_date,
      return_date = p_return_date,
      result_link = v_result_link,
      notes = v_note,
      updated_by = v_actor_id
  where id = p_video_task_id;

  if cardinality(v_changed_fields) > 0 then
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
      'video_task_content_plan_synced',
      v_plan.title,
      'Đã đồng bộ Video Task liên kết với Content Plan.',
      jsonb_build_object(
        'video_task_id', p_video_task_id,
        'content_plan_id', v_task.content_plan_id,
        'changed_fields', v_changed_fields,
        'previous_status', v_task.status,
        'status', v_status,
        'has_result_link', v_result_link is not null,
        'actor_id', v_actor_id,
        'created_at', v_event_at
      )
    );
  end if;

  video_task_id := p_video_task_id;
  content_plan_id := v_task.content_plan_id;
  status := v_status;
  result_link := v_result_link;
  content_plan_link := v_result_link;
  note := v_note;
  changed_fields := v_changed_fields;
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
  v_actor_id uuid := auth.uid();
  v_task public.video_tasks%rowtype;
  v_event_at timestamptz := timezone('utc'::text, now());
begin
  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để nhận Task.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_actor_id
      and coalesce(p.active, true) = true
      and coalesce(p.is_active, true) = true
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

  if v_task.status not in ('Chờ', 'Pending') then
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
      'previous_status', v_task.status,
      'new_status', 'Đang làm',
      'actor_id', v_actor_id,
      'created_at', v_event_at
    )
  );

  return next;
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
      and coalesce(p.is_active, true) = true
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
      notes,
      created_by,
      updated_by
    )
    values (
      p_content_plan_id,
      v_plan.title,
      p_editor_id,
      'Pending',
      v_task_category,
      '',
      null,
      null,
      null,
      null,
      v_plan.air_date,
      null,
      v_plan.note,
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
          'status', v_task_status,
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
        'category', v_plan.category,
        'status', v_task_status
      ),
      'content_plan_assigned:' || p_content_plan_id::text || ':' || p_editor_id::text
    );

  else
    if v_task.status not in ('Chờ', 'Pending') and v_task.editor_id is distinct from p_editor_id then
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

revoke all on function public.sync_linked_video_task_from_video_month(uuid, text, text, text, text, date, date, text, text) from public;
revoke all on function public.sync_linked_video_task_from_video_month(uuid, text, text, text, text, date, date, text, text) from anon;
grant execute on function public.sync_linked_video_task_from_video_month(uuid, text, text, text, text, date, date, text, text) to authenticated;

revoke all on function public.accept_linked_video_task(uuid, date, date) from public;
revoke all on function public.accept_linked_video_task(uuid, date, date) from anon;
grant execute on function public.accept_linked_video_task(uuid, date, date) to authenticated;

revoke all on function public.assign_content_plan_editor(uuid, uuid) from public;
revoke all on function public.assign_content_plan_editor(uuid, uuid) from anon;
grant execute on function public.assign_content_plan_editor(uuid, uuid) to authenticated;

comment on function public.sync_linked_video_task_from_video_month(uuid, text, text, text, text, date, date, text, text) is
  'Atomic Phase 12 linked Video Task update path. Syncs shared note/result link to Content Plan and keeps Video-only execution fields on video_tasks.';

comment on function public.prevent_video_task_content_plan_relink() is
  'Guards linked Video Task ownership. Pending and legacy Chờ are both treated as not-yet-accepted states.';

comment on column public.video_tasks.status is
  'Canonical linked task status values: Pending, Đang làm, Đã xong. Chờ remains valid for legacy rows.';

commit;
