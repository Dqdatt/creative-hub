### Completed
Implemented Phase 9 native `Thông báo` with a production Supabase-backed repository, unread bell indicator, secondary-route notification inbox, read/unread behavior, mark-one/mark-all flows, safe deep links into verified native modules, DEBUG-only fixtures, focused tests, and required screenshot QA.

### Files changed
- `ios/CreativeHub/CreativeHub/Features/Notifications/NotificationModels.swift`
- `ios/CreativeHub/CreativeHub/Features/Notifications/NotificationRepository.swift`
- `ios/CreativeHub/CreativeHub/Features/Notifications/NotificationFixtures.swift`
- `ios/CreativeHub/CreativeHub/Features/Notifications/NotificationViewModel.swift`
- `ios/CreativeHub/CreativeHub/Features/Notifications/NotificationView.swift`
- `ios/CreativeHub/CreativeHub/Core/Components/CHGlassTopBar.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppShellView.swift`
- `ios/CreativeHub/CreativeHub.xcodeproj/project.pbxproj`
- `ios/CreativeHub/CreativeHubTests/CreativeHubTests.swift`
- `ios/CreativeHub/CreativeHubUITests/CreativeHubUITests.swift`
- `ios/CreativeHub/QA/Snapshots/phase9-01-notifications-main.png`
- `ios/CreativeHub/QA/Snapshots/phase9-02-notifications-unread.png`
- `ios/CreativeHub/QA/Snapshots/phase9-03-notification-opened-read.png`
- `ios/CreativeHub/QA/Snapshots/phase9-04-notifications-mark-all-read.png`
- `ios/CreativeHub/QA/Snapshots/phase9-05-notification-deeplink.png`
- `ios/CreativeHub/QA/Snapshots/phase9-06-notification-destination-unavailable.png`
- `ios/CreativeHub/QA/Snapshots/phase9-07-notifications-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase9-08-notifications-load-error.png`
- `ios/CreativeHub/QA/Snapshots/phase9-09-notifications-bottom-scroll-safe.png`
- `ios/CreativeHub/QA/Snapshots/phase9-10-bell-unread-indicator.png`
- `ios/CreativeHub/QA/Snapshots/phase9-11-bell-zero-unread.png`
- `docs/ios/PHASE9_NOTIFICATIONS.md`

### Source verification
- Phase 9 package inspected: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE9_NOTIFICATIONS_PACKAGE/PHASE9_NOTIFICATIONS_PROMPT.md` and `PHASE9_NOTIFICATIONS_README.md`.
- Existing backend mapping inspected: `docs/ios/IOS_BACKEND_MAPPING.md`.
- Web notification files inspected: `src/services/notificationsService.ts`, `src/types/notification.ts`, `src/config/notificationPresentation.ts`, and `src/utils/notificationAction.ts`.
- Related web feature files inspected for destination behavior: Video Tasks, Calendar, Content Plan, Members, permissions, and app routing sources.
- Native app shell inspected: `AppShellView.swift`, `AppRouter.swift`, `CHGlassTopBar.swift`, and existing Phase 5-8 feature view models/modules.

### Real notification contract
- Table: `notifications`.
- Fields: `id`, `recipient_id`, `actor_id`, `type`, `title`, `body`, `entity_type`, `entity_id`, `action_url`, `metadata`, `event_key`, `read_at`, and `created_at`.
- RLS: recipient-scoped reads and mutations; native does not add a client-side recipient filter that would replace RLS.
- Recent list: `created_at` descending, bounded by the repository limit.
- Unread count: source-backed count where `read_at` is null.
- Mark one read: RPC `mark_notification_read` with `p_notification_id`.
- Mark all read: RPC `mark_all_notifications_read`.
- Delete RPCs are verified in the web/backend contract but are not surfaced in this Phase 9 native inbox UI because the supplied acceptance list does not require a destructive notification action.
- Web realtime subscription is verified. Native Phase 9 keeps canonical load, pull-to-refresh, unread refresh on profile/session changes, and post-mutation reconciliation; no push notification or new background/realtime lifecycle was introduced in this phase.

### Type mapping
- Shoot: `shoot_created`, `shoot_updated`, `shoot_cancelled`, `shoot_member_added`, `shoot_member_removed`.
- Content Plan: `content_plan_created`, `content_plan_assigned`, `content_plan_reassigned`, `content_plan_deleted`.
- Video Task: `video_task_created`, `video_task_accepted`, `video_task_execution_updated`, `video_task_completed`, `video_task_deleted`.
- Unknown types are rendered safely as passive notification content and do not create fake navigation.
- Entity types are restricted to verified values: `shoot`, `content_plan`, and `video_task`.

### Deep links
- `/calendar` opens a verified shoot when `highlight` or legacy `shoot` resolves to an existing shoot id.
- `/tasks` and `/video-thang` open a verified Video Task when `highlight` or legacy `task` resolves to an existing task id.
- `/content-plan` opens a verified Content Plan item when `highlight` or legacy `item` resolves to an existing content id.
- `/users` opens the Members root when the current user can view Members.
- `/dashboard` opens Overview.
- Absolute, protocol-relative, malformed, or unverifiable links fall back to passive/unavailable handling.
- Missing/deleted destination rows show production-safe copy: `Nội dung thông báo không còn khả dụng.`

### Permissions
- Notifications root is reachable from the existing topbar bell as a secondary route.
- Bottom navbar remains hidden while Notifications is active.
- Destination opens are permission-aware: Calendar, Video Tasks, Content Plan, and Members routes are blocked if the current profile lacks the verified view permission.
- Permission denial uses safe user-facing copy and does not reveal backend/RLS details.

### UI behavior
- Bell unread indicator is backed by the notification repository unread count and is exposed with accessibility values for unread vs zero-unread states.
- Inbox states: loading, loaded list, empty, load error with retry, read/unread, passive notice, unavailable destination, and bottom-scroll-safe list.
- Row read state uses `read_at`; unread rows are visually stronger and count toward the bell dot.
- Opening an unread row optimistically marks it read, calls the verified RPC, then reloads canonical state.
- Mark-all calls the verified RPC, updates local read state, and reloads canonical state.
- Mutation failures reconcile from source truth and show sanitized copy.

### Fixtures
- DEBUG-only fixture gate: `CREATIVEHUB_PHASE9_NOTIFICATIONS_FIXTURE`.
- Supported values: `mixed`, `zero-unread`, `empty`, `error`, `unavailable`, and `mark-failure`.
- Fixture data is in-memory only and never writes to Supabase.
- Production provider remains the default when the fixture environment variable is absent.

### Backend touched
`None`

### Tests
- Added unit coverage for type/entity mapping, safe destination resolution, DTO read/unread mapping, ordering/count/relative time, mark-one/mark-all behavior, mutation failure reconciliation, sanitized errors, and fixture isolation.
- Added UI coverage for unread bell, zero-unread bell, main inbox, unread/read states, passive open, mark-all, deep-link to Video Tasks, unavailable destination, empty state, load error, and bottom scroll safety.

### Focused verification
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build`
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO -only-testing:CreativeHubTests test`
- Result: 96 unit tests, 0 failures.
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO -only-testing:CreativeHubUITests/CreativeHubUITests/testPhase9NotificationsSnapshots test`
- Result: 1 focused UI snapshot test, 0 failures.
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO test`
- Result: 123 tests, 0 failures: 96 unit tests plus 27 UI tests.

### Screenshot QA
- `phase9-01-notifications-main.png`: PASS.
- `phase9-02-notifications-unread.png`: PASS.
- `phase9-03-notification-opened-read.png`: PASS.
- `phase9-04-notifications-mark-all-read.png`: PASS.
- `phase9-05-notification-deeplink.png`: PASS.
- `phase9-06-notification-destination-unavailable.png`: PASS.
- `phase9-07-notifications-empty.png`: PASS.
- `phase9-08-notifications-load-error.png`: PASS.
- `phase9-09-notifications-bottom-scroll-safe.png`: PASS.
- `phase9-10-bell-unread-indicator.png`: PASS.
- `phase9-11-bell-zero-unread.png`: PASS.

### Security review
- Backend changed: No.
- New Supabase tables/RPCs: No.
- Service-role key in native: No.
- RLS bypass: No.
- Push notification entitlement or token registration: No.
- Production fixture leakage: No; fixture provider is DEBUG and opt-in only.
- Raw backend error leakage in UI: sanitized.
- Unsafe external links: rejected.
- Fake local production persistence: No.

### Blockers / decisions needed
- None for Phase 9.

### Next phase
Do not start it.
