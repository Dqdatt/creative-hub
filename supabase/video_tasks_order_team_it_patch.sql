-- ============================================================
-- CreativeHub - Video Task Team Order IT patch
-- Adds IT to the existing video_tasks.order_team CHECK constraint.
-- Safe to run in Supabase SQL Editor after supabase/setup.sql.
-- ============================================================

begin;

alter table public.video_tasks drop constraint if exists video_tasks_order_team_check;

alter table public.video_tasks
  add constraint video_tasks_order_team_check
  check (order_team is null or order_team in ('BRAND', 'DIGITAL', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR'));

commit;

select
  con.conname as constraint_name,
  pg_get_constraintdef(con.oid) as constraint_definition
from pg_constraint con
join pg_class rel
  on rel.oid = con.conrelid
join pg_namespace nsp
  on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'video_tasks'
  and con.conname = 'video_tasks_order_team_check';
