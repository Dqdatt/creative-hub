-- ============================================================
-- CreativeHub - Video Task taxonomy cleanup
-- Removes Pending/Ads from active UI values and adds Hoãn.
-- Run this after the linked task/content plan patches.
-- ============================================================

begin;

select set_config('app.content_plan_assignment', 'on', true);
select set_config('app.linked_video_task_acceptance', 'on', true);
select set_config('app.linked_video_task_execution_update', 'on', true);
select set_config('app.linked_video_task_completion', 'on', true);

alter table public.video_tasks drop constraint if exists video_tasks_status_check;
alter table public.video_tasks drop constraint if exists video_tasks_category_check;
alter table public.video_tasks drop constraint if exists video_tasks_order_team_check;
alter table public.content_plan drop constraint if exists content_plan_category_check;

create or replace function public.normalize_video_task_taxonomy_labels()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'Pending' or new.status = 'pending' then
    new.status := 'Chờ';
  elsif new.status = 'in_progress' then
    new.status := 'Đang làm';
  elsif new.status = 'done' then
    new.status := 'Đã xong';
  end if;

  if new.category = 'Ads' then
    new.category := 'Motion';
  end if;

  if new.order_team = 'DIGITAL' then
    new.order_team := 'DIGITAL - ADS';
  end if;

  return new;
end;
$$;

drop trigger if exists video_tasks_linked_pending_normalize on public.video_tasks;
drop trigger if exists video_tasks_status_label_normalize on public.video_tasks;
drop trigger if exists video_tasks_taxonomy_label_normalize on public.video_tasks;
create trigger video_tasks_taxonomy_label_normalize
before insert or update of status, category, order_team on public.video_tasks
for each row execute function public.normalize_video_task_taxonomy_labels();

drop function if exists public.normalize_new_linked_video_task_pending();
drop function if exists public.normalize_video_task_status_labels();

update public.video_tasks
set status = case
  when status = 'Pending' then 'Chờ'
  when status = 'pending' then 'Chờ'
  when status = 'in_progress' then 'Đang làm'
  when status = 'done' then 'Đã xong'
  when status in ('Chờ', 'Đang làm', 'Đã xong', 'Hoãn') then status
  else 'Chờ'
end
where status is null
   or status not in ('Chờ', 'Đang làm', 'Đã xong', 'Hoãn')
   or status = 'Pending';

update public.video_tasks
set category = 'Motion'
where category = 'Ads';

update public.content_plan
set category = 'Motion'
where category = 'Ads';

update public.video_tasks
set order_team = 'DIGITAL - ADS'
where order_team = 'DIGITAL';

alter table public.video_tasks
  add constraint video_tasks_status_check
  check (status in ('Chờ', 'Đang làm', 'Đã xong', 'Hoãn'));

alter table public.video_tasks
  add constraint video_tasks_category_check
  check (category is null or category in ('Video dài', 'Motion'));

alter table public.video_tasks
  add constraint video_tasks_order_team_check
  check (order_team is null or order_team in ('BRAND', 'DIGITAL - ADS', 'ECOM', 'HR', 'ISD', 'IT', 'CS', 'GT', 'PUR'));

alter table public.content_plan
  add constraint content_plan_category_check
  check (category is null or category in ('Video dài', 'Short/Reels', 'Livestream', 'Ảnh', 'Motion'));

comment on column public.video_tasks.status is 'Trạng thái UI tiếng Việt: Chờ, Đang làm, Đã xong, Hoãn.';
comment on column public.video_tasks.category is 'Thể loại video: Video dài hoặc Motion.';
comment on column public.video_tasks.order_team is 'Team order, dùng DIGITAL - ADS cho nhóm digital/ads.';
comment on column public.content_plan.category is 'Thể loại nội dung: Video dài, Short/Reels, Livestream, Ảnh, Motion.';

commit;
