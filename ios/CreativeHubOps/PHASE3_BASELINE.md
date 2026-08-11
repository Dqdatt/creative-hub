# Phase 3 Baseline

Generated: 2026-08-07 Asia/Ho_Chi_Minh

## Current iOS Runtime State

- ✅ Working: Xcode project, SwiftUI shell, LaunchScreen, official bottom navigation.
- ✅ Working: Supabase config via xcconfig, Supabase Swift SDK, email/password sign-in, session restore, logout.
- ✅ Working: Real read queries for `video_tasks`, `shoots`, and `content_plan`.
- ✅ Working: Loading, empty, and error components exist.
- ✅ Working: Pull to refresh exists through the shared operations store.
- 🟡 Partial: Auth state restores session but does not yet listen to auth state changes.
- 🟡 Partial: Dashboard uses real tasks/shoots but does not yet include editor workload/profile joins.
- 🟡 Partial: Task list has real read/search/filter but no detail/create/edit/delete/status workflow.
- 🟡 Partial: Calendar has real shoot agenda read but no month navigation, event indicators, detail/create/edit/delete workflow.
- 🟡 Partial: Content Plan route has real list read but no detail/create/edit/assignment/delete workflow.
- ❌ UI only: Task create sheet.
- ❌ UI only: Shoot create sheet.
- ❌ UI only: Profile edit sheet.
- ❌ UI only: Password update sheet.
- ❌ UI only: Users route.
- ❌ UI only: Notifications route.
- ❌ Missing: Current user profile store from `profiles`.
- ❌ Missing: Permission override loading from `user_permission_overrides`.
- ❌ Missing: Native shared permission layer matching webapp `src/config/permissions.ts`.
- ❌ Missing: Realtime subscriptions.
- ❌ Missing: Unified domain error model.
