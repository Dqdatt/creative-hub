# send-push Edge Function

Gửi Web Push tới mọi thiết bị của người nhận mỗi khi có dòng mới trong `public.notifications`.
Trigger `enqueue_web_push` (file `supabase/web_push_subscriptions.sql`) gọi hàm qua pg_net, chỉ gửi `notification_id` kèm header `x-push-secret`.

## Cài đặt (một lần)

1. Tạo khoá VAPID (P-256) và một chuỗi ngẫu nhiên làm `PUSH_WEBHOOK_SECRET`. Khoá công khai phải trùng với `VAPID_PUBLIC_KEY` trong `src/pwa/push.ts`.
2. Đặt secrets cho function:

```bash
supabase secrets set VAPID_PUBLIC_KEY=... VAPID_PRIVATE_KEY=... VAPID_SUBJECT=https://<domain-app> PUSH_WEBHOOK_SECRET=...
```

3. Deploy:

```bash
supabase functions deploy send-push --no-verify-jwt
```

4. Chạy `supabase/web_push_subscriptions.sql`, rồi tạo 2 secret Vault (`project_url`, `push_webhook_secret`) như ghi chú đầu file SQL.

## Lưu ý

- Đổi khoá VAPID thì mọi thiết bị phải bật lại thông báo đẩy.
- iPhone chỉ nhận push khi app đã được thêm vào Màn hình chính (iOS 16.4+).
- Endpoint trả 404/410 (thiết bị đã huỷ) sẽ tự bị xoá khỏi `web_push_subscriptions`.
