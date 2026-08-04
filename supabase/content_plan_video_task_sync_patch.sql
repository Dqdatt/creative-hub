-- ============================================================
-- CreativeHub - Sync linked Video tháng tasks from Content Plan
-- Run after:
-- - supabase/content_plan_link_patch.sql
-- - supabase/linked_task_field_lock_patch.sql
-- ============================================================

begin;

create or replace function public.sync_linked_video_task_from_content_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.title is not distinct from old.title
    and new.note is not distinct from old.note
    and new.category is not distinct from old.category
    and new.air_date is not distinct from old.air_date
    and new.editor_id is not distinct from old.editor_id then
    return new;
  end if;

  perform set_config('app.content_plan_assignment', 'on', true);

  update public.video_tasks
  set title = new.title,
      notes = new.note,
      category = case
        when new.category in ('Video dài', 'Motion', 'Ads') then new.category
        else public.video_tasks.category
      end,
      air_date = new.air_date,
      editor_id = new.editor_id,
      updated_by = new.updated_by
  where public.video_tasks.content_plan_id = new.id;

  return new;
end;
$$;

drop trigger if exists content_plan_video_task_sync on public.content_plan;
create trigger content_plan_video_task_sync
after update of title, note, category, air_date, editor_id on public.content_plan
for each row execute function public.sync_linked_video_task_from_content_plan();

commit;

select
  tg.tgname,
  proc.proname as function_name
from pg_trigger tg
join pg_class rel on rel.oid = tg.tgrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
join pg_proc proc on proc.oid = tg.tgfoid
where nsp.nspname = 'public'
  and rel.relname = 'content_plan'
  and tg.tgname = 'content_plan_video_task_sync';
