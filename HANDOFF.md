# HANDOFF

## Mục tiêu phiên này
Sửa topbar PWA (vệt gradient dưới status bar, tốn 2 hàng) và làm Web Push cho PWA.

## Đã xong (v2.3.0, đã gộp `pwa-push` vào main và push)
- giao 005 (đã merge): `.m-shell` nền phẳng `--m-bg`, chọn tháng gộp lên hàng avatar (grid `1fr auto 1fr`). Claude chỉnh nút tháng 34px.
- giao 006 (đã merge): `public/sw.js` nhận `push` + `notificationclick`; `src/pwa/push.ts`; thẻ bật/tắt push ở trang Thông báo (mobile).
- Claude: `AuthContext.signOut` gọi `disablePush()` trước khi đăng xuất; `AppLayout` gọi `syncPushSubscription()` khi có profile.
- Server (Claude, ĐÃ DEPLOY lên project `qyybwwyoicsnvfbqqkaq`):
  - `supabase/web_push_subscriptions.sql`: bảng `web_push_subscriptions` (RLS, không grant client), RPC `register_/delete_web_push_subscription`, trigger `notifications_enqueue_web_push` → pg_net → `send-push`. Đã chạy.
  - `supabase/functions/send-push` (deploy `--no-verify-jwt`), secrets VAPID_* + PUSH_WEBHOOK_SECRET đã set; Vault có `project_url`, `push_webhook_secret`.
  - Đã thử: sai secret 401, id rác 400, id không có 404; đường pg_net + Vault → function chạy (404 với id giả).
- Khoá VAPID và secret nằm trong `.env.push.local` (gitignore). Khoá công khai đã hardcode trong `src/pwa/push.ts`.

## Chưa kiểm
- Chưa gửi push thật lần nào: `npm:web-push` trên Edge Runtime mới chứng minh boot được, chưa chứng minh mã hoá/gửi được. Kiểm bằng iPhone sau khi deploy Vercel; lỗi thì xem log function `send-push`.
- Thẻ push chưa thấy trên UI thật (dev không có SW; trình duyệt trong app chặn quyền thông báo).
- `VAPID_SUBJECT` tạm là URL Supabase; có domain Vercel thì `supabase secrets set VAPID_SUBJECT=https://<domain>`.

## Quyết định đã chốt
- Chỉ làm mobile/PWA (< 768px); desktop giữ nguyên. Modal dùng nền đặc.
- Không đổi status bar iOS sang `black-translucent`; vì vậy nền đỉnh app phải phẳng, trùng theme-color.
- Push gửi cho mọi dòng mới trong `notifications`. Endpoint chỉ nhận host push thật (chặn SSRF).
- Duyệt việc `giao`: tự đọc diff + chạy app thật trước `giao xong`.
- Mỗi commit nâng version ở 3 chỗ (package.json, footer AppLayout, `APP_VERSION` Account) – trừ commit chỉ đổi tài liệu.

## Nợ Ponytail
- Lỗi cũ: `.m-toolbar` margin -16px tràn `.calendar-page` (overflow hidden) 16px.
- Chưa có: badge số trên icon app, tắt push theo loại thông báo, nút push trên desktop.

## Việc tiếp theo
1. iPhone (sau khi Vercel deploy v2.3.0): mở PWA từ Màn hình chính → Thông báo → Bật thông báo đẩy → nhờ người khác giao task cho mình → kiểm push đến, bấm mở đúng trang.
2. Sửa tràn 16px `.m-toolbar` trong `.calendar-page` (giao qua `giao`).
