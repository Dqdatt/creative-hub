-- ============================================================
-- CreativeHub - Web Push cho PWA (iOS 16.4+, Android, desktop).
-- Chạy sau internal_notifications_foundation.sql.
--
-- Luồng: insert vào public.notifications -> trigger xếp 1 request pg_net
-- -> Edge Function send-push (kiểm x-push-secret, tự đọc thông báo theo id)
-- -> gửi Web Push tới mọi thiết bị của người nhận.
--
-- Cài một lần sau khi chạy file này (SQL Editor):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<PUSH_WEBHOOK_SECRET>', 'push_webhook_secret');
-- Chưa có 2 secret này thì trigger bỏ qua, thông báo trong app vẫn chạy bình thường.
-- ============================================================

begin;

create extension if not exists pg_net with schema extensions;

create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  last_seen_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists web_push_subscriptions_user_idx
  on public.web_push_subscriptions (user_id);

-- Không policy nào: client chỉ đi qua 2 RPC bên dưới, Edge Function dùng service role.
alter table public.web_push_subscriptions enable row level security;
revoke all on public.web_push_subscriptions from anon, authenticated;

create or replace function public.register_web_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_endpoint text := btrim(coalesce(p_endpoint, ''));
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  -- Chỉ nhận endpoint của dịch vụ push thật: Edge Function sẽ POST tới URL này (chặn SSRF).
  if length(v_endpoint) > 1000
    or v_endpoint !~ '^https://(fcm\.googleapis\.com|android\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)/[^[:space:]]+$' then
    raise exception 'invalid push endpoint';
  end if;

  if coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{86,88}=*$' then
    raise exception 'invalid push key';
  end if;

  if coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{21,24}=*$' then
    raise exception 'invalid push auth';
  end if;

  -- Cùng endpoint đăng nhập user khác thì chuyển thiết bị sang user hiện tại.
  insert into public.web_push_subscriptions (user_id, endpoint, p256dh, auth, user_agent)
  values (v_user_id, v_endpoint, p_p256dh, p_auth, left(p_user_agent, 300))
  on conflict (endpoint) do update set
    user_id = excluded.user_id,
    p256dh = excluded.p256dh,
    auth = excluded.auth,
    user_agent = excluded.user_agent,
    last_seen_at = timezone('utc'::text, now());
end;
$$;

create or replace function public.delete_web_push_subscription(p_endpoint text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  delete from public.web_push_subscriptions
  where endpoint = btrim(coalesce(p_endpoint, ''))
    and user_id = auth.uid();
end;
$$;

create or replace function public.enqueue_web_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  if not exists (select 1 from public.web_push_subscriptions where user_id = new.recipient_id) then
    return new;
  end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_secret is null then
    return new;
  end if;

  -- Chỉ gửi id; Edge Function tự đọc nội dung bằng service role.
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/send-push',
    body := jsonb_build_object('notification_id', new.id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret)
  );
  return new;
exception when others then
  -- Push là phụ: lỗi ở đây không được làm hỏng việc tạo thông báo.
  raise warning 'enqueue_web_push failed: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_enqueue_web_push on public.notifications;
create trigger notifications_enqueue_web_push
after insert on public.notifications
for each row execute function public.enqueue_web_push();

revoke all on function public.register_web_push_subscription(text, text, text, text) from public, anon;
revoke all on function public.delete_web_push_subscription(text) from public, anon;
revoke all on function public.enqueue_web_push() from public, anon, authenticated;
grant execute on function public.register_web_push_subscription(text, text, text, text) to authenticated;
grant execute on function public.delete_web_push_subscription(text) to authenticated;

commit;
