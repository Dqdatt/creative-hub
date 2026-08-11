# Phase 4.5 Real Device QA Checklist

Generated: 2026-08-09 Asia/Ho_Chi_Minh

Status: BLOCKED. No physical iPhone/iPad was detected during Phase 4.5.

Expected project: `ios/CreativeHubOps/CreativeHubOps.xcodeproj`.

Screenshots should be saved under `ios/CreativeHubOps/QA/phase4_5/device/` when a real device is available. Avoid screenshots containing passwords, reset links, private tokens, or sensitive production user data.

## Device Checklist

| Workflow | Tested | Result | Notes |
| --- | --- | --- | --- |
| Physical device detection | No | Blocked | `xcrun xctrace list devices` showed Mac and simulators only. |
| Xcode destination shows real iPhone/iPad | No | Blocked | `xcodebuild -showdestinations` showed simulator/generic destinations only. |
| Signed install from Xcode | No | Blocked | Requires production Bundle ID, Apple Developer Team, provisioning, and connected device. |
| First launch / LaunchScreen | No | Blocked | Verify no black letterbox, no splash hang, correct app icon/name. |
| Safe area and bottom navigation | No | Blocked | Verify not clipped on notch/Dynamic Island/home indicator devices. |
| Portrait orientation on iPhone | No | Blocked | Confirm app remains portrait as configured. |
| iPad portrait/upside-down behavior | No | Blocked | Confirm iPad orientation behavior matches `Info.plist`. |
| Login with real account | No | Blocked | Requires safe test account. |
| Session restore after force quit | No | Blocked | Requires safe test account. |
| Logout then login with another account | No | Blocked | Verify scoped data clears between accounts. |
| Dashboard data load | No | Blocked | Verify KPI cards, monthly progress, upcoming shoots, and scrolling. |
| Video Tasks list | No | Blocked | Verify search/filter/list density and empty/loading/error states. |
| Video Task detail | No | Blocked | Verify read-only detail, linked Content Plan navigation, status actions, edit, delete confirmation. |
| Video Task create/edit/delete | No | Blocked | Use safe staging/test data only. |
| Calendar month navigation | No | Blocked | Verify previous/next month, agenda rows, missing time display, and detail navigation. |
| Shoot detail/create/edit/delete | No | Blocked | Use safe staging/test data only. |
| Content Plan list/detail | No | Blocked | Verify category/status filtering, linked task awareness, and detail navigation. |
| Content Plan create/edit/assign/delete | No | Blocked | Use safe staging/test data only. |
| Profile edit | No | Blocked | Verify form validation and save recovery. |
| Avatar upload with PhotosPicker | No | Blocked | Verify permission sheet behavior, image compression, upload, and avatar refresh. |
| Password update | No | Blocked | Use safe account only. Do not test on production personal account. |
| Notifications list | No | Blocked | Verify unread count, mark read, mark all read, and destination routing. |
| Notification realtime | No | Blocked | Requires two safe accounts or server-triggered notification event. |
| Background / foreground reconnect | No | Blocked | Verify data does not duplicate and realtime reconnects cleanly. |
| Airplane mode / offline behavior | No | Blocked | Verify failures show inline errors and forms retain entered values. |
| Wi-Fi to cellular/network change | No | Blocked | Verify reload/retry paths recover without stale UI. |
| Keyboard and sheets | No | Blocked | Verify keyboard does not cover required inputs/actions. |
| Text clipping and Dynamic Type | No | Blocked | Test default, large, and extra-large text sizes. |
| Light theme consistency | No | Blocked | Dark mode is temporarily forced light; verify surfaces remain readable. |
| Account switch isolation | No | Blocked | Login A, load data, logout, login B, verify no stale A state. |

## How To Close This Checklist

1. Open `ios/CreativeHubOps/CreativeHubOps.xcodeproj` in Xcode.
2. Replace the placeholder Bundle ID only after the production Bundle Identifier is provided.
3. Select the correct Apple Developer Team in Signing & Capabilities.
4. Connect a trusted physical iPhone/iPad.
5. Run the app from Xcode on the device.
6. Execute each row above with safe admin and non-admin accounts.
7. Save non-sensitive screenshots under `ios/CreativeHubOps/QA/phase4_5/device/`.
8. Update each row from `Blocked` to `Pass` or `Fail` with device model, iOS version, account role, and notes.

## Phase 4.6 — Final Release Blocker Closure

Generated: 2026-08-09 Asia/Ho_Chi_Minh

Real-device available: NO.

| Check | Result | Evidence | Remaining Action |
| --- | --- | --- | --- |
| Physical iPhone/iPad detection | Blocked | `xcrun xctrace list devices` listed only the Mac and simulators. | Connect/trust a physical iPhone/iPad. |
| Xcode physical destination | Blocked | `xcodebuild -showdestinations` listed generic iOS placeholder and simulators only. | Re-run after device is connected and trusted. |
| Debug install to device | Blocked | No physical destination, Bundle ID still placeholder, Team missing. | Provide Bundle ID, select Team, connect device. |
| Signed Release build to device | Blocked | Signing prerequisites incomplete. | Run only after Debug device build passes. |
| Archive readiness | Blocked | Archive was not attempted. | Attempt only after signed Release device build passes. |

Minimum Phase 4.6 device QA remains untested: cold launch, background/foreground, kill/relaunch, session restore, login/logout/login, Dashboard load/scroll/refresh, Tasks CRUD, Calendar navigation and Shoot CRUD, Content Plan CRUD, Profile avatar upload/persistence, Notifications mark-read/realtime, and Account Switch A to B cleanup.

NOT READY FOR PHASE 5
