# Phase 3C Interaction Audit

Generated: 2026-08-08 Asia/Ho_Chi_Minh

| Tap target | Expected destination | Current implementation | Missing UI |
| --- | --- | --- | --- |
| Dashboard KPI | Read-only unless webapp drill-down is confirmed | Read-only | None |
| Dashboard upcoming task | Task Detail | Pushes `AppRoute.taskDetail(id)` | None |
| Dashboard upcoming shoot | Shoot Detail | Pushes `AppRoute.shootDetail(id)` | None |
| Task card | Task Detail | Pushes `AppRoute.taskDetail(id)` | None |
| Task Detail edit | Edit sheet | Opens `AppSheet.taskEdit` | None |
| Task Detail delete | Confirmation then RPC delete | Confirmation dialog then `delete_video_task_with_notifications` flow | None |
| Task Detail status | Status action menu | Manual tasks can update status; linked task status RPCs are shown as backend pending | Linked task status RPC completion remains Phase 3B |
| Task linked Content Plan | Content Plan Detail | Pushes `AppRoute.contentPlanDetail(id)` when linked item is loaded | Cross-month linked item fetch is not implemented |
| Calendar agenda item | Shoot Detail | Pushes `AppRoute.shootDetail(id)` | None |
| Shoot Detail edit | Edit sheet | Opens `AppSheet.shootEdit` | None |
| Shoot Detail delete | Confirmation then RPC delete | Confirmation dialog then `delete_shoot_with_notifications` flow | None |
| Content Plan item | Content Plan Detail | Pushes `AppRoute.contentPlanDetail(id)` | None |
| Content Plan Detail edit/assign | Edit sheet | Opens `AppSheet.contentPlanEdit` | None |
| Content Plan Detail delete | Confirmation then RPC delete | Confirmation dialog then `delete_content_plan_with_notifications` flow | None |
| Content Plan linked task | Task Detail | Pushes `AppRoute.taskDetail(id)` when linked task is loaded | Cross-month linked task fetch is not implemented |
| Users item | User Detail | Pushes `AppRoute.userDetail(id)` for loaded editor profiles | Full admin Edge Function modification remains Phase 3B |
| Notification item | Entity detail destination | Marks read, then routes by `entity_type` and `entity_id` | Unsupported entity types remain read-only |
| Profile actions | Profile/password sheets, workspace routes | Existing sheet/navigation flow retained | Avatar upload remains Phase 3B |
| Center quick create | Task create sheet | Existing Task create flow retained | None |

Screenshot note: Detail screenshots require authenticated local data for Task, Shoot, Content Plan, and User records. The Phase 3C build/test verification covers compile and launch; screenshots should be captured from Xcode once seeded Supabase data is available in the simulator session.
