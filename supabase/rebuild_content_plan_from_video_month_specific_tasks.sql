-- One-off rebuild: take Video tháng as source of truth and recreate exactly these Content Plan rows.
--
-- Targets:
-- - VIDEO COMPANY TRIP
-- - Teasing Drap 3 - Thuộc về
--
-- What it does:
-- - Chooses the canonical Video tháng task for each target.
-- - Unlinks the canonical task so it will not be deleted by Content Plan cascade.
-- - Deletes old matching Content Plan rows and their linked duplicate video tasks.
-- - Inserts fresh Content Plan rows from Video tháng data.
-- - Relinks the canonical Video tháng tasks to the new Content Plan rows.
-- - Deletes remaining manual duplicate Video tháng rows for those same titles.

begin;

create temp table rebuild_targets (
  label text primary key,
  title_pattern text not null
) on commit drop;

insert into rebuild_targets (label, title_pattern)
values
  ('VIDEO COMPANY TRIP', '^videocompanytrip$'),
  ('TEASING DRAP 3 - THUOC VE', '^(video)?(teaser|tearser|teasing)(drap|draft)3.*$');

create or replace function pg_temp.rebuild_normalized_title(p_value text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]+', '', 'g');
$$;

create temp table rebuild_video_candidates on commit drop as
select
  t.label,
  vt.*,
  linked_cp.title as linked_content_plan_title,
  row_number() over (
    partition by t.label
    order by
      case
        when vt.status = 'Đã xong'
         and nullif(btrim(coalesce(vt.result_link, '')), '') is not null
          then 0
        else 1
      end,
      case when vt.content_plan_id is null then 0 else 1 end,
      vt.updated_at desc nulls last,
      vt.created_at desc nulls last,
      vt.id
  ) as source_rank
from rebuild_targets t
join public.video_tasks vt on true
left join public.content_plan linked_cp
  on linked_cp.id = vt.content_plan_id
where pg_temp.rebuild_normalized_title(vt.title) ~ t.title_pattern
   or pg_temp.rebuild_normalized_title(linked_cp.title) ~ t.title_pattern;

do $$
declare
  v_problem text;
begin
  select string_agg(t.label || ' (Video tháng: ' || coalesce(c.video_count, 0) || ')', '; ')
  into v_problem
  from rebuild_targets t
  left join (
    select label, count(*) as video_count
    from rebuild_video_candidates
    group by label
  ) c on c.label = t.label
  where coalesce(c.video_count, 0) = 0;

  if v_problem is not null then
    raise exception 'Rebuild stopped: missing source Video tháng task: %', v_problem;
  end if;
end;
$$;

create temp table rebuild_source_video on commit drop as
select *
from rebuild_video_candidates
where source_rank = 1;

do $$
declare
  v_problem text;
begin
  select string_agg(label, '; ')
  into v_problem
  from rebuild_source_video
  where editor_id is null
     or air_date is null;

  if v_problem is not null then
    raise exception 'Rebuild stopped: source Video tháng task must have editor_id and air_date: %', v_problem;
  end if;
end;
$$;

create temp table rebuild_old_content_plan on commit drop as
select
  t.label,
  cp.id
from rebuild_targets t
join public.content_plan cp
  on pg_temp.rebuild_normalized_title(cp.title) ~ t.title_pattern;

do $$
declare
  v_problem text;
begin
  select string_agg(s.label, '; ')
  into v_problem
  from rebuild_source_video s
  where s.content_plan_id is not null
    and not exists (
      select 1
      from rebuild_old_content_plan old_cp
      where old_cp.label = s.label
        and old_cp.id = s.content_plan_id
    );

  if v_problem is not null then
    raise exception 'Rebuild stopped: canonical Video tháng task is linked to a non-target Content Plan: %', v_problem;
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_trigger
    where tgrelid = 'public.video_tasks'::regclass
      and tgname = 'video_tasks_content_plan_id_immutable_guard'
  ) then
    alter table public.video_tasks disable trigger video_tasks_content_plan_id_immutable_guard;
  end if;

  if exists (
    select 1 from pg_trigger
    where tgrelid = 'public.content_plan'::regclass
      and tgname = 'content_plan_field_permission_guard'
  ) then
    alter table public.content_plan disable trigger content_plan_field_permission_guard;
  end if;
end;
$$;

-- Keep canonical Video tháng rows safe before deleting old Content Plan rows.
update public.video_tasks vt
set content_plan_id = null,
    updated_by = coalesce(vt.updated_by, vt.created_by)
from rebuild_source_video s
where vt.id = s.id;

-- Delete old Content Plan rows. Any old linked video task duplicates are removed by FK cascade.
delete from public.content_plan cp
using rebuild_old_content_plan old_cp
where cp.id = old_cp.id;

create temp table rebuild_new_content_plan (
  label text primary key,
  content_plan_id uuid not null
) on commit drop;

do $$
declare
  r record;
  v_new_content_plan_id uuid;
begin
  for r in
    select *
    from rebuild_source_video
    order by label
  loop
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
      r.air_date,
      r.title,
      nullif(btrim(coalesce(r.notes, '')), ''),
      case
        when r.category in ('Video dài', 'Motion', 'Ads') then r.category
        else null
      end,
      case
        when r.status = 'Đã xong'
         and nullif(btrim(coalesce(r.result_link, '')), '') is not null
          then btrim(r.result_link)
        else null
      end,
      r.editor_id,
      coalesce(r.created_by, r.updated_by),
      coalesce(r.updated_by, r.created_by)
    )
    returning id into v_new_content_plan_id;

    insert into rebuild_new_content_plan (label, content_plan_id)
    values (r.label, v_new_content_plan_id);

    update public.video_tasks
    set content_plan_id = v_new_content_plan_id,
        editor_id = r.editor_id,
        status = r.status,
        result_link = nullif(btrim(coalesce(r.result_link, '')), ''),
        order_team = r.order_team,
        priority = r.priority,
        resize_reqs = r.resize_reqs,
        receive_date = r.receive_date,
        return_date = r.return_date,
        air_date = r.air_date,
        category = r.category,
        notes = r.notes,
        updated_by = coalesce(r.updated_by, r.created_by)
    where id = r.id;
  end loop;
end;
$$;

-- Remove any remaining manual duplicate rows for these target titles.
delete from public.video_tasks vt
using rebuild_targets t, rebuild_source_video s
where t.label = s.label
  and vt.id <> s.id
  and vt.content_plan_id is null
  and pg_temp.rebuild_normalized_title(vt.title) ~ t.title_pattern;

do $$
begin
  if exists (
    select 1 from pg_trigger
    where tgrelid = 'public.content_plan'::regclass
      and tgname = 'content_plan_field_permission_guard'
  ) then
    alter table public.content_plan enable trigger content_plan_field_permission_guard;
  end if;

  if exists (
    select 1 from pg_trigger
    where tgrelid = 'public.video_tasks'::regclass
      and tgname = 'video_tasks_content_plan_id_immutable_guard'
  ) then
    alter table public.video_tasks enable trigger video_tasks_content_plan_id_immutable_guard;
  end if;
end;
$$;

select
  s.label,
  s.id as source_video_task_id,
  ncp.content_plan_id as new_content_plan_id,
  cp.title as content_plan_title,
  cp.air_date as content_plan_air_date,
  cp.editor_id as content_plan_editor_id,
  cp.link as content_plan_link,
  vt.status as video_task_status,
  vt.editor_id as video_task_editor_id,
  vt.result_link as video_task_result_link,
  vt.content_plan_id as video_task_content_plan_id
from rebuild_source_video s
join rebuild_new_content_plan ncp
  on ncp.label = s.label
join public.content_plan cp
  on cp.id = ncp.content_plan_id
join public.video_tasks vt
  on vt.id = s.id
order by s.label;

commit;
