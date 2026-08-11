# Phase 4 Production Hardening Report

Generated: 2026-08-09 Asia/Ho_Chi_Minh

Scope: native iOS project `ios/CreativeHubOps/CreativeHubOps.xcodeproj`. This phase hardened the current SwiftUI app without redesigning UI or adding new business features.

## Changes

| Area | Result | Verification | Remaining Risk |
| --- | --- | --- | --- |
| Session, account switching, lifecycle, realtime reconnect | Added session/load generation guards so stale loads and stale account-session mutations cannot write back after account switch/logout. Root-level account change already clears Operations, Admin Users, Notifications, and stops/restarts notification realtime. | Unit tests: `testOperationsAccountSwitchClearsSessionScopedState`, `testOperationsIgnoresStaleMonthLoadResult`, `testAdminUsersAccountSwitchClearsSessionScopedState`. Full `xcodebuild test` passed. | Needs manual real-login test with two real accounts on device to confirm Keychain/session transition behavior against live Supabase. |
| Network errors, mutation recovery, double submit | Added mutation locks for Operations/Admin flows and load dedupe for Admin Users/Notifications. Retry paths use forced reload where needed. Avatar processing remains off the MainActor. | Unit tests: `testOperationsRejectsSecondMutationWhileFirstIsRunning`, `testAdminUsersLoadSkipsCachedDataUnlessForced`, `testNotificationsLoadSkipsCachedDataUnlessForced`. | Backend mutation failure recovery is covered structurally, but should still be manually exercised with real credentials and intermittent network. |
| Performance, concurrency, caching | Month loads capture immutable month ranges and ignore stale results. Admin/Notifications avoid redundant fetches after cached content is present. Calendar missing value display was standardized to `—`. | Unit tests: leap/year month range, stale month load, load dedupe. Code scan found no N+1 client loops in month data reads. | Large production datasets may still need backend-side pagination/filtered RPCs for `video_tasks`, which is currently filtered client-side after one table fetch. |
| Security, RLS, config, Release build | No service-role/JWT secret found in native app source/config. Only runtime user access token is passed to admin Edge Functions. Supabase URL/anon key resolve in build settings. Edge Functions are reachable and require auth at least at JWT boundary. | `rg` secret/debug scan; `xcodebuild -showBuildSettings`; non-destructive curl checks; Release simulator build passed; Release generic iOS arm64 build passed with signing disabled. | Full admin authorization cannot be proven without admin/non-admin test accounts or Supabase function source/log access. Bundle ID remains `com.example.CreativeHubOps`, so TestFlight/App Store signing is not ready as-is. |
| Accessibility, real-device readiness, final regression | Added labels for calendar month arrow buttons. App is portrait-only on iPhone via `Info.plist`; iPad supports portrait/upside-down. Simulator UI smoke tests pass. Generic device arm64 compile passes. | UI tests: launch, notifications surface, shoot detail, create task sheet. `xcrun xctrace list devices` found no connected iPhone/iPad, only Mac + simulators. | Real-device QA is still pending because no physical iOS device was connected. Dynamic Type/VoiceOver pass should be done on device. |

## Build And Test Report

- Debug simulator full suite:
  - Command: `xcodebuild test -project ios/CreativeHubOps/CreativeHubOps.xcodeproj -scheme CreativeHubOps -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
  - Result: `TEST SUCCEEDED`
  - Coverage: 36 unit tests + 4 UI tests = 40 total.
  - Note: xcodebuild printed a non-fatal simulator runner launch warning after the suite had passed.
- Release simulator:
  - Command: `xcodebuild -project ios/CreativeHubOps/CreativeHubOps.xcodeproj -scheme CreativeHubOps -configuration Release -destination 'generic/platform=iOS Simulator' build`
  - Result: `BUILD SUCCEEDED`
- Release generic iOS arm64:
  - Command: `xcodebuild -project ios/CreativeHubOps/CreativeHubOps.xcodeproj -scheme CreativeHubOps -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
  - Result: `BUILD SUCCEEDED`

## Backend And Security Report

Supabase project checked: `https://qyybwwyoicsnvfbqqkaq.supabase.co`. The environment could not be classified as staging/dev, so all checks were read-only or intentionally non-destructive.

Edge Function reachability/auth:

| Function | Check | Result |
| --- | --- | --- |
| `create-user` | `OPTIONS` | 204 |
| `create-user` | POST without auth | 401 |
| `create-user` | POST invalid auth | 401 |
| `create-user` | POST anon auth | 401 |
| `manage-user` | `OPTIONS` | 204 |
| `manage-user` | POST without auth | 401 |
| `manage-user` | POST invalid auth | 401 |
| `manage-user` | POST anon auth with fake reset payload | 400 with structured error keys |

RLS/read exposure check with publishable anon key:

| Resource | Result |
| --- | --- |
| `profiles` | 200, empty array |
| `video_tasks` | 200, empty array |
| `shoots` | 200, empty array |
| `shoot_editors` | 200, empty array |
| `content_plan` | 200, empty array |
| `notifications` | 401 |
| `user_permission_overrides` | 200, empty array |
| Storage bucket list | 200, empty array |

Interpretation: unauthenticated/anon reads did not expose rows in these checks. This does not prove per-user RLS correctness for authenticated roles.

## Recommendation

NOT READY FOR PHASE 5.

Reason: the native app now builds and passes simulator QA, but Phase 5/TestFlight should wait for real-device testing, real account role-matrix verification, confirmed App Store bundle identifier/signing/provisioning, and authenticated RLS/admin Edge Function verification.
