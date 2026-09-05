# Phase 3 - App Shell Navigation

## Scope

Phase 3 refines the authenticated native iOS shell only. It keeps the Phase 1 compact bottom navigation and Phase 2 auth/system states, and does not introduce Phase 4 business content.

Backend touched: None.

## Source Priority

1. `PHASE3_APP_SHELL_REFINEMENT_NAVIGATION_PACKAGE/creativehub_ios_prototype_cta_calendar_compact.html`
2. `PHASE3_APP_SHELL_REFINEMENT_NAVIGATION_PACKAGE/creativehub_ios_prototype_complete_states(2).html` for shared visual language only

## Implemented

- Main tab order remains `Tổng quan | Video | Calendar CTA | Content | Thành viên`.
- Overview uses greeting topbar mode with no leading `...` action.
- Video, Calendar, Content, and Members use main topbar mode with isolated tool reveal state.
- Notifications and Profile are secondary routes with Back-only topbar and hidden bottom navigation.
- Secondary Back restores the originating tab instead of resetting to Overview.
- Main tabs behave as peer roots; tapping the current tab does not push duplicate routes.
- Added a reusable full-screen module scaffold with Back-only topbar, hidden navbar, and typed module route context.
- Toasts now render near the bottom, above the visible navbar/CTA and near the safe bottom when the navbar is hidden.
- Accessibility identifiers cover topbar actions, navbar tabs, secondary/module back, and tool reveal state.

## Verification

Build:

```sh
xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData build
```

Result: succeeded.

Tests:

```sh
xcodebuild -project ios/CreativeHub/CreativeHub.xcodeproj -scheme CreativeHub -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/CreativeHub/DerivedData -parallel-testing-enabled NO test
```

Result: succeeded, 32 app/unit tests and 8 UI tests.

## Screenshots

Generated in `ios/CreativeHub/QA/Snapshots/`:

- `phase3-01-overview-shell.png`
- `phase3-02-video-tools-closed.png`
- `phase3-03-video-tools-open.png`
- `phase3-04-calendar-selected.png`
- `phase3-05-notifications-from-video.png`
- `phase3-06-restored-video.png`
- `phase3-07-profile-from-calendar.png`
- `phase3-08-module-open.png`
- `phase3-09-module-restored.png`
- `phase3-10-toast-navbar-visible.png`
- `phase3-fix01-01-video-title.png`
- `phase3-fix01-02-profile-shell-placeholder.png`
- `phase3-fix01-03-toast-navbar-visible.png`
- `phase3-fix01-04-toast-navbar-hidden.png`
- `phase3-fix01-05-restored-calendar.png`

## FIX 01 Acceptance

- Compact source priority verified against `creativehub_ios_prototype_cta_calendar_compact.html`; toast rule is `.toast` with `background: rgba(24,31,49,.90)`, `padding: 10px 14px`, `font-size: 12px`, `backdrop-filter: blur(10px)`, hidden `translateY(20px)`, and `.25s` transition.
- Shared native toast now renders as an iconless charcoal capsule with white text, 10/14 padding, 12pt semibold text, bottom padding 96 when navbar is visible, and bottom padding 20 when navbar is hidden or unauthenticated.
- Video topbar title is `Video tháng`; bottom navigation label remains `Video`.
- Profile secondary route renders only the shell placeholder: `Hồ sơ cá nhân` / `Hồ sơ sẽ hiển thị tại đây.`
- The forbidden fake identity `dat@creativehub.local` is not used by the app. The DEBUG launch fixture uses `QA User` / `qa@example.test`, and Profile UI tests assert `Dat` and `dat@creativehub.local` are absent.
- `Module kiểm thử`, `Nguồn: ...`, and `Nhập thử` are available only when `#if DEBUG` and `CREATIVEHUB_PHASE3_QA_HARNESS=1`; normal UI launch does not expose `module.open-test`.
- Notifications placeholder copy is `Thông báo sẽ hiển thị tại đây.`

## Notes

SwiftUI may keep recently removed navbar elements in the accessibility snapshot briefly during overlay transitions; acceptance checks assert route restoration and tappability while the rendered navbar is hidden by route state and transition.
