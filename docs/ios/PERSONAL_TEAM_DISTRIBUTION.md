# CreativeHub Personal Team Distribution

## Scope

This flow is for Personal Team sideload testing only. It is not App Store distribution and does not enable real APNs remote push. CreativeHub currently uses in-app Supabase notifications; Remote Push Notifications remain deferred until an Apple Developer Program setup is available.

## Build

Build the app from Xcode to a connected iPhone first, or run:

```bash
xcodebuild \
  -project ios/CreativeHub/CreativeHub.xcodeproj \
  -scheme CreativeHub \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ios/CreativeHub/DerivedData \
  build
```

Keep signing automatic with the Personal Team and do not add the Push Notifications capability.

## Package IPA

Package the latest local iPhoneOS app build:

```bash
scripts/package-personal-team-ipa.sh
```

Or pass an explicit app bundle:

```bash
scripts/package-personal-team-ipa.sh ios/CreativeHub/DerivedData/Build/Products/Debug-iphoneos/CreativeHub.app
```

The output is:

```text
ios/CreativeHub/BuildArtifacts/CreativeHub-PersonalTeam.ipa
```

The script copies the built app into a temporary `Payload/CreativeHub.app` folder and zips it. It does not modify the source app and does not embed credentials or provisioning secrets. SideStore handles its own re-signing during sideload.

## SideStore Install

SideStore requires initial computer setup and device pairing. After SideStore is correctly configured, install the CreativeHub IPA from SideStore and complete iOS trust or Developer Mode prompts if they appear.

Apple free signing remains time-limited. Open SideStore periodically and refresh CreativeHub before the signing window expires. A cable is not needed for each normal SideStore refresh after SideStore is correctly configured.

Rebuild or repackage CreativeHub only when code changes or a new version needs to be installed.

## When Computer Setup May Be Needed Again

- The pairing file is invalidated.
- A major iOS update or device reset changes trust/pairing state.
- SideStore installation breaks.
- A new IPA/version needs to be produced.
- Signing account or device configuration changes.

## Personal Team Notes

- Push Notifications capability is not required.
- `aps-environment` is not required.
- The app should not request remote notification permission.
- The app should not register APNs device tokens.
- In-app notification unread state refreshes while the authenticated app is active.
