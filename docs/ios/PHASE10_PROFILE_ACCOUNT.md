### Completed
Implemented Phase 10 native `Hồ sơ` / account surface and closed FIX 01 visual + contract review items.

### Files changed
- `ios/CreativeHub/CreativeHub/Features/Profile/ProfileModels.swift`
- `ios/CreativeHub/CreativeHub/Features/Profile/ProfileRepository.swift`
- `ios/CreativeHub/CreativeHub/Features/Profile/ProfileFixtures.swift`
- `ios/CreativeHub/CreativeHub/Features/Profile/ProfileViewModel.swift`
- `ios/CreativeHub/CreativeHub/Features/Profile/ProfileView.swift`
- `ios/CreativeHub/CreativeHub/Core/Components/CHButton.swift`
- `ios/CreativeHub/CreativeHub/App/AppState.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppRouter.swift`
- `ios/CreativeHub/CreativeHub/Core/Navigation/AppShellView.swift`
- `ios/CreativeHub/CreativeHubTests/CreativeHubTests.swift`
- `ios/CreativeHub/CreativeHubUITests/CreativeHubUITests.swift`
- `docs/ios/PHASE10_PROFILE_ACCOUNT.md`

### Source verification
- Native Profile files re-opened for FIX 01: `Features/Profile/*`.
- Phase 8 FIX 02 Members bottom-action pattern re-checked and mirrored for the Profile edit sheet.
- Backend profile contract remains the Phase 10 verified Supabase `profiles` + avatar storage contract.
- Backend was not changed for FIX 01.

### Real profile contract
- Table: `profiles`.
- Read fields: `id`, `email`, `full_name`, `display_name`, `short_name`, `phone`, `role`, `department`, `avatar_url`, `editor_code`, `is_editor_member`, `active`, and `is_active`.
- Editable self fields: `full_name`, `display_name`, `short_name`, `phone`, `department`, and `avatar_url`.
- Protected fields remain read-only in native: `id`, `email`, `role`, editor identity, active status, permissions, and account ownership.
- `short_name` is updated from `display_name` to preserve the web compatibility contract.

### FIX 01 closure
- Unsupported Theme, Language, and notification preferences are omitted from production Profile UI.
- The absence of unsupported preferences is documented here only; no production card or unavailable/internal copy is rendered.
- The save-success screenshot issue was caused by nondeterministic UI-test text entry. The UI test now clears the existing value before typing and reopens edit to assert the exact canonical value.
- Screenshot scenarios now launch isolated fixtures so saved display-name state cannot leak into later images.
- Profile edit bottom actions now use a safe bottom action bar with full `Hủy` and `Lưu thay đổi` labels, no gray material slab, and scroll padding for final fields.
- Avatar upload/remove was re-verified as source-backed. Production upload still uses the signed-in Supabase storage path; DEBUG fixtures simulate image/avatar states without backend writes.
- Avatar upload failure now shows avatar-specific sanitized copy and preserves the current avatar.

### Avatar contract
- Production upload uses Supabase Storage with upsert enabled, then stores the public URL in `profiles.avatar_url`.
- Avatar removal updates `profiles.avatar_url` to null.
- Native supports initials fallback when no avatar URL is present or image loading fails.
- Image picker is native `PhotosPicker`; selected avatar payload is capped at 2 MB.
- FIX 01 unit coverage verifies scoped path construction, upload success, upload failure preservation, removal, and no cross-user path.

### Preferences contract
- Theme, language, and notification preferences are not source-backed account preferences in the verified web/backend source.
- Native must not render these unsupported preferences in production UI.
- No fake local account preference persistence was introduced.

### UI behavior
- Profile is a secondary route opened from the existing topbar profile entry point.
- Bottom navbar remains hidden while Profile is active and restores to the origin tab on back.
- Main state shows avatar/initials, display identity, email, role, active status, account metadata, and profile actions.
- Edit state supports full name, display name, phone, department, avatar change, avatar removal, cancel, save, validation errors, and safe bottom actions.
- Email, role, status, and editor identity are displayed but not editable.
- Save preserves the draft on failure; success reloads canonical profile data and updates the app-shell current user summary.
- Password sheet and logout confirmation remain unchanged except for regression coverage.

### Fixtures
- DEBUG-only fixture gate: `CREATIVEHUB_PHASE10_PROFILE_FIXTURE`.
- Supported values: `normal`, `editor`, `avatar`, `initials`, `save-error`, `avatar-upload-error`, `load-error`, and `password-error`.
- Fixture data is in-memory only and never writes to Supabase.
- Production provider remains the default when the fixture environment variable is absent.

### Backend touched
`None`

### Tests
- Previous accepted Phase 10 baseline: 130 tests.
- Added FIX 01 unit coverage for exact replacement, fixture reset, avatar scoped path, upload success, upload failure preservation, and remove-to-initials fallback.
- Updated Phase 10 UI coverage for unsupported preferences absent from the accessibility tree, deterministic field replacement, fixture isolation, safe bottom edit actions, actual avatar fixture evidence, avatar remove fallback, password/logout regressions, bottom scroll safety, and back restoration.
- Full-suite count after FIX 01: 132 tests, 104 unit tests plus 28 UI tests.

### Focused verification
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build`
- PASS: `xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO -only-testing:CreativeHubTests/CreativeHubTests/testPhase10ProfileDTOMapsRoleStatusEditorAndInitials -only-testing:CreativeHubTests/CreativeHubTests/testPhase10ProfileValidationAndProtectedFieldAllowlist -only-testing:CreativeHubTests/CreativeHubTests/testPhase10ProfileViewModelSaveReloadsCanonicalAndRefreshesShell -only-testing:CreativeHubTests/CreativeHubTests/testPhase10ProfileSaveFailurePreservesDraftAndSanitizesError -only-testing:CreativeHubTests/CreativeHubTests/testPhase10PasswordValidationAndFixtureIsolation -only-testing:CreativeHubTests/CreativeHubTests/testPhase10ProfileLoadErrorCopyAndLogout -only-testing:CreativeHubTests/CreativeHubTests/testPhase10Fix01ProfileReplacementAndFixtureReset -only-testing:CreativeHubTests/CreativeHubTests/testPhase10Fix01AvatarUploadRemoveFailureAndScopedPath test`
- Result: 8 focused unit tests, 0 failures.
- PASS: `CREATIVEHUB_SNAPSHOT_DIR=ios/CreativeHub/QA/Snapshots xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO -only-testing:CreativeHubUITests/CreativeHubUITests/testPhase10ProfileAccountSnapshots test`
- Result: 1 focused Phase 10 UI snapshot test, 0 failures.

### Full verification
- PASS: `CREATIVEHUB_SNAPSHOT_DIR=ios/CreativeHub/QA/Snapshots xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO test`
- Result: 104 unit tests and 28 UI tests, 132 total, 0 failures.

### Screenshot QA
- `phase10-fix01-01-profile-main-clean.png`: PASS.
- `phase10-fix01-02-profile-edit-clean.png`: PASS.
- `phase10-fix01-03-profile-edit-bottom-actions.png`: PASS.
- `phase10-fix01-04-profile-save-replacement.png`: PASS.
- `phase10-fix01-05-profile-avatar-actual-image.png`: PASS.
- `phase10-fix01-06-profile-avatar-remove.png`: PASS.
- `phase10-fix01-07-profile-password-regression.png`: PASS.
- `phase10-fix01-08-profile-logout-regression.png`: PASS.
- `phase10-fix01-09-profile-bottom-scroll-safe.png`: PASS.
- `phase10-fix01-10-profile-back-restores-shell.png`: PASS.

### Security review
- Backend changed: No.
- New Supabase tables/RPCs: No.
- Service-role key in native: No.
- RLS bypass: No.
- Raw backend error leakage in UI: sanitized.
- Production fixture leakage: No; fixture provider is DEBUG and opt-in only.
- Protected account fields editable by self: No.
- Fake local production persistence: No.

### Blockers / decisions needed
- None for Phase 10 FIX 01.

### Next phase
Do not start it.
