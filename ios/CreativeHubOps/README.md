# CreativeHubOps iOS

Native SwiftUI app for CreativeHub Ops.

## Configuration

Create local config files from the examples if needed:

- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`

Required variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `BUNDLE_IDENTIFIER`

Only the Supabase URL and publishable anon key belong in the app. Never add a service-role key, database password, JWT secret, or admin token.

## Notes

- Minimum deployment target: iOS 17.
- SwiftUI lifecycle.
- Supabase Swift SDK via Swift Package Manager.
- Auth uses Supabase email/password sign-in. Supabase Swift stores auth session using its default Apple Keychain-backed local storage.
- Dashboard, Video, Lịch quay, and Content Plan read real Supabase tables through the native SDK.
- No WebView wrapper.
- No fake Dynamic Island, fake status bar, fake home indicator, or device frame.
- Push notification is not implemented; the current backend supports internal notifications via Supabase Realtime.
- Plus Jakarta Sans is imported by the webapp from Google Fonts, but no local licensed font file exists in the repo. This app currently uses the iOS system font fallback.

## Verification

Last verified locally on iPhone 16 Pro simulator:

```sh
xcodebuild -project ios/CreativeHubOps/CreativeHubOps.xcodeproj -scheme CreativeHubOps -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/DerivedData build
xcodebuild -project ios/CreativeHubOps/CreativeHubOps.xcodeproj -scheme CreativeHubOps -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath ios/DerivedData test
```

Current suite covers native navigation labels, Supabase config validation, Content Plan production categories, dashboard KPI math, and login screen launch.
