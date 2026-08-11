# Phase 4 Baseline

Date: 2026-08-09 Asia/Ho_Chi_Minh

## Current Build Status

- Last recorded Debug build: passed on iPhone 16 Pro simulator.
- Last recorded test run: passed.
- Baseline test count: 33 passed, 0 failed, 0 skipped.
- UI primary and secondary surfaces are considered approved from Phase 3D/3E.

## Project Configuration

- Xcode project: `ios/CreativeHubOps/CreativeHubOps.xcodeproj`
- Deployment target: iOS 17.0
- Swift version: 6.0
- Simulator used in latest verification: iPhone 16 Pro, iOS 18.6
- Bundle identifier: configured through `BUNDLE_IDENTIFIER` xcconfig substitution.

## Supabase Configuration

- Supabase project configured: `https://qyybwwyoicsnvfbqqkaq.supabase.co`
- Client key type: publishable anon key in Xcode config.
- Environment classification: not identified in source as development/staging/production; treat as protected data.
- Destructive/live mutation tests must not run automatically against this project.

## Known Backend Dependencies

- Tables: `profiles`, `user_permission_overrides`, `video_tasks`, `shoots`, `shoot_editors`, `content_plan`, `notifications`
- RPCs: linked task lifecycle, shoot CRUD notifications, content plan CRUD/assign notifications, notification mark-read flows
- Edge Functions: `create-user`, `manage-user`
- Storage bucket: `avatars`
- Realtime: `public.notifications` filtered by `recipient_id`

## Known Remaining Limitations

- Real-device QA is pending until a physical iPhone and signing team are available.
- Populated live screenshots are data-dependent and should avoid credentials/sensitive content.
- Admin Edge Function privileged success paths require an existing admin test account; automated tests must not mutate protected data.
- Full role matrix/RLS verification needs safe role-specific accounts or a staging Supabase project.
- Optional realtime refresh for `video_tasks`, `shoots`, and `content_plan` is not implemented; notification realtime is implemented.
