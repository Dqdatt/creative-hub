# Phase 4 - Overview

Phase 4 replaces the native Overview placeholder with the production dashboard surface derived from the approved compact HTML prototype.

## Sources

- Prototype: `/Users/dqdatt/Desktop/TaskManagementApp/PHASE4_OVERVIEW_PACKAGE/creativehub_ios_prototype_cta_calendar_compact.html`
- Web dashboard semantics: `src/services/dashboardService.ts`, `src/hooks/useDashboard.ts`, `src/services/tasksService.ts`, `src/services/shootsService.ts`, `src/services/contentPlanService.ts`
- Backend mapping: `docs/ios/IOS_BACKEND_MAPPING.md`

## Data Sources

The production native provider is read-only and uses the signed-in Supabase client. It does not use service-role credentials and does not write fixture data.

- `video_tasks`: monthly video rows and status/order/editor fields
- embedded `content_plan`: linked `air_date` override
- embedded `profiles`: task editor metadata
- `shoots`: shoot rows bounded by month
- `shoot_editors` + embedded `profiles`: shoot editor metadata
- `profiles`: editor-member roster, names, colors, avatars

Pagination uses 1,000-row ranges and continues until a page returns fewer than 1,000 records, avoiding silent truncation at the default PostgREST page size.

## Semantics

- Dashboard month: current local calendar month unless the DEBUG QA month override is set.
- Monthly task membership: effective air date, where linked `content_plan.air_date` wins over `video_tasks.air_date`.
- Completed status: exact Vietnamese status `Đã xong`.
- Total videos: count of tasks whose effective air date is in the dashboard month.
- Completed: count of monthly tasks with status `Đã xong`.
- Remaining: total videos minus completed videos, clamped at zero.
- Shoots: count of `shoots` in month excluding `livestream`.
- Team Order: groups monthly videos by uppercased `order_team`, sorted by count descending with web order-team priority as tie-breaker.
- Editor workload: tasks assigned to an editor plus non-livestream shoots assigned to the editor by profile id or editor code.
- Mini-bars: five calendar buckets derived from real task effective air dates and shoot dates.
- Chart: cumulative completed-video count by effective air date across the month.
- Shoot load track: neutral visual track because no verified denominator exists in the web/backend mapping.
- Date handling: ISO `yyyy-MM-dd` strings are compared inside `OverviewMonth` boundaries generated with the app business calendar.

## Data Semantics Trace

| Metric | Source fields | Source code/web evidence | Existing semantic vs native derivation | Formula |
|---|---|---|---|---|
| Monthly video membership | `video_tasks.air_date`, `video_tasks.content_plan_id`, linked `content_plan.air_date` | `src/services/tasksService.ts`: `getEffectiveAirDate(row)` returns linked `content_plan.air_date` when `content_plan_id` and row exist, otherwise `video_tasks.air_date`; `fetchVideoTasks(monthValue)` filters by that effective date. `docs/ios/IOS_BACKEND_MAPPING.md` Dashboard row says tasks are filtered by effective air date. | Verified existing product semantic. Tasks without an effective air date are excluded from the month. If task and linked plan dates disagree, linked `content_plan.air_date` wins. | `effectiveAirDate = linkedAirDate ?? airDate`; include when `startISODate...endISODate` contains it. |
| Completed | `video_tasks.status` | `src/types/task.ts` defines `TaskStatus = 'Chờ' | 'Đang làm' | 'Đã xong'`; `src/hooks/useDashboard.ts` counts `task.status === 'Đã xong'`; `docs/ios/IOS_BACKEND_MAPPING.md` lists the same status values. | Verified existing product semantic. No fuzzy matching. | `completedVideos = monthTasks.filter(status == "Đã xong").count` |
| Remaining | `totalVideos`, `completedVideos` | `src/hooks/useDashboard.ts` exposes `totalVideos` and `doneVideos`; the compact prototype has the `Còn lại` card. Existing web dashboard does not name a separate remaining formula. | Truthful native client derivation. It does not conflict with web metrics because it derives directly from existing total/done counts. | `remainingVideos = max(0, totalVideos - completedVideos)` |
| Lịch quay | `shoots.shoot_date`, `shoots.shoot_type` | `src/hooks/useDashboard.ts` computes `countedShoots = shoots.filter((shoot) => shoot.type !== 'livestream')`; `src/types/shoot.ts` defines `ShootType`; `src/data/shoots.ts` labels `livestream`, `lichquay`, `onset`, `other`; `docs/ios/IOS_BACKEND_MAPPING.md` lists `shoot_type` values and shoot-load fields. | Verified existing dashboard predicate for excluding livestream. The native compact label remains the approved Overview label. | `shootCount = monthShoots.filter(type != "livestream").count` |
| Team Order | `video_tasks.order_team` | `src/services/tasksService.ts` selects/maps `order_team` to `VideoTask.orderTeam`; `src/components/dashboard/TeamOrderTable.tsx` groups tasks by `ORDER_TEAMS` and filters active groups; `src/data/tasks.ts` defines known `ORDER_TEAMS`. | Grouping by order team is verified. Uppercase normalization and preservation of extra real groups are native presentation/data-safety rules. Ordering is a presentation rule: count descending with `ORDER_TEAMS` priority as tie-breaker. | Group non-empty `order_team.uppercased()`, preserve all groups, sort count desc then priority then alpha. |
| Editor workload count | `video_tasks.editor_id`/profile `editor_code`, `shoot_editors.profile_id`, shoot editor profile `editor_code`, `shoots.shoot_type` | `src/components/dashboard/EditorWorkload.tsx` computes `editorTasks`, non-livestream `editorShoots`, and `totalTasks = editorTasks.length + editorShoots.length`; label is `tổng task`. `src/services/shootsService.ts` maps `shoot_editors.profile_id` and profile `editor_code`. | Verified existing product semantic for workload total. Native compact label `task` is visually shorter than web `tổng task` but represents the same count. | `taskCount = assignedVideoTasks.count + assignedNonLivestreamShoots.count` |
| Mini bars | effective task air date, `shoots.shoot_date` | No exact five-bar web metric exists. Existing workload contributors and dates are verified by `EditorWorkload.tsx`, `tasksService.ts`, and `shootsService.ts`. | Truthful native client derivation for compact visualization. | Split the month into five equal day buckets; count each editor's assigned videos by effective air date plus assigned non-livestream shoots by shoot date. Bar heights normalize against that editor's max bucket. |
| Chart | completed task effective air date | `src/hooks/useDashboard.ts` verifies completed count; `tasksService.ts` verifies effective air date. No existing web dashboard line chart semantic exists. Completion timestamp is not fetched for dashboard rows. | Truthful native client derivation. It is not a completed-at timeline; it places currently completed tasks on their effective air dates and accumulates by day. If a task is completed after air date, it still appears on its air date because no completion timestamp is available. | For each day, add completed tasks whose effective air date is that day; cumulative running total across month. |
| Completion | `completedVideos`, `totalVideos` | `src/hooks/useDashboard.ts` computes `completionRate = totalVideos ? Math.round((doneVideos / totalVideos) * 100) : 0`. | Verified existing product semantic. | `completionRatio = completedVideos / totalVideos`, zero when total is zero. |
| Shoot load | `shootCount` | `docs/ios/IOS_BACKEND_MAPPING.md` documents source fields but no target/capacity denominator. Web dashboard has count only for shoot load; no verified denominator was found. | Product denominator not defined; native renders count and a base neutral track only. | `value = shootCount`; `track.fillRatio = nil` when denominator is absent. |

## States

- Loading uses the shared native state view.
- Load errors show a retry action; refresh failures keep stale dashboard data visible with an inline error.
- Zero data renders truthful zero counts, an empty Team Order track, empty workload copy, and safe `0%` completion.

## Fixture Isolation

Phase 4 visual fixtures are compiled only under `DEBUG` and are selected only by `CREATIVEHUB_PHASE4_OVERVIEW_FIXTURE`.

Supported DEBUG fixture values:

- `visual`
- `zero`
- `error`

Production launches default to `OverviewSupabaseRepository`.

## Verification

- Required build command passed.
- Full `xcodebuild test` passed on iPhone 16 Pro simulator.
- Phase 4 screenshots were generated in `ios/CreativeHub/QA/Snapshots`.
