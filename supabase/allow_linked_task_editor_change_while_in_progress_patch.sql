-- ============================================================
-- CreativeHub - Cho đổi Editor của Task liên kết khi Task đang làm
-- Chỉ chặn khi Task đã xong. Lấy nguyên văn hàm đang chạy trên production
-- rồi sửa đúng một điều kiện, phần còn lại giữ nguyên.
--
-- Muốn quay lại quy tắc cũ thì đổi dòng điều kiện thành:
--   if v_task.status not in ('Chờ', 'Pending') and v_task.editor_id is distinct from p_editor_id then
--     raise exception 'Không thể đổi Editor vì Task đã được bắt đầu.';
-- ============================================================

CREATE OR REPLACE FUNCTION public.assign_content_plan_editor(p_content_plan_id uuid, p_editor_id uuid)
 RETURNS TABLE(content_plan_id uuid, video_task_id uuid, editor_id uuid, task_created boolean, task_status text, air_date date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    if v_task.status = 'Đã xong' and v_task.editor_id is distinct from p_editor_id then
      raise exception 'Không thể đổi Editor vì Task đã xong.';
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
$function$
