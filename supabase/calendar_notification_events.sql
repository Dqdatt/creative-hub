-- ============================================================
-- CreativeHub - Calendar notification events
-- Phase 5.2: trusted Calendar mutation RPCs + internal notifications.
-- Safe to run after setup.sql, role/profile patches, editor membership,
-- activity_log_schema.sql, and internal_notifications_foundation.sql.
-- ============================================================

begin;

create or replace function public.normalize_calendar_text(p_value text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(btrim(regexp_replace(coalesce(p_value, ''), '\s+', ' ', 'g')), '');
$$;

create or replace function public.normalize_calendar_editor_codes(p_editor_codes text[])
returns text[]
language sql
immutable
set search_path = public
as $$
  select coalesce(array_agg(editor_code order by editor_code), '{}'::text[])
  from (
    select distinct lower(public.normalize_calendar_text(value)) as editor_code
    from unnest(coalesce(p_editor_codes, '{}'::text[])) as value
    where public.normalize_calendar_text(value) is not null
  ) normalized
  where editor_code is not null;
$$;

create or replace function public.format_calendar_notification_datetime(
  p_shoot_date date,
  p_time_slot text
)
returns text
language sql
stable
set search_path = public
as $$
  select case
    when public.normalize_calendar_text(p_time_slot) is null then to_char(p_shoot_date, 'DD/MM/YYYY')
    else to_char(p_shoot_date, 'DD/MM/YYYY') || ' lúc ' || public.normalize_calendar_text(p_time_slot)
  end;
$$;

create or replace function public.calendar_change_summary(p_labels text[])
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

create or replace function public.resolve_calendar_editor_profile_ids(p_editor_codes text[])
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_editor_codes text[];
  v_profile_ids uuid[];
begin
  v_editor_codes := public.normalize_calendar_editor_codes(p_editor_codes);

  if cardinality(v_editor_codes) = 0 then
    return '{}'::uuid[];
  end if;

  select coalesce(array_agg(p.id order by lower(p.editor_code)), '{}'::uuid[])
  into v_profile_ids
  from public.profiles p
  where lower(public.normalize_calendar_text(p.editor_code)) = any(v_editor_codes)
    and coalesce(p.is_editor_member, false) = true
    and coalesce(p.is_active, p.active, true) = true;

  if cardinality(v_profile_ids) <> cardinality(v_editor_codes) then
    raise exception 'Không tìm thấy profile editor hợp lệ. Hãy kiểm tra Editor Code và bật "Tham gia team editor" trong Thành viên.';
  end if;

  return v_profile_ids;
end;
$$;

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
begin
  if p_recipient_id is null then
    return 0;
  end if;

  if p_actor_id is not null and p_recipient_id = p_actor_id then
    return 0;
  end if;

  perform public.create_internal_notification(
    p_recipient_id,
    p_actor_id,
    p_type,
    p_title,
    p_body,
    'shoot',
    p_shoot_id,
    p_action_url,
    coalesce(p_metadata, '{}'::jsonb),
    p_event_key
  );

  return 1;
end;
$$;

create or replace function public.create_shoot_with_notifications(
  p_shoot_date date,
  p_shoot_type text,
  p_crew text,
  p_time_slot text,
  p_location text,
  p_content_note text,
  p_editor_codes text[] default '{}'::text[]
)
returns table (
  shoot_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_location text;
  v_crew text;
  v_time_slot text;
  v_content_note text;
  v_member_ids uuid[];
  v_member_id uuid;
  v_shoot_id uuid;
  v_context text;
  v_body text;
  v_notifications_created integer := 0;
  v_metadata jsonb;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để tạo lịch quay.' using errcode = '42501';
  end if;

  if not public.can_edit_shoots() then
    raise exception 'Bạn không có quyền tạo lịch quay.' using errcode = '42501';
  end if;

  if p_shoot_type not in ('livestream', 'lichquay', 'onset', 'other') then
    raise exception 'Loại lịch quay không hợp lệ.';
  end if;

  v_location := public.normalize_calendar_text(p_location);
  if v_location is null then
    raise exception 'Vui lòng nhập địa điểm lịch quay.';
  end if;

  v_crew := public.normalize_calendar_text(p_crew);
  v_time_slot := public.normalize_calendar_text(p_time_slot);
  v_content_note := public.normalize_calendar_text(p_content_note);
  v_member_ids := public.resolve_calendar_editor_profile_ids(p_editor_codes);

  insert into public.shoots (
    shoot_date,
    shoot_type,
    crew,
    time_slot,
    location,
    content_note,
    status,
    priority,
    created_by,
    updated_by
  )
  values (
    p_shoot_date,
    p_shoot_type,
    v_crew,
    v_time_slot,
    v_location,
    v_content_note,
    'scheduled',
    '',
    v_actor_id,
    v_actor_id
  )
  returning id into v_shoot_id;

  if cardinality(v_member_ids) > 0 then
    insert into public.shoot_editors (shoot_id, profile_id, created_by)
    select v_shoot_id, member_id, v_actor_id
    from unnest(v_member_ids) as member_id
    on conflict do nothing;
  end if;

  v_context := public.format_calendar_notification_datetime(p_shoot_date, v_time_slot);
  v_body := 'Bạn được thêm vào lịch “' || v_location || '” vào ' || v_context || '.';
  v_metadata := jsonb_build_object(
    'shoot_type', p_shoot_type,
    'shoot_date', p_shoot_date,
    'time_slot', v_time_slot,
    'location', v_location
  );

  foreach v_member_id in array v_member_ids loop
    v_notifications_created := v_notifications_created + public.create_calendar_shoot_notification(
      v_member_id,
      v_actor_id,
      'shoot_created',
      'Lịch quay mới',
      v_body,
      v_shoot_id,
      '/calendar?highlight=' || v_shoot_id::text,
      v_metadata,
      'shoot_created:' || v_shoot_id::text || ':' || v_member_id::text
    );
  end loop;

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
    'shoot',
    v_shoot_id,
    'created',
    v_location,
    'Đã tạo lịch quay "' || v_location || '".',
    jsonb_build_object(
      'shoot_date', p_shoot_date,
      'shoot_type', p_shoot_type,
      'crew', v_crew,
      'editor_ids', public.normalize_calendar_editor_codes(p_editor_codes),
      'time_slot', v_time_slot
    )
  );

  shoot_id := v_shoot_id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

create or replace function public.update_shoot_with_notifications(
  p_shoot_id uuid,
  p_shoot_date date,
  p_shoot_type text,
  p_crew text,
  p_time_slot text,
  p_location text,
  p_content_note text,
  p_editor_codes text[] default '{}'::text[]
)
returns table (
  shoot_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_old public.shoots%rowtype;
  v_location text;
  v_crew text;
  v_time_slot text;
  v_content_note text;
  v_old_member_ids uuid[];
  v_new_member_ids uuid[];
  v_added_member_ids uuid[];
  v_removed_member_ids uuid[];
  v_retained_member_ids uuid[];
  v_member_id uuid;
  v_changed_labels text[] := '{}'::text[];
  v_field_changed boolean := false;
  v_context text;
  v_summary text;
  v_notifications_created integer := 0;
  v_event_id text := gen_random_uuid()::text;
  v_metadata jsonb;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để cập nhật lịch quay.' using errcode = '42501';
  end if;

  if not public.can_edit_shoots() then
    raise exception 'Bạn không có quyền cập nhật lịch quay.' using errcode = '42501';
  end if;

  select *
  into v_old
  from public.shoots
  where id = p_shoot_id
  for update;

  if not found then
    raise exception 'Không tìm thấy lịch quay.';
  end if;

  if p_shoot_type not in ('livestream', 'lichquay', 'onset', 'other') then
    raise exception 'Loại lịch quay không hợp lệ.';
  end if;

  v_location := public.normalize_calendar_text(p_location);
  if v_location is null then
    raise exception 'Vui lòng nhập địa điểm lịch quay.';
  end if;

  v_crew := public.normalize_calendar_text(p_crew);
  v_time_slot := public.normalize_calendar_text(p_time_slot);
  v_content_note := public.normalize_calendar_text(p_content_note);
  v_new_member_ids := public.resolve_calendar_editor_profile_ids(p_editor_codes);

  select coalesce(array_agg(profile_id order by profile_id), '{}'::uuid[])
  into v_old_member_ids
  from (
    select se.profile_id
    from public.shoot_editors se
    where se.shoot_id = p_shoot_id
    for update
  ) locked_members;

  select coalesce(array_agg(member_id order by member_id), '{}'::uuid[])
  into v_added_member_ids
  from unnest(v_new_member_ids) as member_id
  where not member_id = any(v_old_member_ids);

  select coalesce(array_agg(member_id order by member_id), '{}'::uuid[])
  into v_removed_member_ids
  from unnest(v_old_member_ids) as member_id
  where not member_id = any(v_new_member_ids);

  select coalesce(array_agg(member_id order by member_id), '{}'::uuid[])
  into v_retained_member_ids
  from unnest(v_new_member_ids) as member_id
  where member_id = any(v_old_member_ids);

  if v_location is distinct from public.normalize_calendar_text(v_old.location) then
    v_changed_labels := array_append(v_changed_labels, 'địa điểm');
  end if;

  if p_shoot_type is distinct from v_old.shoot_type then
    v_changed_labels := array_append(v_changed_labels, 'loại lịch');
  end if;

  if p_shoot_date is distinct from v_old.shoot_date then
    v_changed_labels := array_append(v_changed_labels, 'ngày');
  end if;

  if v_time_slot is distinct from public.normalize_calendar_text(v_old.time_slot) then
    v_changed_labels := array_append(v_changed_labels, 'thời gian');
  end if;

  if v_crew is distinct from public.normalize_calendar_text(v_old.crew) then
    v_changed_labels := array_append(v_changed_labels, 'crew');
  end if;

  if v_content_note is distinct from public.normalize_calendar_text(v_old.content_note) then
    v_changed_labels := array_append(v_changed_labels, 'ghi chú');
  end if;

  v_field_changed := cardinality(v_changed_labels) > 0;

  if v_field_changed then
    update public.shoots
    set shoot_date = p_shoot_date,
        shoot_type = p_shoot_type,
        crew = v_crew,
        time_slot = v_time_slot,
        location = v_location,
        content_note = v_content_note,
        status = 'scheduled',
        priority = '',
        updated_by = v_actor_id
    where id = p_shoot_id;
  end if;

  if cardinality(v_removed_member_ids) > 0 then
    delete from public.shoot_editors
    where public.shoot_editors.shoot_id = p_shoot_id
      and public.shoot_editors.profile_id = any(v_removed_member_ids);
  end if;

  if cardinality(v_added_member_ids) > 0 then
    insert into public.shoot_editors (shoot_id, profile_id, created_by)
    select p_shoot_id, added_member_id, v_actor_id
    from unnest(v_added_member_ids) as added_member_id
    on conflict do nothing;
  end if;

  if not v_field_changed
    and cardinality(v_added_member_ids) = 0
    and cardinality(v_removed_member_ids) = 0 then
    shoot_id := p_shoot_id;
    notifications_created := 0;
    return next;
    return;
  end if;

  v_context := public.format_calendar_notification_datetime(p_shoot_date, v_time_slot);
  v_metadata := jsonb_build_object(
    'shoot_type', p_shoot_type,
    'shoot_date', p_shoot_date,
    'time_slot', v_time_slot,
    'location', v_location
  );

  foreach v_member_id in array v_added_member_ids loop
    v_notifications_created := v_notifications_created + public.create_calendar_shoot_notification(
      v_member_id,
      v_actor_id,
      'shoot_member_added',
      'Bạn được thêm vào lịch quay',
      'Bạn được thêm vào lịch “' || v_location || '” vào ' || v_context || '.',
      p_shoot_id,
      '/calendar?highlight=' || p_shoot_id::text,
      v_metadata,
      'shoot_member_added:' || p_shoot_id::text || ':' || v_member_id::text || ':' || v_event_id
    );
  end loop;

  foreach v_member_id in array v_removed_member_ids loop
    v_notifications_created := v_notifications_created + public.create_calendar_shoot_notification(
      v_member_id,
      v_actor_id,
      'shoot_member_removed',
      'Bạn đã được gỡ khỏi lịch quay',
      'Bạn không còn tham gia lịch “' || v_location || '” vào ' || v_context || '.',
      p_shoot_id,
      '/calendar?highlight=' || p_shoot_id::text,
      v_metadata,
      'shoot_member_removed:' || p_shoot_id::text || ':' || v_member_id::text || ':' || v_event_id
    );
  end loop;

  if v_field_changed then
    v_summary := public.calendar_change_summary(v_changed_labels);
    v_metadata := v_metadata || jsonb_build_object('changed_fields', to_jsonb(v_changed_labels));

    foreach v_member_id in array v_retained_member_ids loop
      v_notifications_created := v_notifications_created + public.create_calendar_shoot_notification(
        v_member_id,
        v_actor_id,
        'shoot_updated',
        'Lịch quay đã được cập nhật',
        'Lịch “' || v_location || '” đã thay đổi: ' || v_summary || '.',
        p_shoot_id,
        '/calendar?highlight=' || p_shoot_id::text,
        v_metadata,
        'shoot_updated:' || p_shoot_id::text || ':' || v_member_id::text || ':' || v_event_id
      );
    end loop;
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
    'shoot',
    p_shoot_id,
    'updated',
    v_location,
    'Đã cập nhật lịch quay "' || v_location || '".',
    jsonb_build_object(
      'shoot_date', p_shoot_date,
      'shoot_type', p_shoot_type,
      'crew', v_crew,
      'editor_ids', public.normalize_calendar_editor_codes(p_editor_codes),
      'time_slot', v_time_slot,
      'changed_fields', v_changed_labels,
      'added_members', v_added_member_ids,
      'removed_members', v_removed_member_ids
    )
  );

  shoot_id := p_shoot_id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

create or replace function public.delete_shoot_with_notifications(p_shoot_id uuid)
returns table (
  shoot_id uuid,
  notifications_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_old public.shoots%rowtype;
  v_member_ids uuid[];
  v_member_id uuid;
  v_context text;
  v_notifications_created integer := 0;
  v_metadata jsonb;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa lịch quay.' using errcode = '42501';
  end if;

  if not public.can_edit_shoots() then
    raise exception 'Bạn không có quyền xóa lịch quay.' using errcode = '42501';
  end if;

  select *
  into v_old
  from public.shoots
  where id = p_shoot_id
  for update;

  if not found then
    raise exception 'Không tìm thấy lịch quay.';
  end if;

  select coalesce(array_agg(profile_id order by profile_id), '{}'::uuid[])
  into v_member_ids
  from (
    select se.profile_id
    from public.shoot_editors se
    where se.shoot_id = p_shoot_id
    for update
  ) locked_members;

  v_context := public.format_calendar_notification_datetime(v_old.shoot_date, v_old.time_slot);
  v_metadata := jsonb_build_object(
    'shoot_type', v_old.shoot_type,
    'shoot_date', v_old.shoot_date,
    'time_slot', public.normalize_calendar_text(v_old.time_slot),
    'location', public.normalize_calendar_text(v_old.location)
  );

  foreach v_member_id in array v_member_ids loop
    v_notifications_created := v_notifications_created + public.create_calendar_shoot_notification(
      v_member_id,
      v_actor_id,
      'shoot_cancelled',
      'Lịch quay đã bị hủy',
      'Lịch “' || public.normalize_calendar_text(v_old.location) || '” vào ' || v_context || ' đã bị hủy.',
      p_shoot_id,
      '/calendar?date=' || v_old.shoot_date::text,
      v_metadata,
      'shoot_cancelled:' || p_shoot_id::text || ':' || v_member_id::text
    );
  end loop;

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
    'shoot',
    p_shoot_id,
    'deleted',
    public.normalize_calendar_text(v_old.location),
    'Đã xóa lịch quay "' || public.normalize_calendar_text(v_old.location) || '".',
    jsonb_build_object('shoot_id', p_shoot_id, 'shoot_date', v_old.shoot_date)
  );

  delete from public.shoots
  where id = p_shoot_id;

  shoot_id := p_shoot_id;
  notifications_created := v_notifications_created;
  return next;
end;
$$;

revoke execute on function public.normalize_calendar_text(text) from public;
revoke execute on function public.normalize_calendar_editor_codes(text[]) from public;
revoke execute on function public.format_calendar_notification_datetime(date, text) from public;
revoke execute on function public.calendar_change_summary(text[]) from public;
revoke execute on function public.resolve_calendar_editor_profile_ids(text[]) from public;
revoke execute on function public.create_calendar_shoot_notification(uuid, uuid, text, text, text, uuid, text, jsonb, text) from public;
revoke execute on function public.normalize_calendar_text(text) from anon, authenticated;
revoke execute on function public.normalize_calendar_editor_codes(text[]) from anon, authenticated;
revoke execute on function public.format_calendar_notification_datetime(date, text) from anon, authenticated;
revoke execute on function public.calendar_change_summary(text[]) from anon, authenticated;
revoke execute on function public.resolve_calendar_editor_profile_ids(text[]) from anon, authenticated;
revoke execute on function public.create_calendar_shoot_notification(uuid, uuid, text, text, text, uuid, text, jsonb, text) from anon, authenticated;

revoke execute on function public.create_shoot_with_notifications(date, text, text, text, text, text, text[]) from public;
revoke execute on function public.update_shoot_with_notifications(uuid, date, text, text, text, text, text, text[]) from public;
revoke execute on function public.delete_shoot_with_notifications(uuid) from public;
revoke execute on function public.create_shoot_with_notifications(date, text, text, text, text, text, text[]) from anon;
revoke execute on function public.update_shoot_with_notifications(uuid, date, text, text, text, text, text, text[]) from anon;
revoke execute on function public.delete_shoot_with_notifications(uuid) from anon;

grant execute on function public.create_shoot_with_notifications(date, text, text, text, text, text, text[]) to authenticated;
grant execute on function public.update_shoot_with_notifications(uuid, date, text, text, text, text, text, text[]) to authenticated;
grant execute on function public.delete_shoot_with_notifications(uuid) to authenticated;

comment on function public.create_shoot_with_notifications(date, text, text, text, text, text, text[]) is
  'Creates one Calendar shoot, assigns members, writes activity log, and notifies assigned non-actor members transactionally.';
comment on function public.update_shoot_with_notifications(uuid, date, text, text, text, text, text, text[]) is
  'Updates one Calendar shoot, derives member diff under row locks, writes activity log, and emits Calendar notifications transactionally.';
comment on function public.delete_shoot_with_notifications(uuid) is
  'Deletes one Calendar shoot after notifying current non-actor members with a safe date deep link.';

commit;
