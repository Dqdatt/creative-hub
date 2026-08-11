# Mockup Verification Notes

- Date: `2026-08-06`
- Viewport: `393 x 852`
- Method: Vite local server + Google Chrome headless screenshot.
- Captured files:
  - `dashboard.png`
  - `tasks.png`
  - `calendar.png`
  - `profile.png`
  - `quick-create-task.png`
  - `login.png`

## Verified Visual Tokens

- Background: light blue-gray surface close to `#E8EBF2` / `#EAECF5`.
- Cards: white surfaces with subtle border and soft shadow.
- Topbar: compact, centered title/subtitle, circular logo/action buttons.
- Bottom navigation: floating rounded white bar, compact labels, selected item in purple.
- Modal/sheet: bottom sheet with dim backdrop and rounded top corners.
- Search: light filled search field with roughly `14pt` radius.
- Card radius: mostly `16-26pt` depending on component hierarchy.
- Primary accent: `#7C5CFF`.

## Limits

Chrome rendered the standalone `ios-prototype.html` artifact for live capture. The React prototype source under `src/ios-prototype` also exists and was source-audited, but its `IOSBottomNav.tsx` differs from the standalone mockup. The native app follows the Phase 2 navigation requirement explicitly stated in the approval brief:

`Tổng quan`, `Video`, center `+`, `Lịch quay`, `Cá nhân`.

`Content Plan` and `Nhân sự` are implemented as secondary routes, guarded by permissions, not as bottom tabs.

## Font

The webapp imports `Plus Jakarta Sans` from Google Fonts in `index.html`. No `.ttf`, `.otf`, `.woff`, or `.woff2` font files exist in the repository. The iOS app uses the system font fallback until a licensed local font file is provided.

## Dark Mode

The webapp has a `ThemeProvider` and `html.dark` token overrides. The iOS app includes native light/dark color assets in code, but does not invent 2FA or push notification behavior.
