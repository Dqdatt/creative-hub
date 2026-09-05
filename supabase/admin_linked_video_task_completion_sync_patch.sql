-- Allow admin Video tháng saves to sync completion back to linked Content Plan.
-- This keeps the existing editor completion RPC intact, while covering the admin override path.

create or replace function public.admin_sync_linked_video_task_completion(
  p_video_task_id uuid,
  p_content_plan_id uuid,
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
    raise exception 'Bạn cần đăng nhập để đồng bộ Task.';
  end if;

  if not public.is_admin() then
    raise exception 'Bạn cần quyền admin để đồng bộ Task linked từ Video tháng.';
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

  if v_task.content_plan_id <> p_content_plan_id then
    raise exception 'Task không khớp Content Plan liên kết.';
  end if;

  v_normalized_link := btrim(coalesce(p_result_link, ''));

  if v_normalized_link = ''
    or v_normalized_link !~* '^https?://[^[:space:]/?#]+[^[:space:]<>"'']*$' then
    raise exception 'Link thành phẩm chưa hợp lệ.';
  end if;

  select *
  into v_plan
  from public.content_plan
  where id = p_content_plan_id
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
  where id = p_content_plan_id;

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
    'content_plan_completed',
    v_plan.title,
    'Admin đã đồng bộ link hoàn thành từ Video tháng sang Content Plan.',
    jsonb_build_object(
      'content_plan_id', p_content_plan_id,
      'video_task_id', p_video_task_id,
      'editor_id', v_task.editor_id,
      'result_link', v_normalized_link,
      'actor_id', v_actor_id,
      'created_at', v_completed_at
    )
  );

  video_task_id := p_video_task_id;
  content_plan_id := p_content_plan_id;
  status := 'Đã xong';
  result_link := v_normalized_link;
  content_plan_link := v_normalized_link;
  completed_at := v_completed_at;
  editor_id := v_task.editor_id;
  air_date := v_plan.air_date;
  return next;
end;
$$;

revoke all on function public.admin_sync_linked_video_task_completion(uuid, uuid, text) from public;
revoke all on function public.admin_sync_linked_video_task_completion(uuid, uuid, text) from anon;
grant execute on function public.admin_sync_linked_video_task_completion(uuid, uuid, text) to authenticated;

comment on function public.admin_sync_linked_video_task_completion(uuid, uuid, text) is
  'Admin-only sync for linked Video tháng completion into Content Plan when saving through the generic task modal.';
