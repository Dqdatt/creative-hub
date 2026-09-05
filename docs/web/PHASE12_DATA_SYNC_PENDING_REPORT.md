# Phase 12 - Web Data Sync, Pending Status, Admin Report

## Scope

Phase 12 is web/backend only. Native iOS is intentionally untouched.

## Verified Data Contract

Canonical Content Plan membership is `video_tasks.content_plan_id -> content_plan.id`.

Canonical date fields remain unchanged:

- Video Tasks month membership: effective air date, using linked `content_plan.air_date` when `content_plan_id` is present, otherwise `video_tasks.air_date`.
- Content Plan: `content_plan.air_date`.
- Dashboard report month: same Video Task effective month loaded by `fetchVideoTasks(monthValue)` plus shoot data loaded by `fetchShoots(startDate, endDate)`.

## Canonical Field Ownership

Shared between linked Video Task and Content Plan:

- `note`: `content_plan.note` and `video_tasks.notes`.
- Result link: `content_plan.link` and `video_tasks.result_link`.
- Task status: canonical value remains `video_tasks.status`; Content Plan reads the linked task status for display.
- Linked task identity: `video_tasks.content_plan_id`.

Video-only:

- `receive_date`
- `return_date`
- `priority`
- `resize_reqs`
- `order_team`

Content-only:

- `content_plan.title`
- `content_plan.category`
- `content_plan.air_date`
- Planning ownership for `editor_id` remains the existing Content Plan assignment workflow.

## Backend Contract

Migration:

- `supabase/phase12_video_content_sync_pending_report.sql`

The migration:

- Adds `Pending` to `video_tasks.status`.
- Sets `video_tasks.status` default to `Pending`.
- Normalizes linked tasks created with legacy `Chờ` to `Pending`.
- Keeps legacy `Chờ` accepted for existing/manual compatibility.
- Removes the previous admin-only direct linked override behavior from the guard.
- Adds `sync_linked_video_task_from_video_month(...)` as the atomic linked update path.
- Updates `accept_linked_video_task(...)` to accept `Pending` and legacy `Chờ`.

The new sync RPC is `security definer`, but it authorizes against the authenticated actor:

- `admin`
- `creative_manager`
- `content_creator`
- `team_lead` compatibility
- assigned editor for that linked task

The frontend never uses service-role credentials.

## Web Behavior

Video Tasks:

- Pending status appears in filters, modal, table, and status badge.
- Linked task generic saves call `sync_linked_video_task_from_video_month`.
- Direct partial admin update followed by separate admin completion sync is no longer used.
- Accept flow still supports old `Chờ` rows and new `Pending` rows.

Content Plan:

- Fetch now includes linked task `id`, `status`, and `result_link`.
- Table displays linked task status.
- Result link display uses the linked task result link when present, falling back to `content_plan.link`.
- Realtime subscription listens to both `content_plan` and `video_tasks`.

Dashboard:

- Adds a `Cần chú ý` card for Pending, overdue, and done-without-link counts.
- Clicks route to Video Tasks with query filters where available.
- Adds Admin Report setup + preview modal.
- Report is generated from monthly task/shoot/editor data, not from dashboard screenshots.
- PDF export uses a dedicated A4 print layout and browser save-to-PDF flow because the project has no PDF-generation dependency installed.

## Security Review

- No iOS files changed for this phase.
- No service-role key introduced.
- No raw database errors surfaced intentionally; existing service mappers convert known backend messages to Vietnamese user-safe copy.
- The new RPC keeps linked Video Task and Content Plan updates atomic.
- RLS remains active; the RPC performs explicit authenticated-user authorization before mutating data.

## QA Notes

Automated checks run locally:

- `npm run build`
- `npm run lint`

Screenshot QA and role-matrix QA require a running Supabase dataset with admin, creative_manager, content_creator, and editor users.
