-- ============================================================
-- CreativeHub - Notification cleanup RPCs
-- Phase: compact Notification Center cleanup actions.
-- Safe to run after internal_notifications_foundation.sql.
-- ============================================================

begin;

create or replace function public.delete_notification(p_notification_id uuid)
returns table (
  notification_id uuid,
  was_unread boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa thông báo.' using errcode = '42501';
  end if;

  if p_notification_id is null then
    raise exception 'notification_id is required';
  end if;

  select n.id, n.read_at is null
  into notification_id, was_unread
  from public.notifications n
  where n.id = p_notification_id
    and n.recipient_id = v_actor_id;

  if notification_id is null then
    raise exception 'Không tìm thấy thông báo.' using errcode = '42501';
  end if;

  delete from public.notifications n
  where n.id = notification_id
    and n.recipient_id = v_actor_id;

  return next;
end;
$$;

create or replace function public.delete_notifications_older_than(p_days integer default 15)
returns table (
  deleted_count integer,
  unread_deleted_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_days integer;
  v_cutoff timestamptz;
begin
  v_actor_id := auth.uid();

  if v_actor_id is null then
    raise exception 'Bạn cần đăng nhập để xóa thông báo.' using errcode = '42501';
  end if;

  v_days := least(greatest(coalesce(p_days, 15), 1), 365);
  v_cutoff := timezone('utc'::text, now()) - make_interval(days => v_days);

  with deleted as (
    delete from public.notifications n
    where n.recipient_id = v_actor_id
      and n.created_at < v_cutoff
    returning n.read_at
  )
  select count(*)::integer,
         count(*) filter (where read_at is null)::integer
  into deleted_count,
       unread_deleted_count
  from deleted;

  return next;
end;
$$;

revoke execute on function public.delete_notification(uuid) from public;
revoke execute on function public.delete_notification(uuid) from anon;
grant execute on function public.delete_notification(uuid) to authenticated;

revoke execute on function public.delete_notifications_older_than(integer) from public;
revoke execute on function public.delete_notifications_older_than(integer) from anon;
grant execute on function public.delete_notifications_older_than(integer) to authenticated;

revoke insert, update, delete on public.notifications from anon, authenticated;

comment on function public.delete_notification(uuid) is
  'Deletes one notification owned by auth.uid(); does not grant generic table DELETE.';
comment on function public.delete_notifications_older_than(integer) is
  'Deletes notifications owned by auth.uid() where created_at is older than the clamped day cutoff.';

commit;
