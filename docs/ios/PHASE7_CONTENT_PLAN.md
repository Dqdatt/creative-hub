### Completed
Implemented Phase 7 native `Content Plan` with production Supabase repository wiring, permission-aware list/module UI, month navigation, search/filters, CRUD paths, linked Video Task assignment workflow, DEBUG-only fixtures, focused tests, and required screenshot QA.

### Files changed
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanModels.swift`
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanRepository.swift`
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanFixtures.swift`
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanViewModel.swift`
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanView.swift`
- `ios/CreativeHub/CreativeHub/Features/ContentPlan/ContentPlanModuleView.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppShellView.swift`
- `ios/CreativeHub/CreativeHub.xcodeproj/project.pbxproj`
- `ios/CreativeHub/CreativeHubTests/CreativeHubTests.swift`
- `ios/CreativeHub/CreativeHubUITests/CreativeHubUITests.swift`
- `ios/CreativeHub/QA/Snapshots/phase7-01-content-main.png`
- `ios/CreativeHub/QA/Snapshots/phase7-02-content-tools-open.png`
- `ios/CreativeHub/QA/Snapshots/phase7-03-content-filtered.png`
- `ios/CreativeHub/QA/Snapshots/phase7-04-content-create.png`
- `ios/CreativeHub/QA/Snapshots/phase7-05-content-edit.png`
- `ios/CreativeHub/QA/Snapshots/phase7-06-content-readonly.png`
- `ios/CreativeHub/QA/Snapshots/phase7-07-content-linked-video-task.png`
- `ios/CreativeHub/QA/Snapshots/phase7-08-content-delete-confirm.png`
- `ios/CreativeHub/QA/Snapshots/phase7-09-content-restored-toast.png`
- `ios/CreativeHub/QA/Snapshots/phase7-10-content-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase7-11-content-filter-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase7-12-content-load-error.png`
- `ios/CreativeHub/QA/Snapshots/phase7-13-content-bottom-scroll-safe.png`
- `docs/ios/PHASE7_CONTENT_PLAN.md`

### Source verification
- Native sources inspected: `AppRouter.swift`, `AppState.swift`, `AppShellView.swift`, Phase 5 Calendar implementation, Phase 6 Video Tasks implementation, and `docs/ios/PHASE6_VIDEO_TASKS.md`.
- Web Content Plan files inspected: `src/services/contentPlanService.ts`, `src/hooks/useContentPlan.ts`, `src/types/contentPlan.ts`, `src/pages/ContentPlan.tsx`, `src/components/content-plan/ContentPlanFilters.tsx`, `src/components/content-plan/ContentPlanTable.tsx`, `src/components/content-plan/ContentPlanModal.tsx`, `src/config/permissions.ts`, and `src/data/contentPlan.ts`.
- Supabase/RPC/SQL inspected: `supabase/content_plan_schema.sql`, `supabase/content_plan_video_task_relation_patch.sql`, `supabase/content_plan_task_assignment_rpc.sql`, `supabase/content_plan_video_task_notification_events.sql`, `supabase/content_plan_link_patch.sql`, and `supabase/content_plan_note_patch.sql`.
- Phase 7 package path inspected: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE7_CONTENT_PLAN_PACKAGE/`.
- Visual source note: the supplied Phase 7 package contained only `PHASE7_CONTENT_PLAN_PROMPT.md` and `PHASE7_CONTENT_PLAN_README.md`; no Phase 7 HTML prototype file was present in that package. Visual fallback sources inspected in the repo were `/Users/dqdatt/Desktop/TaskManagementApp/video-task-project/ios-prototype.html`, `src/ios-prototype/screens/IOSContentPlanScreen.tsx`, and `src/ios-prototype/components/IOSSheetRenderer.tsx`.

### Real data contract
- Table: `content_plan`.
- Fields: `id`, `air_date`, `title`, `note`, `category`, `editor_id`, `link`, joined `profiles`, and joined `video_tasks`.
- Month/date membership: rows whose `air_date` falls between local month start and end.
- Sort: incomplete/no-safe-link rows first, then `air_date`, then stable id/date fallback.
- Editor identity: UI/editor filters use `profiles.editor_code` for selection and display, while assignment resolves to `profiles.id` UUID before RPC writes.
- Team Order: not a Content Plan field in verified web/backend sources.
- Category/type: `Video dài`, `Short/Reels`, `Livestream`, `Ảnh`, `Motion`, `Ads`.
- Notes: `content_plan.note` remains a source-owned planning field.
- Linked Video Task relation: linked when `video_tasks.content_plan_id = content_plan.id`.

### Repository
- `ContentPlanSupabaseRepository` reads `content_plan` with `profiles` and `video_tasks` joins through the signed-in Supabase client.
- Create calls `create_content_plan_with_notifications`.
- Update writes source-owned Content Plan fields directly to `content_plan`.
- Assignment resolves editor code to profile UUID, then calls `assign_content_plan_editor`.
- Delete calls `delete_content_plan_with_notifications`.
- No service-role client, RLS bypass, schema migration, or new RPC was added.

### View model
- `ContentPlanViewModel` owns selected month, loading/error/loaded state, search, editor/category filters, create/edit/assign/read-only modes, form data, mutation state, delete confirmation state, retry, canonical reload, and toast handoff.
- Mutations reload canonical Content Plan data after success.
- Mixed content edit plus editor reassignment is rejected locally with the same safe workflow rule: save content first, then assign editor.

### Permissions
- `contentPlanCreate` gates `+ Thêm dòng`.
- `contentPlanUpdate` gates source-owned field edits.
- `contentPlanAssign` gates editor assignment and linked task creation/update.
- `contentPlanDelete` gates delete controls.
- Read-only detail is passive: no fake disabled edit form, no picker affordances, no Save.
- Admin override is limited to verified update/assign behavior and does not unlock Video Task execution fields inside Content Plan.

### CRUD
#### Create
- Backend path: `create_content_plan_with_notifications`.
- Validation: title required, `YYYY-MM-DD` air date required, safe `http://`/`https://` link if provided.
- Editor assignment: create does not auto-create Video Task.
- Canonical reload: PASS.
- PASS.

#### Update
- Backend path: direct `content_plan` update for Content Plan-owned fields.
- Locked/source-owned fields: linked item `link` is passive because it is synchronized from Video tháng.
- Editor changes: routed through assignment workflow, not mixed with content update.
- Canonical reload: PASS.
- PASS.

#### Delete
- Backend path: `delete_content_plan_with_notifications`.
- Linked consequence: linked `video_tasks` are deleted by the verified cascade semantics; confirmation copy states this consequence.
- Confirmation: PASS, overlay does not mutate module mode/form.
- Canonical reload and restored toast: PASS.
- PASS.

### Content Plan -> Video Task
- Trigger/workflow: assigning an editor to a compatible Content Plan row via the verified assignment RPC.
- Backend path/RPC: `assign_content_plan_editor(p_content_plan_id, p_editor_id)`.
- Initial linked task state: `Chờ`.
- Editor parameter identity: profile UUID, resolved from editor code.
- Duplicate prevention: backend lock/unique constraint and RPC behavior prevent duplicate linked tasks.
- Compatible categories: null, `Video dài`, `Motion`, and `Ads`.
- Existing linked task behavior: existing task is updated where allowed; reassignment is blocked once task execution has started by backend contract.
- Content Plan canonical fields: title, category, air date, editor, note, and link ownership remain with Content Plan/linked sync.
- Video Task execution fields: remain on `video_tasks`.
- PASS.

### Main Content UI
- Root replaces the placeholder and uses title `Content Plan` with bottom nav label `Content`.
- Month navigation uses previous/next chevrons and reloads canonical month data.
- List cards show verified fields only: air date, title, category, editor, note, safe link where present, and linked state.
- Search filters title only, matching verified web behavior.
- Filters include first-class category chips plus compact editor/category menus.
- Active filters and reset are visible.
- Empty and filter-empty are separate states.
- Bottom scroll safety: final card remains tappable above the floating navbar.
- PASS.

### States
- Loading: implemented.
- Loaded: PASS.
- Empty: PASS.
- Filter empty: PASS.
- Load error: PASS with retry.
- Retry: implemented through `viewModel.retry()`.
- Read-only: PASS.

### Fixtures
- DEBUG-only `ContentPlanFixtureProvider`.
- Explicit gate: `CREATIVEHUB_PHASE7_CONTENT_PLAN_FIXTURE`.
- Supported values: `full`, `empty`, `error`.
- Month override: `CREATIVEHUB_PHASE7_MONTH`.
- Permission QA override: `CREATIVEHUB_PHASE7_CONTENT_PLAN_PERMISSION`.
- Fixture mutations are in-memory only and never write to Supabase.

### Tests
- Added unit coverage for data contract/RPC params, permissions/module modes, filters/sort/reset, create/update/assign/delete paths, and delete overlay state isolation.
- Added UI coverage for main/filter, create/edit, read-only, linked Video Task, delete confirmation/restored toast, empty/filter-empty/error, and bottom scroll safety.
- Full scheme PASS: 102 tests total, 82 app/unit tests and 20 UI tests.

### Screenshot QA
- `phase7-01-content-main.png`: PASS.
- `phase7-02-content-tools-open.png`: PASS.
- `phase7-03-content-filtered.png`: PASS.
- `phase7-04-content-create.png`: PASS.
- `phase7-05-content-edit.png`: PASS.
- `phase7-06-content-readonly.png`: PASS.
- `phase7-07-content-linked-video-task.png`: PASS.
- `phase7-08-content-delete-confirm.png`: PASS.
- `phase7-09-content-restored-toast.png`: PASS.
- `phase7-10-content-empty.png`: PASS.
- `phase7-11-content-filter-empty.png`: PASS.
- `phase7-12-content-load-error.png`: PASS.
- `phase7-13-content-bottom-scroll-safe.png`: PASS.

### Regression
- Overview: PASS through full UI regression.
- Calendar: PASS through full UI regression.
- Video Tasks: PASS through full UI regression.
- Phase 6 compact filters: PASS.
- Linked Accept: PASS through existing Phase 6 UI tests.
- Linked execution: PASS through existing Phase 6 UI tests.
- Linked complete/safe result link: PASS through existing Phase 6 tests.
- Linked other-editor passive detail: PASS.
- Navbar, Calendar CTA, module motion, toast, Notifications/Profile navigation, and auth/system states: PASS through full suite.

### Build
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build`

### Full tests
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO test`
- Result: 102 tests total, 0 failures.

### Security review
- Backend changed: No.
- Service-role key: No.
- Credentials/tokens: No new credentials.
- RLS bypass: No.
- Fixture backend writes: No.
- Production fixture leakage: No; fixture provider is DEBUG and opt-in only.
- Editor identity confusion: guarded by distinct editor code/profile UUID models and tests.
- Duplicate linked-task risk: native uses existing assignment RPC and does not invent direct linked task creation.

### Backend touched
`None`

### Blockers / decisions needed
- None for implementation.
- Source note: no Phase 7 HTML prototype was present in the supplied package, so the native screen used verified web/backend contracts plus repo-local iOS prototype sources for visual guidance.

### Remaining issues
- None known for Phase 7.

### Next phase
`Phase 8 — Members / Thành viên` is inferred from the supplied "do not start Members or later phases" instruction and the existing project navigation. A separate Phase 8 package was not supplied or started.

---

### Phase 7 Fix 01 Completed
Applied the Tech Lead visual/semantic closure for native Content Plan without starting Phase 8.

### Phase 7 prototype/source resolution
- Searched paths: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE7_FIX01_CONTENT_PLAN_PACKAGE`, `/Users/dqdatt/Desktop/TaskManagementApp/PHASE7_CONTENT_PLAN_PACKAGE`, and `/Users/dqdatt/Desktop/TaskManagementApp/video-task-project`.
- Search result: no actual Phase 7 HTML prototype was present; only prompt/readme docs and generated QA snapshots were found.
- Approved fallback sources used for this fix: current native design system, current Phase 7 native geometry, `/Users/dqdatt/Desktop/TaskManagementApp/video-task-project/ios-prototype.html`, and `src/ios-prototype/screens/IOSContentPlanScreen.tsx`.

### Phase 7 Fix 01 verified data semantics
- Re-verified from `src/services/contentPlanService.ts`, `src/components/content-plan/ContentPlanTable.tsx`, `src/components/content-plan/ContentPlanFilters.tsx`, and `supabase/content_plan_task_assignment_rpc.sql`.
- Assignment source of truth is `assign_content_plan_editor(p_content_plan_id, p_editor_id)`.
- Compatible categories for linked Video Task creation/update: null, `Video dài`, `Motion`, `Ads`.
- Incompatible categories: `Short/Reels`, `Livestream`, `Ảnh`; native now labels them `Không tạo Video Task` instead of a pending creation state.
- Assigning an editor to a compatible Content Plan row creates or updates exactly one linked `video_tasks` row through the RPC.
- A compatible assigned row without `video_tasks.content_plan_id = content_plan.id` is treated as an exceptional inconsistent state, not a happy-path fixture state.
- Existing linked task reassignment remains allowed only while linked task status is `Chờ`; once status is `Đang làm` or `Đã xong`, native locks the editor picker and shows the backend-equivalent reason.

### Phase 7 Fix 01 UI corrections
- Removed duplicated category filtering UI; native now has one canonical category rail plus the editor menu and reset.
- Reset clears search, editor filter, and category filter.
- Removed any `Team Order` Content Plan surface.
- Linked detail now shows a visible linked indicator with linked task status and matching editor display.
- Linked Content Plan link remains passive because it is synchronized from Video tháng.
- No Video execution controls were added to Content Plan.
- Load error copy is sanitized for QA and no longer exposes `Fixture`, raw backend, RPC, SQL, Supabase, or PostgREST markers.

### Phase 7 Fix 01 tests/screenshots
- Added unit coverage for task-state semantics, sanitized load error copy, fixture/backend assignment contract, incompatible category behavior, linked status, and editor reassignment lock.
- Added UI coverage for one canonical category filter UI, linked detail, edit lock, incompatible category state, sanitized load error, and bottom scroll safety.
- Required screenshots:
  - `phase7-fix01-01-content-main-canonical.png`
  - `phase7-fix01-02-content-tools-compact.png`
  - `phase7-fix01-03-content-filter-active.png`
  - `phase7-fix01-04-content-linked-detail.png`
  - `phase7-fix01-05-content-linked-edit-lock.png`
  - `phase7-fix01-06-content-incompatible-category.png`
  - `phase7-fix01-07-content-load-error.png`
  - `phase7-fix01-08-content-bottom-scroll-safe.png`

### Phase 7 Fix 01 backend
`None`
