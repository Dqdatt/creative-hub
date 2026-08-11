# Phase 4.5 Role And Permission Matrix

Generated: 2026-08-09 Asia/Ho_Chi_Minh

Status: BLOCKED / NOT VERIFIED with real accounts.

No safe admin and non-admin credentials/accounts were provided or discoverable in the local project. This file documents the expected matrix and the exact verification gaps. Do not use private production personal accounts for destructive tests.

## Client Permission Source

Native role mapping from `PermissionService`:

| Role | Expected Client Permissions |
| --- | --- |
| `admin` | All permissions, including user management. |
| `creative_manager` | Dashboard, video task CRUD, shoot CRUD, content plan view/assign, self profile edit. |
| `content_creator` | Shoot CRUD, content plan CRUD, self profile edit. |
| `editor` | Dashboard, video task CRUD, shoot view, content plan view, self profile edit. |
| `team_lead` | Normalized to `creative_manager`. |
| View-only override | Removes mutation/admin/profile-edit permissions. |
| Custom override | Enables/disables individual feature flags; user management remains admin-only. |

Client unit tests passed for permission mapping, view-only overrides, custom overrides, account-switch clearing, linked task transitions, and mutation guards. Server-side RLS and Edge Function authorization still require real role accounts.

## Required Accounts

| Account | Required | Status | Notes |
| --- | --- | --- | --- |
| Safe admin account | Yes | Missing | Needed for user management, Edge Function success paths, admin-only UI, and destructive staging operations. |
| Safe non-admin account | Yes | Missing | Needed to verify admin denial, restricted UI, RLS isolation, and account-switch clearing. |
| Optional editor/content creator account | Recommended | Missing | Needed to verify assigned-editor linked task flows on real backend data. |

## Verification Matrix

| Operation | Non-admin | Admin | Backend Enforced | Result |
| --- | --- | --- | --- | --- |
| Login and load profile/permissions | Not verified | Not verified | Not verified | Blocked by missing accounts. |
| Dashboard visibility | Not verified | Not verified | Not verified | Client permission tests pass; real account behavior pending. |
| Admin Users screen access | Not verified | Not verified | Not verified | Must verify non-admin cannot access and admin can access. |
| `create-user` Edge Function success | Not applicable | Not verified | Not verified | Function rejects no-auth/anon-auth; admin success pending. |
| `create-user` Edge Function non-admin denial | Not verified | Not applicable | Not verified | Requires safe non-admin token. |
| `manage-user` reset/update/delete success | Not applicable | Not verified | Not verified | Function is reachable; admin success pending. |
| `manage-user` non-admin denial | Not verified | Not applicable | Not verified | Requires safe non-admin token. |
| Video task create/update/delete | Not verified | Not verified | Not verified | Requires safe staging data. |
| Video task read isolation | Not verified | Not verified | Not verified | Requires role-scoped authenticated reads. |
| Linked task accept/update/complete | Not verified | Not verified | Not verified | Requires assigned editor/content plan fixture. |
| Shoot create/update/delete | Not verified | Not verified | Not verified | Requires safe staging data. |
| Shoot read isolation | Not verified | Not verified | Not verified | Requires role-scoped authenticated reads. |
| Content Plan create/update/delete | Not verified | Not verified | Not verified | Requires safe staging data. |
| Content Plan assign editor | Not verified | Not verified | Not verified | Requires safe admin/manager/editor accounts. |
| Profile edit self | Not verified | Not verified | Not verified | Requires safe accounts. |
| Profile edit other user | Not verified | Not verified | Not verified | Must verify non-admin denial and admin behavior if supported. |
| Avatar upload own path | Not verified | Not verified | Not verified | Requires safe account and Storage policy verification. |
| Notifications read/mark-read | Not verified | Not verified | Not verified | Requires safe notification fixtures. |
| Notification realtime recipient isolation | Not verified | Not verified | Not verified | Requires two safe accounts or server-triggered events. |
| Account switch A to B state clearing | Not verified | Not verified | Not verified | Unit tests pass; real Keychain/session behavior pending. |
| Password update self | Not verified | Not verified | Not verified | Requires safe accounts only. |

## Non-Destructive Backend Checks Already Completed

| Check | Result |
| --- | --- |
| `create-user` `OPTIONS` | 204 |
| `create-user` POST without auth | 401 |
| `create-user` POST invalid auth | 401 |
| `create-user` POST anon auth | 401 |
| `manage-user` `OPTIONS` | 204 |
| `manage-user` POST without auth | 401 |
| `manage-user` POST anon auth with fake reset payload | 400 with structured error keys |
| Anon REST reads for core tables | No rows exposed in Phase 4.5 checks |

## Closure Criteria

- Verify every matrix row with a safe admin account.
- Verify every matrix row with at least one safe non-admin account.
- Confirm non-admin users cannot perform admin-only Edge Function operations.
- Confirm account switching clears previous account data on a physical device.
- Record account role, device model, iOS version, result, and evidence screenshot/log note for each row.

## Phase 4.6 — Final Release Blocker Closure

Generated: 2026-08-09 Asia/Ho_Chi_Minh

Status: BLOCKED / NOT VERIFIED. Safe admin and non-admin accounts were not provided during Phase 4.6, so no password, credential, or destructive test flow was stored or executed.

| Operation | Non-admin UI | Non-admin Backend | Admin UI | Admin Backend | Result |
| --- | --- | --- | --- | --- | --- |
| View Users route | Not verified | Not verified | Not verified | Not verified | Blocked by missing accounts. |
| Create user | Not verified | Not verified | Not verified | Not verified | Edge Function rejects no-auth/anon; real roles pending. |
| Manage user | Not verified | Not verified | Not verified | Not verified | Edge Function rejects no-auth/anon; real roles pending. |
| Permission override | Not verified | Not verified | Not verified | Not verified | Requires safe admin and target user. |
| Task create/edit/delete by role | Not verified | Not verified | Not verified | Not verified | Requires safe staging/test data. |
| Shoot create/edit/delete by role | Not verified | Not verified | Not verified | Not verified | Requires safe staging/test data. |
| Content Plan operations | Not verified | Not verified | Not verified | Not verified | Requires safe staging/test data. |
| Notifications read/mark read | Not verified | Not verified | Not verified | Not verified | Requires notification fixtures or safe workflow. |
| Profile self-edit | Not verified | Not verified | Not verified | Not verified | Requires safe accounts. |
| Avatar upload own object | Not verified | Not verified | Not verified | Not verified | Requires safe accounts and device PhotosPicker QA. |
| Avatar overwrite other user object | Not verified | Not verified | Not applicable | Not verified | Requires safe non-admin token and separate target object. |
| Realtime recipient isolation | Not verified | Not verified | Not verified | Not verified | Requires two safe accounts or a server-triggered safe notification. |
| Account switch state cleanup | Not verified | Not verified | Not verified | Not verified | Requires Admin A to Non-admin B device QA. |

Phase 4.6 non-destructive backend boundary checks:

| Function | No-auth | Anon-auth | Admin | Non-admin |
| --- | --- | --- | --- | --- |
| `create-user` | 401 | 401 | Not verified | Not verified |
| `manage-user` | 401 | 400 structured rejection | Not verified | Not verified |

NOT READY FOR PHASE 5
