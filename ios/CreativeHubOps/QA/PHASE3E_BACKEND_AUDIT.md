# Phase 3E Backend, Realtime & Privileged Flow Audit

Date: 2026-08-09 Asia/Ho_Chi_Minh

Scope: Native iOS backend parity completion for linked task lifecycle, avatar Supabase Storage, notification realtime, and admin privileged flows. No Supabase schema, RLS, RPC, storage policy, or Edge Function source was modified.

## Feature Matrix

| Feature | UI | Supabase | Server Logic | Permission | Tests |
| --- | --- | --- | --- | --- | --- |
| Linked Task accept | ✅ Native sheet from Task Detail | ✅ RPC `accept_linked_video_task` | ✅ Existing SECURITY DEFINER RPC | ✅ Assigned editor + `video_tasks:update` gate | ✅ Unit + build |
| Linked Task execution update | ✅ Native sheet from Task Detail | ✅ RPC `update_linked_video_task_execution` | ✅ Existing SECURITY DEFINER RPC | ✅ Assigned editor + `video_tasks:update` gate | ✅ Unit + build |
| Linked Task complete | ✅ Native sheet from Task Detail | ✅ RPC `complete_linked_video_task` after execution update | ✅ Existing SECURITY DEFINER RPC syncs Content Plan link | ✅ Assigned editor + `video_tasks:update` gate | ✅ Unit + build |
| Avatar upload | ✅ Profile photo picker | ✅ Storage bucket `avatars`; profile `avatar_url` update | ✅ Existing Storage/RLS policies expected | ✅ `profile:edit_self` + logged-in session | ✅ Unit + build |
| Notification realtime | ✅ Existing notification surface auto-merges events | ✅ Realtime channel `notifications-{profileId}` on `notifications` | ✅ Existing Postgres Changes publication expected | ✅ Filtered by `recipient_id` + session RLS | ✅ Unit + UI |
| Admin user list | ✅ Users list/detail | ✅ `profiles`, optional `user_permission_overrides` | ✅ Existing RLS | ✅ `user_management:*` gate | ✅ Unit + UI |
| Admin create user | ✅ Create sheet | ✅ Edge Function `create-user` + optional override upsert | ✅ Existing Edge Function uses service role server-side | ✅ Bearer token; admin checked server-side | ✅ Unit + build |
| Admin update user/email/permissions | ✅ Edit sheet | ✅ `profiles`, `user_permission_overrides`, Edge Function `manage-user` for email | ✅ Existing Edge Function for Auth email | ✅ Bearer token; admin checked server-side | ✅ Unit + build |
| Admin reset password | ✅ Reset password sheet | ✅ Edge Function `manage-user` | ✅ Existing Edge Function | ✅ Bearer token; admin checked server-side | ✅ Build |
| Admin delete user | ✅ Detail menu + confirmation | ✅ Edge Function `manage-user` | ✅ Existing Edge Function prevents self/last-admin delete | ✅ Bearer token; admin checked server-side | ✅ Build |

## Backend Inventory Used

Tables:

- `profiles`
- `user_permission_overrides`
- `video_tasks`
- `content_plan`
- `notifications`
- Existing read paths still use `shoots` and `shoot_editors`.

RPCs:

- `accept_linked_video_task`
- `update_linked_video_task_execution`
- `complete_linked_video_task`
- Existing Phase 3B/3D RPCs remain in use:
  - `delete_video_task_with_notifications`
  - `create_shoot_with_notifications`
  - `update_shoot_with_notifications`
  - `delete_shoot_with_notifications`
  - `create_content_plan_with_notifications`
  - `assign_content_plan_editor`
  - `delete_content_plan_with_notifications`
  - notification mark-read RPCs from `NotificationsRepository`

Edge Functions:

- `create-user`
- `manage-user`

Storage:

- Bucket `avatars`
- Native upload path: `<user_id>/<timestamp>-<clean-file-name>`
- Native upload format: processed JPEG, max source 10 MB, max dimension 1024 px, `cacheControl = 3600`, `upsert = true`

Realtime:

- Channel: `notifications-{profileId}`
- Table: `public.notifications`
- Events: insert, update, delete
- Filter: `recipient_id = current profile id`
- Client behavior: dedupe by `id`, update unread count via computed state, remove deleted rows, stop subscription and clear notification state on logout/profile switch.

## Security Scan

Command scope: `ios/CreativeHubOps/CreativeHubOps` and `ios/CreativeHubOps/CreativeHubOpsTests`.

Findings:

- ✅ No `SUPABASE_SERVICE_ROLE_KEY` in native app code.
- ✅ No service role, JWT secret, database password, refresh token, or static admin token found.
- ✅ Edge Function calls use the current Supabase Auth access token at runtime only.
- ✅ Password fields are form values only; tests use a dummy validation password.
- ✅ No logging of password or access token was added.

## QA Screenshots

Existing Phase 3D screenshots remain under `ios/CreativeHubOps/QA/phase3d/`.

- `launch.png`
- `notifications.png`
- `shoot-detail.png`
- `create-task-sheet.png`

Live populated shoot-detail screenshot is still data-dependent. The current `shoot-detail.png` captures the pushed detail route/error-state from the available notification route; a populated live shoot screenshot should be recaptured after a non-deleted in-month shoot exists in the configured Supabase project.

## Verification

- Build: `xcodebuild build` succeeded on iPhone 16 Pro simulator.
- Tests: `xcodebuild test` succeeded on iPhone 16 Pro simulator.
- Latest test summary: 33 passed, 0 failed, 0 skipped.
