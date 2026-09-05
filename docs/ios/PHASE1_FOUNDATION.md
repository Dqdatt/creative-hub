# CreativeHub iOS Phase 1 Foundation

Date: 2026-08-14

## Scope

Phase 1 created a new native SwiftUI foundation under `ios/CreativeHub/`. It does not implement production login, dashboard data, notifications data, profile data, or CRUD flows.

## Project Architecture

- Xcode project: `ios/CreativeHub/CreativeHub.xcodeproj`
- Main target: `CreativeHub`
- Unit test target: `CreativeHubTests`
- UI test target: `CreativeHubUITests`
- Source structure:
  - `CreativeHub/App`: app entry, root state, router, root view
  - `CreativeHub/Core/DesignSystem`: colors, typography, spacing, radius, shadow tokens
  - `CreativeHub/Core/Components`: topbar, bottom navigation, calendar CTA, card, avatar, buttons, toast, state view
  - `CreativeHub/Core/Navigation`: app shell and secondary route container
  - `CreativeHub/Core/Networking`: config and Supabase client foundation
  - `CreativeHub/Features/*`: Phase 1 placeholder screens only

## Deployment Target

Selected iOS deployment target: 17.0.

Reason: Phase 1 uses modern SwiftUI animation/symbol APIs and native NavigationStack while keeping the target within currently practical iPhone support. This can be revisited if product requirements demand older devices.

## Navigation Architecture

- `MainDestination`: strongly typed main destinations in latest order:
  - `overview`
  - `video`
  - `calendar`
  - `content`
  - `members`
- `SecondaryDestination`: foundation for `notifications` and `profile`.
- `ModuleDestination`: typed future routes for task/shoot/content/member modules and account settings.
- `AppRouter` owns selected main tab and a typed `NavigationStack` path.
- Bottom navigation visibility is deterministic: visible only when `router.path.isEmpty`; hidden for secondary and module routes.

## App State

`AppState` defines:

- `AuthenticationState.checking`
- `AuthenticationState.authenticated`
- `AuthenticationState.unauthenticated`
- `AuthenticationState.expired`

Phase 1 temporarily enters `.authenticated` after startup validation so the shell can be tested. Real session restore/login belongs to Phase 2.

## Supabase Initialization

- Uses Supabase Swift package: `https://github.com/supabase/supabase-swift.git`
- Config comes from Xcode build settings into `Info.plist`:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Current values mirror the existing web `.env` Supabase project.
- No service-role key is included.
- `SupabaseService` creates a `SupabaseClient` when config is valid.

## Design Tokens

Swift tokens mirror the approved prototype baseline:

- Background: `#F3F5FB`
- Ink: `#111522`
- Muted: `#707B93`
- Purple: `#7256FF`
- Blue: `#4E8CFF`
- Green: `#21BF6B`
- Orange: `#FF9C2A`
- Red: `#FF5B65`
- Primary gradient: purple to blue
- Main card radius: 24pt
- Topbar height: 48pt
- Bottom nav visual height: 72pt

## Reusable Components

- `CHGlassTopBar`
- `CHBottomNavigation`
- `CHCalendarCTA`
- `CHCard`
- `CHAvatar`
- `CHPrimaryButtonStyle`
- `CHSecondaryButtonStyle`
- `CHToast`
- `CHStateView`

The bottom navigation follows the updated Phase 1 direction:

`Tổng quan | Video | CTA Lịch quay | Content | Thành viên`

Calendar is a raised central CTA and remains present when regular tabs are selected.

## Logo

Imported `src/assets/logo.png` into:

`ios/CreativeHub/CreativeHub/Resources/Assets.xcassets/Logo.imageset/logo.png`

This matches the Phase 0-identified current CreativeHub logo asset.

## Screenshot Baseline

Generated native snapshots under:

`ios/CreativeHub/QA/Snapshots/`

- `01-overview.png`
- `02-video.png`
- `03-calendar-cta.png`
- `04-secondary-hidden.png`
- `05-restored-overview.png`

These were visually inspected for basic shell coherence: safe area, topbar framing, navbar visibility, center CTA presence, regular tab active state, and Calendar CTA active state.

FIX 02 inspected the recovered compact CTA prototype at:

`/Users/dqdatt/Desktop/TaskManagementApp/creativehub_ios_prototype_cta_calendar_compact(1).html`

The bottom navigation was adjusted to match the compact prototype geometry: 12pt side inset, 72pt bar height, 27pt radius, 5pt/4pt internal vertical padding, full-column regular liquid pill, 58pt center Calendar CTA, 3pt CTA border, compact shadow, and no extra bubble/gloss/orb/ghost-circle layer.

FIX 04 corrected the reusable shell glass treatment after screenshot review showed the topbar and bottom navbar rendering too gray. `CHGlassSurface` now uses the approved bright translucent white gradients as the visual base, with low-opacity native material retained only for frost/depth, plus subtle white stroke/highlight and soft shadows.

## Known Differences From HTML Prototype

- Phase 1 placeholder screen content is intentionally not the real feature UI.
- The topbar/avatar uses the current logo in the avatar slot for shell validation only; real profile avatar loading comes later.

## Bundle Identifier / Signing

No approved production bundle identifier was found.

Current bundle ID:

`com.local.CreativeHub.dev`

This is development-only for simulator validation. It is not a production App Store/TestFlight identity.

## Validation

- `xcodebuild -list`: passed
- Simulator build: passed
- FIX 02 simulator build: passed on iPhone 16 Pro
- FIX 02 full test suite: passed, 10 tests
- FIX 02 screenshot UI tests: passed and wrote 5 snapshots
- FIX 04 simulator build: passed on iPhone 16 Pro
- FIX 04 full test suite: passed, 10 tests
- FIX 04 screenshot UI tests: passed and rewrote 5 snapshots

## Remaining Blockers

- Provide approved production bundle identifier and Apple signing team before release work.
- Phase 2 must replace temporary authenticated startup with real Supabase session restore and login.
