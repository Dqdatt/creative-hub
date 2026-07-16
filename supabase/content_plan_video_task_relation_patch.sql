-- ============================================================
-- CreativeHub - Content Plan to Video Task relation
-- Safe to run in Supabase SQL Editor after setup.sql and content_plan_schema.sql.
-- ============================================================

begin;

alter table public.video_tasks
  add column if not exists content_plan_id uuid;

do $$
declare
  v_column_type text;
  v_duplicate_count integer;
begin
  select udt_name
  into v_column_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'video_tasks'
    and column_name = 'content_plan_id';

  if v_column_type is distinct from 'uuid' then
    raise exception 'public.video_tasks.content_plan_id must be uuid before adding Content Plan relation, found %.', v_column_type;
  end if;

  select count(*)
  into v_duplicate_count
  from (
    select content_plan_id
    from public.video_tasks
    where content_plan_id is not null
    group by content_plan_id
    having count(*) > 1
  ) duplicated_links;

  if v_duplicate_count > 0 then
    raise exception 'Duplicate non-null video_tasks.content_plan_id values found. Resolve duplicates before applying video_tasks_content_plan_id_unique.';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'video_tasks'
      and con.conname = 'video_tasks_content_plan_id_fkey'
  ) then
    alter table public.video_tasks
      add constraint video_tasks_content_plan_id_fkey
      foreign key (content_plan_id)
      references public.content_plan(id)
      on delete cascade;
  end if;
end $$;

create unique index if not exists video_tasks_content_plan_id_unique
  on public.video_tasks (content_plan_id)
  where content_plan_id is not null;

create or replace function public.is_content_plan_assignment_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.content_plan_assignment', true) = 'on', false);
$$;

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

create or replace function public.is_linked_video_task_execution_update_context()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(current_setting('app.linked_video_task_execution_update', true) = 'on', false);
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
      or new.category is distinct from old.category
      or new.air_date is distinct from old.air_date
    )
    and not public.is_content_plan_assignment_context() then
    raise exception 'Thông tin kế hoạch của Task liên kết được quản lý từ Content Plan.';
  end if;

  if tg_op = 'UPDATE'
    and old.content_plan_id is not null
    and (
      new.order_team is distinct from old.order_team
      or new.priority is distinct from old.priority
      or new.resize_reqs is distinct from old.resize_reqs
    )
    and not public.is_linked_video_task_execution_update_context() then
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
    and new.status is distinct from old.status
    and not public.is_linked_video_task_completion_context() then
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

comment on column public.video_tasks.content_plan_id is
  'Optional source Content Plan. Null means manual Video tháng task; non-null generated from Content Plan and cascades on Content Plan delete.';

commit;

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'video_tasks'
  and column_name = 'content_plan_id';

select
  con.conname,
  pg_get_constraintdef(con.oid) as constraint_definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'video_tasks'
  and con.conname = 'video_tasks_content_plan_id_fkey';

select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'video_tasks'
  and indexname = 'video_tasks_content_plan_id_unique';
