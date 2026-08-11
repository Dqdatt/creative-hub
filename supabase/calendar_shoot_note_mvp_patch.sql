-- ============================================================
-- CreativeHub - Calendar MVP content/note split
-- Adds a separate optional note while keeping content_note as Nội dung.
-- Safe to run after calendar_notification_events.sql.
-- ============================================================

begin;

alter table public.shoots
  add column if not exists shoot_note text;

alter table public.shoots drop constraint if exists shoots_content_note_required_check;
alter table public.shoots
  add constraint shoots_content_note_required_check
  check (content_note is null or length(btrim(content_note)) > 0);

alter table public.shoots drop constraint if exists shoots_shoot_note_length_check;
alter table public.shoots
  add constraint shoots_shoot_note_length_check
  check (shoot_note is null or char_length(shoot_note) <= 2000);

comment on column public.shoots.content_note is 'Nội dung lịch quay hiển thị trên calendar.';
comment on column public.shoots.shoot_note is 'Ghi chú nội bộ tùy chọn cho lịch quay.';

commit;
