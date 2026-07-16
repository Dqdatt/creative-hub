-- ============================================================
-- CreativeHub - Notification navigation highlight correction
-- Phase: action URL normalization and assignment notification dedupe.
-- Safe to run after Phase 5.2 and Phase 5.3 notification producer migrations.
-- ============================================================

begin;

create or replace function public.create_calendar_shoot_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_shoot_id uuid,
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
  v_action_url text := p_action_url;
begin
  if p_recipient_id is null then
    return 0;
  end if;

  if p_actor_id is not null and p_recipient_id = p_actor_id then
    return 0;
  end if;

  if v_action_url like '/calendar?shoot=%' then
    v_action_url := '/calendar?highlight=' || p_shoot_id::text;
  end if;

  perform public.create_internal_notification(
    p_recipient_id,
    p_actor_id,
    p_type,
    p_title,
    p_body,
    'shoot',
    p_shoot_id,
    v_action_url,
    coalesce(p_metadata, '{}'::jsonb),
    p_event_key
  );

  return 1;
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

  -- Initial Content Plan assignment already produces a clearer assigned notification.
  -- Keep the historical type valid, but stop producing this overlapping assignment event.
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

revoke execute on function public.create_calendar_shoot_notification(uuid, uuid, text, text, text, uuid, text, jsonb, text) from public;
revoke execute on function public.create_calendar_shoot_notification(uuid, uuid, text, text, text, uuid, text, jsonb, text) from anon, authenticated;
revoke execute on function public.create_content_video_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from public;
revoke execute on function public.create_content_video_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) from anon, authenticated;

comment on function public.create_calendar_shoot_notification(uuid, uuid, text, text, text, uuid, text, jsonb, text) is
  'Internal Calendar notification producer helper. Normalizes active shoot action URLs to highlight navigation.';
comment on function public.create_content_video_notification(uuid, uuid, text, text, text, text, uuid, text, jsonb, text) is
  'Internal Content Plan and linked Video Task notification producer helper. Normalizes highlight URLs and deduplicates initial assignment notifications.';

commit;
