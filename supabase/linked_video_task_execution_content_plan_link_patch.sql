-- ============================================================
-- CreativeHub - Sync linked Video Task execution link to Content Plan
-- Run after:
-- - supabase/linked_video_task_execution_update_rpc.sql
-- - supabase/content_plan_link_patch.sql
--
-- Fix:
-- When an assigned editor/admin-editor clicks "Luu thay doi" on a linked
-- Video thang task, result_link must mirror into content_plan.link too.
-- ============================================================

begin;

create or replace function public.is_linked_video_task_execution_update_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_execution_update', true) = 'on', false);
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
  v_plan public.content_plan%rowtype;
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
      and coalesce(p.is_active, true) = true
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

  select *
  into v_plan
  from public.content_plan
  where id = v_task.content_plan_id
  for update;

  if not found then
    raise exception 'Không tìm thấy Content Plan liên kết.';
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
  if v_result_link is distinct from v_plan.link then
    v_changed_fields := array_append(v_changed_fields, 'content_plan_link');
  end if;

  if cardinality(v_changed_fields) > 0 then
    perform set_config('app.linked_video_task_execution_update', 'on', true);
    perform set_config('app.linked_video_task_completion', 'on', true);

    update public.video_tasks
    set order_team = v_order_team,
        priority = v_priority,
        resize_reqs = v_resize_reqs,
        receive_date = p_receive_date,
        return_date = p_return_date,
        result_link = v_result_link,
        updated_by = v_actor_id
    where id = p_video_task_id;

    update public.content_plan
    set link = v_result_link,
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
        'synced_content_plan_link', v_result_link is distinct from v_plan.link,
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

revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from public;
revoke all on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) from anon;
grant execute on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) to authenticated;

comment on function public.update_linked_video_task_execution(uuid, text, text, text, date, date, text) is
  'Assigned editor/admin-editor updates execution fields and mirrors result_link to linked Content Plan.';

-- Optional safe repair for existing mismatches: only fills Content Plan with
-- non-empty Video thang links, never clears existing Content Plan links.
select set_config('app.linked_video_task_completion', 'on', true);

update public.content_plan cp
set link = nullif(btrim(vt.result_link), ''),
    updated_by = vt.updated_by
from public.video_tasks vt
where vt.content_plan_id = cp.id
  and nullif(btrim(coalesce(vt.result_link, '')), '') is not null
  and cp.link is distinct from nullif(btrim(vt.result_link), '');

commit;

select
  'linked_video_task_execution_content_plan_link_patch_applied' as patch,
  count(*) filter (
    where nullif(btrim(coalesce(vt.result_link, '')), '') is not null
      and cp.link is distinct from nullif(btrim(vt.result_link), '')
  ) as remaining_link_mismatches
from public.video_tasks vt
join public.content_plan cp on cp.id = vt.content_plan_id;
