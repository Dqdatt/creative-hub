# manage-user Edge Function

Privileged admin operations for CreativeHub user management.

## Actions

- `update_email`: đổi email đăng nhập thật trong Supabase Auth và đồng bộ `public.profiles.email`.
- `delete_user`: xóa vĩnh viễn Auth user và dọn các quan hệ thử nghiệm liên quan.

## Required Secrets

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

The service role key is used only inside this Edge Function. Do not put it in Vite, Vercel, or any frontend `.env` file.

## Deploy

```bash
supabase functions deploy manage-user
```

## Example Requests

Update email:

```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/manage-user" \
  -H "Authorization: Bearer USER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"update_email","user_id":"USER_ID","email":"new@email.com"}'
```

Delete user:

```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/manage-user" \
  -H "Authorization: Bearer USER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"delete_user","user_id":"USER_ID"}'
```

## Security Notes

- The function validates the caller from the bearer token.
- The caller must have `public.profiles.role = admin` and an active profile.
- The frontend never calls Supabase Auth Admin APIs directly.
- The frontend never receives or stores the service role key.
- All input is validated server-side.

## Deletion Behavior

Before deleting the Auth user, the function cleans test-data relations:

- Removes avatar files from the known CreativeHub path `avatars/<user_id>/`.
- Empty avatar folders, missing avatar files, or a missing `avatars` bucket do not block account deletion.
- Deletes `public.shoot_editors` rows for the profile.
- Clears `video_tasks.editor_id`, `video_tasks.created_by`, `video_tasks.updated_by`.
- Clears `shoots.created_by`, `shoots.updated_by`.
- Clears `content_plan.editor_id`, `content_plan.created_by`, `content_plan.updated_by`.
- Clears `activity_logs.actor_id`.
- Prevents deleting the currently logged-in admin.
- Prevents deleting the last active admin account.

If Auth deletion fails, the function returns an error and does not claim success.
