### Completed
Implemented Phase 6 native `Video tháng` with real Supabase repository wiring, explicit DEBUG fixture gates, permission-aware UI, standalone CRUD forms, linked Content Plan workflows, filter/search/month states, and required screenshot coverage.

### Files changed
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskModels.swift`
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskRepository.swift`
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskFixtures.swift`
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskViewModel.swift`
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskView.swift`
- `ios/CreativeHub/CreativeHub/Features/VideoTasks/VideoTaskModuleView.swift`
- `ios/CreativeHub/CreativeHub/App/AppState.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppShellView.swift`
- `ios/CreativeHub/CreativeHub.xcodeproj/project.pbxproj`
- `ios/CreativeHub/CreativeHubTests/CreativeHubTests.swift`
- `ios/CreativeHub/CreativeHubUITests/CreativeHubUITests.swift`
- `ios/CreativeHub/QA/Snapshots/phase6-01-video-main.png`
- `ios/CreativeHub/QA/Snapshots/phase6-02-video-tools-open.png`
- `ios/CreativeHub/QA/Snapshots/phase6-03-video-filtered.png`
- `ios/CreativeHub/QA/Snapshots/phase6-04-video-create.png`
- `ios/CreativeHub/QA/Snapshots/phase6-05-video-edit-standalone.png`
- `ios/CreativeHub/QA/Snapshots/phase6-06-video-linked-waiting-accept.png`
- `ios/CreativeHub/QA/Snapshots/phase6-07-video-linked-in-progress.png`
- `ios/CreativeHub/QA/Snapshots/phase6-08-video-linked-other-editor.png`
- `ios/CreativeHub/QA/Snapshots/phase6-09-video-delete-confirm.png`
- `ios/CreativeHub/QA/Snapshots/phase6-10-video-restored-toast.png`
- `ios/CreativeHub/QA/Snapshots/phase6-11-video-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase6-12-video-filter-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase6-13-video-load-error.png`
- `ios/CreativeHub/QA/Snapshots/phase6-14-video-readonly-permissions.png`
- `ios/CreativeHub/QA/Snapshots/phase6-15-video-completed-link.png`
- `docs/ios/PHASE6_VIDEO_TASKS.md`

### Architecture
- repository: `VideoTaskSupabaseRepository` reads/writes `video_tasks`, joins `content_plan` and `profiles`, resolves editor code to profile UUID for writes, and calls linked-task RPCs.
- view model: `VideoTaskViewModel` owns loading, month navigation, filters, form state, linked workflow actions, delete confirmation, and fixture/production provider injection.
- main view: `VideoTaskView` renders the native `Video tháng` list, month strip, search/filter reveal, cards, empty/filter-empty/load-error states, safe result links, and permission-gated add/delete actions.
- module: `VideoTaskModuleView` renders create/edit/read-only detail, locked linked source fields, editor execution fields, accept/complete actions, and delete confirmation copy.
- fixture gate: DEBUG-only `CREATIVEHUB_PHASE6_VIDEO_TASKS_FIXTURE` supports `full`, `empty`, and `error`; production defaults to `VideoTaskSupabaseRepository`.

### Backend touched
`None`

### Source verification
- compact prototype exact path: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE6_VIDEO_TASKS_PACKAGE/creativehub_ios_prototype_cta_calendar_compact.html`
- complete states prototype exact path: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE6_VIDEO_TASKS_PACKAGE/creativehub_ios_prototype_complete_states(2).html`
- `renderVideo()` inspected: YES
- `taskCard()` inspected: YES
- `openTask()` inspected: YES
- web types inspected: YES, `src/types/task.ts`
- web service inspected: YES, `src/services/tasksService.ts`
- web filters/table/modal inspected: YES, `TaskFilters.tsx`, `TaskTable.tsx`, `TaskModal.tsx`
- SQL/RPC contracts inspected: YES, existing `supabase/` linked video task functions and setup checks.

### Product contract
- Native statuses use backend/web truth: `Chờ`, `Đang làm`, `Đã xong`.
- Native categories use backend/web truth: `Video dài`, `Motion`, `Ads`.
- Native priority uses backend/web truth: empty normal priority and `Gấp`.
- Month membership follows effective air date, including linked Content Plan air dates.
- Search matches web behavior for title, air date, and note.

### Editor identity
- UI displays editor labels from profile/editor metadata.
- Writes keep editor code and profile UUID distinct.
- Repository resolves `profiles.id` from `profiles.editor_code` before writing `video_tasks.editor_id`.
- Current editor ownership checks compare linked task `editorProfileID` to `AppState.currentProfileID`.

### Permissions
- `videoTasksCreate` gates `+ Thêm Task`.
- `videoTasksUpdate` gates opening/editing task modules.
- `videoTasksDelete` gates delete controls.
- Read-only users can view the list without add/delete/edit controls.
- Admins can override editable execution/status fields on linked tasks while source-owned planning fields stay locked.

### Standalone CRUD
#### Create
- PASS: create module opens from `+ Thêm Task`.
- PASS: standalone fields are editable when create permission is present.
- PASS: validation rejects missing title, invalid dates, invalid order team, and unsafe result links.
#### Update
- PASS: standalone edit module opens from list cards.
- PASS: standalone fields are editable with update permission.
- PASS: save calls direct `video_tasks` update.
#### Delete
- PASS: delete control is visible with delete permission.
- PASS: confirmation is shown before delete.
- PASS: fixture and production repository paths preserve linked delete semantics.

### Linked Task workflow
#### Accept
- PASS: waiting linked task assigned to current editor shows `Nhận Task`.
- PASS: source-owned fields are locked.
- PASS: receive/return dates are editable.
- PASS: action calls `accept_linked_video_task`.
#### In progress
- PASS: assigned linked in-progress task shows `Hoàn thành Task`.
- PASS: execution fields can be updated.
- PASS: action calls `update_linked_video_task_execution`.
#### Complete
- PASS: completion calls `complete_linked_video_task`.
- PASS: result link validation only accepts safe `http://` and `https://` links.
#### Other editor
- PASS: other-editor linked task opens read-only execution state for non-admin update user.
- PASS: accept/save/complete actions are hidden.

### Main Video UI
- PASS: top bar title is `Video tháng`.
- PASS: video owns its filter reveal content, not the generic placeholder.
- PASS: month strip, count, add button, cards, badges, dates, notes, linked markers, safe links, and delete controls render.
- PASS: status/editor/order/category filters render as chip rails.
- PASS: compact card layout remains readable on iPhone 16 Pro simulator.

### States
- Loading: PASS through native load-state path.
- Loaded: PASS.
- Empty month: PASS.
- Filter empty: PASS.
- Load error: PASS with retry button.
- Read-only permissions: PASS.

### Live backend smoke
- NOT RUN: no safe live authenticated iOS session was used for this phase. Production repository compiles and is covered by contract tests without writing fixture data.

### Build
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build`

### Tests
- PASS: focused unit target `CreativeHubTests`.
- PASS: focused UI target `CreativeHubUITests/CreativeHubUITests/testPhase6VideoTaskSnapshots`.
- PASS: full scheme test suite, 87 tests total: 74 unit tests and 13 UI tests.

### Screenshot QA
- `phase6-01-video-main.png`: PASS
- `phase6-02-video-tools-open.png`: PASS
- `phase6-03-video-filtered.png`: PASS
- `phase6-04-video-create.png`: PASS
- `phase6-05-video-edit-standalone.png`: PASS
- `phase6-06-video-linked-waiting-accept.png`: PASS
- `phase6-07-video-linked-in-progress.png`: PASS
- `phase6-08-video-linked-other-editor.png`: PASS
- `phase6-09-video-delete-confirm.png`: PASS
- `phase6-10-video-restored-toast.png`: PASS
- `phase6-11-video-empty.png`: PASS
- `phase6-12-video-filter-empty.png`: PASS
- `phase6-13-video-load-error.png`: PASS
- `phase6-14-video-readonly-permissions.png`: PASS
- `phase6-15-video-completed-link.png`: PASS

### Motion QA
- PASS: main route, filter reveal, module route, delete confirmation, toast restoration, and keyboard dismissal transitions remained stable during UI snapshot runs.

### Visual differences from prototype
#### BLOCKING
- None.
#### NON-BLOCKING
- Native app uses canonical backend status `Đang làm`; some prototype fixture copy uses `Đang dựng`.
- Native edit fields display ISO dates (`YYYY-MM-DD`) while cards display compact day/month labels.
- Lower list cards can pass beneath the translucent bottom navigation during scroll, consistent with the Phase 3 shell.

### Security review
- PASS: Phase 6 code uses the signed-in Supabase client path.
- PASS: no service-role credential or secret was added.
- PASS: fixture providers are DEBUG-gated and opt-in only.
- PASS: result links are constrained to safe `http://` and `https://` schemes.

### Blockers / decisions needed
- None.

### Remaining issues
- None known for Phase 6.

### Next phase
`Phase 7 — Content Plan`

### Phase 6 FIX 01 — UX / State Closure

- PASS: linked waiting tasks assigned to another editor now resolve to passive detail mode with title `Chi tiết Task`; accept, save, and complete actions are hidden.
- PASS: delete confirmation is an isolated overlay state. It preserves module title, workflow mode, form data, and cancel returns to the exact previous mode for eligible linked accept tasks and in-progress linked tasks.
- PASS: the Video tools reveal keeps search and visible status chips, while editor, Team Order, and category move into compact secondary menus with visible active labels and full reset semantics.
- PASS: month navigation chevrons use the existing muted token for clearer contrast without changing behavior or geometry.
- PASS: bottom scroll padding keeps the final video card and list actions above the floating navbar; navbar geometry is unchanged.
- PASS: screenshots `phase6-fix01-01-video-tools-compact.png` through `phase6-fix01-07-video-bottom-scroll-safe.png` were regenerated and visually checked.
- PASS: full native suite passed with 91 tests total: 77 app/unit tests and 14 UI tests.
