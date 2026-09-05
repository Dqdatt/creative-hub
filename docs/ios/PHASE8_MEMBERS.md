### Completed
Implemented Phase 8 native `Thành viên` with a production Supabase-backed repository, permission-aware Members root, member detail/create/edit module, destructive confirmation, password reset action, DEBUG-only fixtures, focused tests, and required screenshot QA.

### Phase 8 FIX 01
- Corrected the role stats heading from the misleading department label to `Vai trò`; counts remain unchanged and continue to represent `Admin`, `Manager`, `Creator`, and `Editor`.
- Replaced the user-visible permission summary with product copy: `Quyền sử dụng được áp dụng theo chế độ đã chọn.` The native Members UI no longer exposes raw permission keys, backend implementation wording, fixture/debug terms, or SQL/RPC/Edge Function language.
- Verified the destructive delete contract against `supabase/functions/manage-user/index.ts`: delete is a server-authorized hard account deletion after relation cleanup, avatar cleanup, auth deletion, and profile cascade verification. Native confirmation copy now states the production consequence without test-data wording and keeps email confirmation.
- Increased Members root bottom inset so the final role stats card scrolls fully above the floating navbar.
- Detail/edit evidence is intentionally distinct: authorized users route to edit via `MembersViewModel.open`, while the read-only permission route produces the source-backed `Chi tiết thành viên` detail state.
- Added focused FIX 01 tests for production-safe copy and delete-failure state preservation, plus UI screenshot coverage for the eight FIX 01 acceptance images.

### Phase 8 FIX 02
- Members modules now opt out of the shared outer module `ScrollView` and own their viewport-level scroll/overlay stack, preventing nested-scroll bottom inset clipping.
- The edit/create bottom action region is full-width, safe-area aware, and uses the full `Lưu thay đổi` label with exactly one `member.action-bar`.
- Blocking delete/reset overlays keep the action bar inert/hidden while preserving the underlying edit state for cancel/restore.
- The destructive delete confirmation now uses a solid shared card-style surface with stronger dimming, so background form text cannot bleed through the production delete copy.
- Added focused FIX 02 UI coverage for action geometry, modal viewport placement, delete cancel restoration, read-only no-action regression, and root bottom-scroll safety.

### Files changed
- `ios/CreativeHub/CreativeHub/Features/Members/MembersPlaceholderView.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppShellView.swift`
- `ios/CreativeHub/CreativeHubTests/CreativeHubTests.swift`
- `ios/CreativeHub/CreativeHubUITests/CreativeHubUITests.swift`
- `ios/CreativeHub/QA/Snapshots/phase8-01-members-main.png`
- `ios/CreativeHub/QA/Snapshots/phase8-02-members-tools.png`
- `ios/CreativeHub/QA/Snapshots/phase8-03-member-detail.png`
- `ios/CreativeHub/QA/Snapshots/phase8-04-member-edit.png`
- `ios/CreativeHub/QA/Snapshots/phase8-05-member-readonly.png`
- `ios/CreativeHub/QA/Snapshots/phase8-06-member-create-or-invite.png`
- `ios/CreativeHub/QA/Snapshots/phase8-07-member-destructive-confirm.png`
- `ios/CreativeHub/QA/Snapshots/phase8-08-members-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase8-09-members-filter-empty.png`
- `ios/CreativeHub/QA/Snapshots/phase8-10-members-load-error.png`
- `ios/CreativeHub/QA/Snapshots/phase8-11-members-restored-toast.png`
- `ios/CreativeHub/QA/Snapshots/phase8-12-members-bottom-scroll-safe.png`
- `docs/ios/PHASE8_MEMBERS.md`

### Source verification
- Searched paths: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE8_MEMBERS_PACKAGE/`, `/Users/dqdatt/Desktop/TaskManagementApp/PHASE8_MEMBERS_THANH_VIEN_PACKAGE/`, `/Users/dqdatt/Desktop/TaskManagementApp/`, and `/Users/dqdatt/Desktop/TaskManagementApp/video-task-project/`.
- Phase 8 package contents: `PHASE8_MEMBERS_PROMPT.md`, `PHASE8_MEMBERS_README.md`, and `.DS_Store`; no HTML or image visual source was present in the supplied package.
- Exact Phase 8 visual source used: `/Users/dqdatt/Desktop/TaskManagementApp/video-task-project/src/ios-prototype/screens/IOSUsersScreen.tsx`.
- Visual source opened/read: `IOSUsersScreen.tsx`, including compact search, member count, add CTA, grouped rows, role chips, email, active indicator, editor marker, and department/member stats.
- Web Members files inspected: `src/pages/Users.tsx`, `src/components/users/UserFilters.tsx`, `src/components/users/UserTable.tsx`, `src/components/users/UserModal.tsx`, `src/hooks/useUsers.ts`, `src/services/userManagementService.ts`, `src/types/userManagement.ts`, and `src/config/permissions.ts`.
- Downstream editor usage inspected: `src/services/contentPlanService.ts`, `src/services/shootsService.ts`, `src/services/tasksService.ts`, and `src/services/dashboardService.ts`.
- Backend/SQL/function files inspected: `supabase/user_management_patch.sql`, `supabase/role_permissions_patch.sql`, `supabase/user_permission_overrides_patch.sql`, `supabase/editor_membership_patch.sql`, `supabase/functions/create-user/index.ts`, `supabase/functions/manage-user/index.ts`, `supabase/content_plan_task_assignment_rpc.sql`, `supabase/calendar_notification_events.sql`, and `supabase/linked_video_task_execution_update_rpc.sql`.

### Real member contract
- Primary table/source: `public.profiles`.
- Member identity: `profiles.id` UUID is the relation and mutation identity.
- Editor identity: `profiles.editor_code` is the compact editor business identity; it is optional and must never be substituted with display name or UUID.
- Display name source: `display_name`, then `short_name`, then `full_name`, then `email`.
- Email source: `profiles.email`; auth email mutation uses the verified `manage-user` Edge Function with action `update_email`.
- Role source: `profiles.role`; verified roles are `admin`, `creative_manager`, `content_creator`, and `editor`; legacy `team_lead` maps to `creative_manager`.
- Active state: `is_active ?? active ?? true`, matching the web fallback and the user management patch sync.
- Editor membership: `is_editor_member` is independent of role. Active editor eligibility requires active profile, `is_editor_member = true`, and a non-empty `editor_code`.
- Ordering: web orders/final-sorts by full name using Vietnamese locale; native uses localized display name comparison.
- Pagination: web has no explicit UI pagination; native repository fetches profiles in signed-in pages of 1000 rows.
- Permission overrides: `user_permission_overrides` stores `permission_mode`; native surfaces the verified mode summary and does not redesign granular permissions.

### Permissions
- `user_management:view` gates Members access.
- `user_management:create` gates the add/create CTA.
- `user_management:update` gates editable member forms and save actions.
- Admin/user-management capability gates destructive delete, password reset, and permission mode changes.
- Read-only users receive a passive detail view: no fake disabled form, no save/delete/reset controls, and no picker affordances.
- DEBUG-only QA override `CREATIVEHUB_PHASE8_MEMBERS_PERMISSION` supports `readonly` and `update` for screenshot coverage.

### Create / Invite
- Create is supported by the verified production path `supabase/functions/create-user/index.ts`.
- Native invokes the `create-user` Edge Function through the signed-in Supabase client; no service-role key is present in the app.
- Function authorization remains server-side/admin-gated.
- Required native fields: name, email, role, active state, editor membership, editor code where applicable, permission mode, and an initial password for the verified create path.
- Canonical reload after create: implemented.

### Update
- Profile-owned fields update through the signed-in Supabase client against `profiles`.
- Email changes route through `manage-user` action `update_email`.
- Permission mode changes write `user_permission_overrides` when supported; missing-table read/delete behavior mirrors the web's defensive fallback.
- Canonical reload after update: implemented.

### Destructive member action
- Delete/remove is supported by `manage-user` action `delete_user`.
- Behavior is hard deletion through the verified server-side function after relation cleanup; confirmation copy states the action is permanent.
- Current admin/self-delete is blocked locally and by the function contract.
- Canonical reload and restored toast after delete: implemented.

### Editor identity / downstream behavior
- Native keeps profile UUID and editor code as separate model fields.
- Members UI displays editor code only when verified from `profiles.editor_code`.
- Native never fabricates an editor code.
- Downstream Calendar, Video Tasks, and Content Plan editor assignment semantics remain untouched.
- Inactive historical editors can remain visible as members but are not treated as active editor-eligible identities.

### Architecture
- Repository: `MemberSupabaseRepository` handles signed-in Supabase reads, profile mutations, Edge Function calls, permission override reads/writes, pagination, DTO mapping, and safe error propagation.
- View model: `MembersViewModel` owns loading/empty/filter-empty/error states, search, filters, create/edit/read-only module modes, validation, mutation state, canonical reloads, toasts, and safe user-facing errors.
- Root view: `MembersPlaceholderView` now renders the real Members screen with search, count, add CTA, list rows, role/status/editor markers, stats, tools panel filters, empty/filter-empty/error states, and bottom scroll safety.
- Module: `MemberModuleView` renders detail, edit, create, read-only, delete confirmation, reset password confirmation, and restored module-to-shell behavior using the accepted native module route pattern.
- Fixture gate: DEBUG-only `MemberFixtureRepository` is enabled only by `CREATIVEHUB_PHASE8_MEMBERS_FIXTURE` with `full`, `empty`, and `error` modes.

### Main Members UI
- Root replaces the placeholder and keeps the shell title `Thành viên`.
- Search matches the verified web fields: name, email, role label, and editor code.
- Filters include source-backed role and active/inactive dimensions only.
- Reset appears only when search or filters are non-default.
- Member rows show verified fields only: display name, role, email, editor marker/code, and active/inactive state.
- Bottom scroll safety: final member remains tappable above the floating navbar.

### Member module
- Detail uses the accepted full module route with hidden bottom navbar and shell restoration on back.
- Edit mode validates required name/email/role and editor code rules.
- Create mode follows the verified create-user path.
- Read-only mode is passive.
- Delete and reset password actions use confirmation overlays.

### States
- Loading: implemented.
- Loaded: PASS.
- Empty: PASS.
- Filter empty: PASS.
- Load error: PASS with retry and sanitized copy.
- Restored toast after mutation: PASS.
- Read-only: PASS.

### Backend touched
`None`

### Tests
- Added unit coverage for profile identity/editor identity separation, active/editor membership semantics, search/filter/reset behavior, create/update/delete canonical reloads, validation, permission gating, and safe error copy.
- Added UI coverage for all required Phase 8 screenshots and bottom scroll safety.
- Full scheme PASS: 112 tests total, 88 app/unit tests and 24 UI tests.

### Build
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build`

### Full tests
- PASS: `CREATIVEHUB_SNAPSHOT_DIR=ios/CreativeHub/QA/Snapshots xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO test`
- Result: 112 tests total, 0 failures.

### Screenshot QA
- `phase8-01-members-main.png`: PASS.
- `phase8-02-members-tools.png`: PASS.
- `phase8-03-member-detail.png`: PASS.
- `phase8-04-member-edit.png`: PASS.
- `phase8-05-member-readonly.png`: PASS.
- `phase8-06-member-create-or-invite.png`: PASS.
- `phase8-07-member-destructive-confirm.png`: PASS.
- `phase8-08-members-empty.png`: PASS.
- `phase8-09-members-filter-empty.png`: PASS.
- `phase8-10-members-load-error.png`: PASS.
- `phase8-11-members-restored-toast.png`: PASS.
- `phase8-12-members-bottom-scroll-safe.png`: PASS.

### Security review
- Backend changed: No.
- Service-role key in native: No.
- RLS bypass: No.
- Raw Supabase/Auth admin capability in client: No.
- Edge Function calls: signed-in Supabase client only.
- Production fixture leakage: No; fixture provider is DEBUG and opt-in.
- Raw backend error leakage in UI: sanitized.
- Editor identity confusion: guarded by separate UUID/editor-code fields and tests.

### Blockers / decisions needed
- None for Phase 8.
- Decision recorded: native exposes verified permission mode summary rather than granular custom permission flags, because the Phase 8 visual source does not include a granular permission editor and this phase is not a permission-system redesign.

### Remaining issues
- None known for Phase 8.

### Next phase
Do not start it.
