-- ============================================================
-- CreativeHub - Content Plan note field
-- Phase 17.5: thêm Ghi chú cho lịch air.
-- Safe to run trong Supabase SQL Editor sau content_plan_schema.sql.
-- ============================================================

begin;

alter table public.content_plan
  add column if not exists note text;

alter table public.content_plan drop constraint if exists content_plan_note_length_check;
alter table public.content_plan
  add constraint content_plan_note_length_check
  check (note is null or char_length(note) <= 2000);

comment on column public.content_plan.note is 'Ghi chú nội bộ cho dòng lịch air Content Plan.';

commit;
