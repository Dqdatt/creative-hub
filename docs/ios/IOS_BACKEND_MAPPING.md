# CreativeHub iOS Backend Mapping

Date: 2026-08-14

This document maps the future native iOS app to the existing working webapp and Supabase backend. UI decisions must come from the approved HTML prototype; data, fields, permissions, and business behavior must come from the webapp and Supabase files listed here.

## Backend Sources Inspected

- Supabase client: `src/lib/supabase.ts`
- Auth and permissions: `src/context/AuthContext.tsx`, `src/config/permissions.ts`
- Dashboard: `src/services/dashboardService.ts`
- Video tasks: `src/services/tasksService.ts`, `src/types/task.ts`
- Calendar/shoots: `src/services/shootsService.ts`, `src/types/shoot.ts`
- Content Plan: `src/services/contentPlanService.ts`, `src/types/contentPlan.ts`
- Members: `src/services/userManagementService.ts`, `src/types/userManagement.ts`
- Profile/avatar/password: `src/services/profileService.ts`, `src/types/profile.ts`
- Notifications: `src/services/notificationsService.ts`, `src/types/notification.ts`
- Activity logs: `src/services/activityLogService.ts`, `src/types/activityLog.ts`
- Schema/RLS/RPCs: `supabase/setup.sql`, `supabase/content_plan_schema.sql`, `supabase/editor_membership_patch.sql`, `supabase/internal_notifications_foundation.sql`, notification and linked-task RPC patch files
- Edge Functions: `supabase/functions/create-user/index.ts`, `supabase/functions/manage-user/index.ts`

## Global App Infrastructure

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Supabase config | `src/lib/supabase.ts` | Supabase URL + anon/publishable key from env | Public anon key only; never service role in iOS | `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` |
| Session restore/check | `AuthProvider` listens to `auth.onAuthStateChange` | Supabase Auth | Authenticated session; refresh token handled by SDK | session, user, access token |
| Login | `signIn` in `AuthContext.tsx` | `auth.signInWithPassword` | Valid Supabase Auth user | email, password |
| Logout | `signOut` in `AuthContext.tsx` | `auth.signOut` | Authenticated user | session state cleared |
| Current profile load | `loadProfileForUser` in `AuthContext.tsx` | `profiles`; optional `user_permission_overrides` | Authenticated; active profile required | `id`, `email`, `full_name`, `display_name`, `short_name`, `role`, `avatar_url`, `department`, `active`, `is_active` |
| Role normalization | `src/config/permissions.ts` | `profiles.role`; `user_permission_overrides` | Client mirrors backend RLS but must not bypass it | roles: `admin`, `creative_manager`, `content_creator`, `editor`; legacy `team_lead` maps to `creative_manager` |

## Permissions

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Effective permissions | `getEffectivePermissions` | `user_permission_overrides`; SQL functions `has_effective_permission`, `can_edit_*`, `can_manage_*` | Role default, `view_only`, or custom flags | `access_mode`, `dashboard_view`, `calendar_view`, `calendar_edit`, `tasks_view`, `tasks_edit`, `content_plan_view`, `content_plan_edit_content`, `content_plan_assign_editor`, `users_manage`, `profile_edit_self` |
| Navigation visibility | `getVisibleNavigationForPermissions` | Same as above | Route-specific view permission | dashboard, calendar, tasks, content plan, users |
| Mutation controls | Feature pages use `can(...)` | RLS policies plus Edge Function auth | Hide/disable based on client permissions; backend remains authoritative | create/update/delete permissions per feature |

## Dashboard / Overview

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Monthly overview | `fetchDashboardData` | Reads `video_tasks`, `shoots`, `profiles` via feature services | `dashboard:view`; underlying table RLS | tasks filtered by effective air date; shoots by date range; editor options |
| Completion metrics | Web aggregation over `VideoTask[]` | `video_tasks` | `dashboard:view` and `video_tasks:view` where data is loaded | `status`, `air_date`, linked `content_plan.air_date` |
| Shoot load metric | `fetchShoots(startDate,endDate)` | `shoots`, `shoot_editors`, `profiles` | `shoots:view` | `shoot_date`, `shoot_type`, `crew`, `time_slot`, `location`, `content_note`, `shoot_note` |
| Editor workload | `fetchContentPlanEditorOptions` + tasks/shoots | `profiles`, `video_tasks`, `shoot_editors` | Authenticated read, active editor membership | `editor_code`, `is_editor_member`, `avatar_url`, `ui_color` |

## Video Tasks

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| List/search/filter video cards | `fetchVideoTasks(monthValue)` | `video_tasks` joined to `profiles` and `content_plan` | `video_tasks:view` | `id`, `stt`, `title`, `resize_reqs`, `editor_id`, `order_team`, `category`, `receive_date`, `return_date`, `air_date`, `status`, `priority`, `result_link`, `notes`, `content_plan_id` |
| Task detail/deep link | `fetchVideoTaskById` | `video_tasks` joined to `profiles`, `content_plan` | `video_tasks:view` | same as list |
| Create manual task | `createVideoTask` | Direct insert into `video_tasks`; activity log insert | `video_tasks:create`; RLS enforces | payload above plus `created_by`, `updated_by` |
| Update manual task | `updateVideoTask` | Direct update to `video_tasks`; activity log insert | `video_tasks:update`; linked-field locks apply | same payload plus linked-task restrictions |
| Delete task | `deleteVideoTask` | RPC `delete_video_task_with_notifications`; fallback direct delete if RPC missing | `video_tasks:delete`; RLS/RPC enforces | `p_video_task_id` |
| Accept linked task | `acceptLinkedVideoTask` | RPC `accept_linked_video_task` | Assigned editor/allowed role per RPC | `p_video_task_id`, `p_receive_date`, `p_return_date` |
| Update linked execution | `updateLinkedVideoTaskExecution` | RPC `update_linked_video_task_execution` | Assigned editor/allowed role per RPC | `p_order_team`, `p_priority`, `p_resize_reqs`, `p_receive_date`, `p_return_date`, `p_result_link` |
| Complete linked task | `completeLinkedVideoTask` | RPC `complete_linked_video_task` | Assigned editor/allowed role per RPC | `p_video_task_id`, `p_result_link` |
| Editor lookup | `resolveEditorProfileId` | `profiles` | Authenticated read | `id`, `editor_code`, `is_editor_member`, `is_active` |

Status values: `Chờ`, `Đang làm`, `Đã xong`. Task categories: `Video dài`, `Motion`, `Ads`. Priority values: empty string or `Gấp`.

## Calendar / Shoots

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Agenda list | `fetchShoots(startDate,endDate)` | `shoots` joined to `shoot_editors` and `profiles` | `shoots:view` | `id`, `shoot_date`, `shoot_type`, `crew`, `time_slot`, `location`, `content_note`, `shoot_note` |
| Shoot detail | `fetchShootById` | Same query filtered by `shoots.id` | `shoots:view` | same as list |
| Create schedule | `createShoot` | RPC `create_shoot_with_notifications`, then direct `shoots.shoot_note` update | `shoots:create`; RPC/RLS enforce | `p_shoot_date`, `p_shoot_type`, `p_crew`, `p_time_slot`, `p_location`, `p_content_note`, `p_editor_codes`; `shoot_note` |
| Update schedule | `updateShoot` | RPC `update_shoot_with_notifications`, then direct `shoots.shoot_note` update | `shoots:update`; RPC/RLS enforce | `p_shoot_id` plus create fields |
| Delete schedule | `deleteShoot` | RPC `delete_shoot_with_notifications` | `shoots:delete`; RPC/RLS enforce | `p_shoot_id` |

Shoot type values: `livestream`, `lichquay`, `onset`, `other`.

## Content Plan

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Timeline list/search/filter | `fetchContentPlan(monthValue)` | `content_plan` joined to `profiles` and `video_tasks` | `content_plan:view` | `id`, `air_date`, `title`, `note`, `category`, `editor_id`, `link` |
| Content detail | `fetchContentPlanItemById` | Same query filtered by `content_plan.id` | `content_plan:view` | same as list |
| Editor options | `fetchContentPlanEditorOptions` | `profiles` | Authenticated read, active editor membership | `id`, `editor_code`, `short_name`, `display_name`, `full_name`, `ui_color`, `avatar_url`, `role`, `active`, `is_active`, `is_editor_member` |
| Create content row | `createContentPlanRow` | RPC `create_content_plan_with_notifications` | `content_plan:create`; RPC/RLS enforce | `p_air_date`, `p_title`, `p_note`, `p_category`, `p_link` |
| Update content row | `updateContentPlanRow` | Direct update to `content_plan`; activity log insert | `content_plan:update`; linked task fields guarded | `air_date`, `title`, `note`, `category`, `link`, `updated_by` |
| Assign editor | `assignEditorToContentPlan` | RPC `assign_content_plan_editor` | `content_plan:assign`; RPC/RLS enforce | `p_content_plan_id`, `p_editor_id` |
| Delete content row | `deleteContentPlanRow` | RPC `delete_content_plan_with_notifications` | `content_plan:delete`; RPC/RLS enforce | `p_content_plan_id` |

Content Plan category values: `Video dài`, `Short/Reels`, `Livestream`, `Ảnh`, `Motion`, `Ads`.

## Members

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Member cards/list | `fetchUserProfiles` | `profiles`; `user_permission_overrides` | `user_management:view`; RLS enforces | `id`, `email`, `full_name`, `display_name`, `short_name`, `phone`, `role`, `department`, `avatar_url`, `editor_code`, `crew_key`, `is_editor_member`, `active`, `is_active`, `created_at`, `updated_at` |
| Update member | `updateManagedUserProfile` | Direct update `profiles`; optional Edge Function `manage-user` action `update_email`; upsert/delete `user_permission_overrides`; activity log | `user_management:update`; admin rules for Edge Function | profile fields plus permission override fields |
| Create member | `createManagedUser` | Edge Function `create-user`; optional `user_permission_overrides`; activity log | `user_management:create`; Edge Function validates caller | email, password, full/display name, phone, role, department, editor code, team editor flag, crew key |
| Delete member | `deleteManagedUserAccount` | Edge Function `manage-user` action `delete_user` | Admin/authorized caller per function | `user_id` |
| Reset member password | `resetManagedUserPassword` | Edge Function `manage-user` action `reset_password` | Admin/authorized caller per function | `user_id`, password |

Important: service-role credentials live only in Supabase Edge Function secrets. The native app must call Edge Functions with the signed-in user's access token, same as the webapp.

## Profile / Account Settings

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Load personal profile | `fetchProfile(user)` | `profiles` | Authenticated user; self profile | `id`, `email`, `full_name`, `display_name`, `short_name`, `phone`, `role`, `department`, `avatar_url` |
| Edit personal profile | `updateProfile` | Direct update `profiles` filtered by current user id | `profile:edit_self`; RLS enforces | `full_name`, `display_name`, `short_name`, `phone`, `department`, optional `avatar_url` |
| Upload avatar | `uploadAvatar` | Storage bucket `avatars`, then `profiles.avatar_url` via `updateProfile` | Storage bucket policy plus `profile:edit_self` | path `<userId>/<timestamp>-<cleanFileName>`, public URL |
| Change password | `updatePassword` | `auth.signInWithPassword` to verify current password, then `auth.updateUser` | Authenticated user and current password | email, current password, new password |
| Notification preference | No backend preference found in inspected files | Pending Phase 10 implementation decision | Do not create backend storage without approval | Existing notification read state is separate |
| Language/theme preference | No backend preference found in inspected files | Local preference plumbing only unless approved later | No schema change in Phase 0 | Values from prototype: language `Tiếng Việt`/`English`; theme `Sáng`/`Tối`/`Theo hệ thống` |

## Notifications

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Recent notifications | `getRecentNotifications` | `notifications` | RLS: recipient only | `id`, `recipient_id`, `actor_id`, `type`, `title`, `body`, `entity_type`, `entity_id`, `action_url`, `metadata`, `event_key`, `read_at`, `created_at` |
| Unread count | `getUnreadNotificationCount` | `notifications` head count where `read_at` is null | RLS: recipient only | `read_at` |
| Mark one read | `markNotificationRead` | RPC `mark_notification_read` | Owned recipient | `p_notification_id` |
| Mark all read | `markAllNotificationsRead` | RPC `mark_all_notifications_read` | Owned recipient | none |
| Delete one | `deleteNotification` | RPC `delete_notification` | Owned recipient | `p_notification_id` |
| Delete old | `deleteNotificationsOlderThan` | RPC `delete_notifications_older_than` | Owned recipient | `p_days` |
| Realtime updates | `subscribeToNotifications` | Realtime channel on `public.notifications` filtered by `recipient_id` | Signed-in profile id | INSERT/UPDATE/DELETE payloads |

Notification entity types: `shoot`, `content_plan`, `video_task`.

## Activity Logs

| Native feature | Webapp implementation | Supabase table/RPC/function | Permission requirement | Relevant fields |
| --- | --- | --- | --- | --- |
| Log mutations | `logActivity` | Insert into `activity_logs` | Authenticated insert policy | `actor_id`, `entity_type`, `entity_id`, `action`, `title`, `description`, `metadata` |
| Recent activity | `fetchRecentActivityLogs` | `activity_logs` joined to `profiles` | Authenticated read policy | `id`, `actor_id`, `entity_type`, `entity_id`, `action`, `title`, `description`, `metadata`, `created_at` |

## Supabase Tables Identified

- `profiles`
- `user_permission_overrides`
- `video_tasks`
- `shoots`
- `shoot_editors`
- `content_plan`
- `notifications`
- `activity_logs`
- Storage bucket: `avatars`

## RPCs / Edge Functions The Native App Should Reuse

RPCs:

- `create_shoot_with_notifications`
- `update_shoot_with_notifications`
- `delete_shoot_with_notifications`
- `create_content_plan_with_notifications`
- `assign_content_plan_editor`
- `delete_content_plan_with_notifications`
- `delete_video_task_with_notifications`
- `accept_linked_video_task`
- `update_linked_video_task_execution`
- `complete_linked_video_task`
- `mark_notification_read`
- `mark_all_notifications_read`
- `delete_notification`
- `delete_notifications_older_than`

Edge Functions:

- `create-user`
- `manage-user`

## Backend Blockers / Decisions For Later Phases

- Notification preference toggle: no persisted user preference was found. Implement local preference/state plumbing only unless the user approves a backend field.
- Theme preference: no approved dark-mode design exists in the prototype. Implement preference plumbing only until a dark UI is approved.
- Language persistence: no backend preference field was found. Use local persistence unless the user approves schema support.
- The native app must not add migrations or new Supabase storage design without explicit approval.
