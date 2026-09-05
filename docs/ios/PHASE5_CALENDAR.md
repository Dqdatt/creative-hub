# Phase 5 - Calendar / Lich quay

Phase 5 replaces the native Calendar placeholder with the compact `Lich quay` screen and real Supabase shoot schedule contract.

## Sources

- Prototype: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE5_CALENDAR_LICH_QUAY_PACKAGE/creativehub_ios_prototype_cta_calendar_compact.html`
- Phase brief: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE5_CALENDAR_LICH_QUAY_PACKAGE/PHASE5_CALENDAR_LICH_QUAY.md`
- Source priority: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE5_CALENDAR_LICH_QUAY_PACKAGE/PHASE5_README_SOURCE_PRIORITY.md`
- Web data contract: `src/services/shootsService.ts`, `src/hooks/useShoots.ts`, `src/components/calendar/ShootModal.tsx`
- Backend mapping: `docs/ios/IOS_BACKEND_MAPPING.md`

## Native Scope

- `CalendarView` owns the compact week card, filter reveal, `Sap toi` agenda, CTA, loading, load error, month empty, and filter empty states.
- `CalendarModuleView` owns create, edit, read-only detail, save, and delete confirmation module states.
- `CalendarViewModel` owns month loading, filtering, module state, mutation lifecycle, and stale module behavior after errors.
- `CalendarSupabaseRepository` owns production reads and mutations.
- `CalendarFixtureProvider` is DEBUG-only and selected only by `CREATIVEHUB_PHASE5_CALENDAR_FIXTURE`.

## Backend Contract

Production reads:

- Table: `shoots`
- Range: `shoot_date >= startDate` and `shoot_date <= endDate`
- Sort: `shoot_date` ascending, then `created_at` ascending equivalent behavior in client ordering
- Joined relation: `shoot_editors` with embedded `profiles`
- Fields mapped into native rows: `id`, `shoot_date`, `shoot_type`, `crew`, `time_slot`, `location`, `content_note`, `shoot_note`

Native field mapping:

- `content_note` -> `CalendarShoot.content`
- `location` -> `CalendarShoot.place`
- `time_slot` -> `CalendarShoot.time`
- `shoot_note` -> `CalendarShoot.note`
- `profiles.editor_code` -> mutation editor code values
- `shoot_editors.profile_id` -> read-only profile UUID metadata

Production mutations:

- Create RPC: `create_shoot_with_notifications`
- Update RPC: `update_shoot_with_notifications`
- Delete RPC: `delete_shoot_with_notifications`
- RPC editor input is `p_editor_codes` and contains editor codes only, never profile UUIDs.
- `shoot_note` is patched directly on `shoots` after create/update, matching the web service behavior.
- No backend SQL, RLS, trigger, or RPC files were changed in Phase 5.

## UI Contract

- Calendar CTA opens the native Calendar root directly.
- Calendar root does not show the generic search field.
- Filter reveal is local to Calendar and supports `Tat ca`, `Livestream`, `Lich quay`, `On set`, and `Khac`.
- The selected week starts on Monday and contains seven dynamic local dates.
- Agenda cards display shoot content from `content_note`, not a fake title.
- Create defaults to selected date, type `lichquay`, and time `ALL MORNING`.
- Module fields are ordered: date, type, time, place, editor, crew, content, note.
- Read-only users can open details but do not see save/delete controls.
- Create/update/delete failures keep the module open with an inline error.
- Successful save/delete closes the module, restores the Calendar shell/navbar, reloads, and shows a toast.

## Permissions

Calendar mutations use the same permission concepts as the web app:

- `shoots:create`
- `shoots:update`
- `shoots:delete`

`AppState.can(_:)` now evaluates role defaults plus permission overrides. DEBUG UI tests can force read-only behavior with `CREATIVEHUB_PHASE5_CALENDAR_PERMISSION=readonly`.

## QA Fixtures

Supported DEBUG fixture values:

- `full`
- `empty`
- `error`
- `readonly`
- `filter-empty`

Production launches default to `CalendarSupabaseRepository`; fixtures are never used unless explicitly selected under `DEBUG`.

## Screenshots

Generated under `ios/CreativeHub/QA/Snapshots`:

- `phase5-01-calendar-main.png`
- `phase5-02-calendar-filters-open.png`
- `phase5-03-calendar-onset-filter.png`
- `phase5-04-calendar-create-module.png`
- `phase5-05-calendar-edit-module.png`
- `phase5-06-calendar-readonly-detail.png`
- `phase5-07-calendar-delete-confirm.png`
- `phase5-08-calendar-restored-toast.png`
- `phase5-09-calendar-empty.png`
- `phase5-10-calendar-load-error.png`
- `phase5-11-calendar-filter-empty.png`

All screenshots were generated at 1206 x 2622 on the iPhone 16 Pro simulator.

## Verification

- Phase 5 targeted UI snapshot test passed with all 11 required screenshots.
- Unit coverage verifies week generation, type/filter mapping, create defaults, agenda sort/filter/content mapping, display crew semantics, editor code versus profile UUID separation, RPC payload shape, validation copies, read-only permissions, retry/filter-empty states, mutation success/failure behavior, and navbar/toast contracts.
- Full regression and final build are recorded in the Phase 5 handoff response.

## Live Smoke

No live Supabase smoke mutation was run in Phase 5. The native production repository points at the verified web/RPC contract, but this workspace did not provide a safe authenticated dev session for live read/write smoke testing.

## FIX 01 - Read-only + Canonical Crew Labels

Read-only presentation:

- `Chi tiết lịch quay` uses passive value surfaces for date, time, location, crew, content, and note.
- Read-only values are rendered as text, not disabled `TextField` or `TextEditor` controls, so tapping them does not invoke editing or the keyboard.
- Shoot type is rendered as one passive badge for the current type only.
- Assigned editors are rendered as passive identity chips with avatar initials and human display names.
- Save and Delete are absent in read-only mode; Back remains the only exit.

Canonical agenda editor labels:

- Source file: `src/services/shootsService.ts`
- Source functions: `getEditorCrewLabel()`, `getShootEditors()`, `combineDisplayCrew()`, `mapShootRow()`
- Input identity for agenda labels is the profile `editor_code` plus profile names.
- Verified code mappings:
  - `dat` -> `ĐẠT`
  - `hai` -> `HẢI`
  - `minh` -> `MINH`
- Fallback rule: use the final token from `full_name`, `display_name`, `short_name`, or `editor_code`, uppercased.

The native implementation keeps these concepts separate:

- editor option display name: human label for picker/detail chips, such as `Đạt Đoàn`
- editor code: RPC identifier sent to `p_editor_codes`, such as `dat`
- compact agenda label: canonical crew label, such as `ĐẠT`
- profile UUID: relation identity from `shoot_editors.profile_id`, never sent as an editor code

Mutation behavior:

- Create and update still persist through the verified repository/RPC contract.
- After successful create/update, the view model reloads schedules from the repository.
- DEBUG fixture create/update now uses the same canonical label mapper as production mapping, so form display names do not leak into agenda `displayCrew`.

FIX 01 screenshots:

- `phase5-fix01-01-readonly-detail.png`
- `phase5-fix01-02-edit-mode-preserved.png`
- `phase5-fix01-03-canonical-crew-before.png`
- `phase5-fix01-04-canonical-crew-after-toast.png`

FIX 01 tests cover read-only UI affordance removal, edit-mode preservation, canonical editor label mappings, fixture create/update remapping, display-name versus compact-label separation, and the existing editor-code/profile-UUID contract.
