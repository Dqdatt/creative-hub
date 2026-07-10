# create-user Edge Function

Tạo Supabase Auth user từ màn hình `/users` mà không đưa `SUPABASE_SERVICE_ROLE_KEY` vào frontend.

## Required Secrets

Supabase tự cung cấp:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Cần set thêm:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Chỉ đặt service role key trong Supabase secrets. Không đặt key này trong `.env` frontend.

## Deploy

```bash
supabase functions deploy create-user
```

Function có `config.toml` với `verify_jwt = false` để request `OPTIONS` preflight đi vào code CORS. Function vẫn tự kiểm tra bearer token và chỉ cho `admin` tạo user.

## Local Test

Chạy local:

```bash
supabase functions serve create-user --env-file .env
```

Gọi thử:

```bash
curl -i -X OPTIONS http://127.0.0.1:54321/functions/v1/create-user \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: authorization, x-client-info, apikey, content-type"
```

Kết quả đúng là HTTP `204` và có các header CORS.

Gọi POST cần bearer token của tài khoản admin:

```bash
curl -i -X POST http://127.0.0.1:54321/functions/v1/create-user \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "editor@example.com",
    "password": "temporary-password",
    "full_name": "Editor Demo",
    "display_name": "Editor Demo",
    "role": "editor",
    "department": "Team Marketing",
    "is_editor_member": true,
    "editor_code": "demo",
    "crew_key": "DEMO"
  }'
```

## Common Errors

- `Thiếu Authorization bearer token.`: frontend không gửi session token hoặc user chưa đăng nhập.
- `Bạn không có quyền tạo thành viên.`: user đang gọi function không có `profiles.role = admin`.
- `Thiếu cấu hình Supabase Edge Function.`: chưa set `SUPABASE_SERVICE_ROLE_KEY`.
- CORS preflight fail: redeploy function sau khi có `config.toml`, kiểm tra response `OPTIONS` trả `204` và có CORS headers.
- `Đã tạo Auth user nhưng chưa cập nhật được profile.`: kiểm tra đã chạy `supabase/user_management_patch.sql` và `supabase/editor_membership_patch.sql` chưa.
