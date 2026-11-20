// Gửi Web Push cho một thông báo vừa tạo. Chỉ trigger enqueue_web_push gọi hàm này
// (xem supabase/web_push_subscriptions.sql), xác thực bằng header x-push-secret.
// Secrets: PUSH_WEBHOOK_SECRET, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const pushSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") ?? "",
  Deno.env.get("VAPID_PUBLIC_KEY") ?? "",
  Deno.env.get("VAPID_PRIVATE_KEY") ?? "",
);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function sameSecret(given: string) {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(pushSecret);
  if (!b.length || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function clip(value: string, max: number) {
  return value.length > max ? `${value.slice(0, max - 1)}…` : value;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!sameSecret(req.headers.get("x-push-secret") ?? "")) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const notificationId = body?.notification_id;
  if (typeof notificationId !== "string" || !UUID_RE.test(notificationId)) {
    return json({ error: "invalid notification_id" }, 400);
  }

  const { data: notification, error } = await admin
    .from("notifications")
    .select("id, recipient_id, title, body, action_url")
    .eq("id", notificationId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!notification) return json({ error: "notification not found" }, 404);

  const { data: subscriptions, error: subError } = await admin
    .from("web_push_subscriptions")
    .select("id, endpoint, p256dh, auth")
    .eq("user_id", notification.recipient_id);
  if (subError) return json({ error: subError.message }, 500);

  // Payload Web Push tối đa ~4KB nên cắt bớt chữ.
  const payload = JSON.stringify({
    title: clip(notification.title, 120),
    body: clip(notification.body, 400),
    url: notification.action_url ?? "/notifications",
    tag: notification.id,
  });

  let sent = 0;
  const gone: string[] = [];
  await Promise.all((subscriptions ?? []).map(async (sub) => {
    try {
      await webpush.sendNotification(
        { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        payload,
        { TTL: 86_400, urgency: "high" },
      );
      sent += 1;
    } catch (err) {
      const status = (err as { statusCode?: number }).statusCode;
      // 404/410: trình duyệt đã huỷ đăng ký, xoá để lần sau không gửi nữa.
      if (status === 404 || status === 410) gone.push(sub.id);
      else console.error("web push failed", status, (err as Error).message);
    }
  }));

  if (gone.length) await admin.from("web_push_subscriptions").delete().in("id", gone);

  return json({ sent, removed: gone.length, total: subscriptions?.length ?? 0 });
});
