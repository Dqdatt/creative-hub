# Phase 2 Auth And System States

## Scope

Phase 2 replaces the Phase 1 fake authenticated launch with a real root auth state machine:

- checkingSession
- signedOut
- signingIn
- authenticated
- empty
- offline
- loadError
- forbidden
- sessionExpired

The app no longer renders the shell until the stored Supabase session has been checked and the real profile bootstrap has completed.

## Supabase Auth

Native auth uses the existing Supabase project config from `Info.plist` through `AppConfig` and `SupabaseService`.

- Stored session bootstrap calls `client.auth.session`, which refreshes expired access tokens when a refresh token is present.
- Email/password login calls `client.auth.signIn(email:password:)`.
- Sign-out calls `client.auth.signOut()`.
- Supabase Swift default local auth storage is Keychain-backed on Apple platforms. No auth token is stored in `UserDefaults`.

Invalid credentials are mapped to the required native inline copy:

```text
Email hoặc mật khẩu chưa chính xác.
```

## Profile Bootstrap

The native app mirrors the web `AuthContext` profile query:

```sql
profiles:
id, email, full_name, display_name, short_name, role, avatar_url, department, active, is_active
```

Fallback display-name behavior follows the existing web app:

1. `display_name`
2. `short_name`
3. `full_name`
4. auth metadata `full_name`
5. auth metadata `name`
6. email prefix
7. `Nhân sự`

If a profile is missing or inactive, native signs out and shows the reusable forbidden state.

## Permission Bootstrap

The native app reads the optional existing web permission override table:

```sql
user_permission_overrides:
access_mode,
dashboard_view,
calendar_view,
calendar_edit,
tasks_view,
tasks_edit,
content_plan_view,
content_plan_edit_content,
content_plan_assign_editor,
users_manage,
profile_edit_self
```

If `user_permission_overrides` is missing (`42P01`, `PGRST205`, or equivalent PostgREST table-missing text), native keeps role defaults, matching the web app. There is no separate global iOS-app permission gate in the current backend, so forbidden is implemented as a reusable root state and used only for real profile access denial.

## Network And Errors

`NWPathMonitor` gates bootstrap and sign-in before network calls. Offline retry reruns safe session bootstrap. Backend/profile/permission load failures map to `loadError`. Invalid login stays on the login screen with inline error text.

## Forgot Password

Password recovery: DEFERRED — existing webapp/backend has no approved recovery flow. Login exposes a temporary informational fallback until recovery redirect/callback infrastructure is formally added.

The web login screen contains `Quên mật khẩu?`, but current web behavior only clears auth errors and does not send a reset email. Native therefore does not invent a redirect URL, bundle scheme, associated domain, or Supabase recovery redirect. Tapping `Quên mật khẩu?` shows this native informational fallback without making a backend request, claiming a reset email was sent, clearing fields, or changing auth state:

```text
Khôi phục mật khẩu
Tính năng khôi phục mật khẩu chưa được cấu hình trên hệ thống. Vui lòng liên hệ quản trị viên để được hỗ trợ.
Đã hiểu
```

Release/Auth Hardening prerequisite: configure password-recovery redirect plus native callback handling before production release if password self-service recovery is required.

This is a known deferred feature, not a Phase 2 blocker.

## System-State Back Behavior

Reusable system-state topbars accept an optional real back action. If a caller supplies a valid destination, the approved circular back control is shown and executes that transition. If no valid previous stable destination exists, the topbar preserves its symmetric layout slot but does not expose an enabled fake back button.

Current root states:

- Empty: no root-level previous destination; no enabled back control.
- Load Error: no root-level previous destination; no enabled back control. Retry remains the real action.
- Offline: no root-level previous destination; no enabled back control. Retry remains the real action.
- Forbidden: back control and `Quay lại` both return to Login.
- Session Expired: no topbar; `Đăng nhập lại` returns to Login.

## Screenshot Harness

UI tests can force root states with the debug-only environment variable:

```text
CREATIVEHUB_PHASE2_STATE
```

Supported values:

- login
- login-invalid
- loading
- empty
- load-error
- offline
- forbidden
- session-expired
- authenticated-shell

The harness is isolated to `#if DEBUG` app builds and never contains credentials.
