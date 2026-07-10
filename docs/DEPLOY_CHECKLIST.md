# CreativeHub Deploy Checklist

## 1. Supabase Database

Run these SQL files in Supabase SQL Editor, in order:

1. `supabase/setup.sql`
2. `supabase/user_management_patch.sql`
3. `supabase/editor_membership_patch.sql`
4. `supabase/shoot_editors_rls_patch.sql`
5. `supabase/content_plan_schema.sql`
6. `supabase/content_plan_note_patch.sql`
7. `supabase/user_permission_overrides_patch.sql`
8. `supabase/activity_log_schema.sql`

Optional seed data for first setup:

1. `supabase/seed.sql`
2. `supabase/content_plan_seed.sql`

## 2. Supabase Edge Function

The `/users` page creates accounts through `create-user` and manages email/delete operations through `manage-user`.

Required secret:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Deploy:

```bash
supabase functions deploy create-user
supabase functions deploy manage-user
```

Do not put `SUPABASE_SERVICE_ROLE_KEY` in Vercel or any frontend `.env` file.

## 3. Avatar Storage

Create a Supabase Storage bucket:

- Bucket name: `avatars`
- Recommended visibility: public read

Policies needed:

- Authenticated users can upload/update their own avatar path.
- Authenticated users can read avatar files.
- Users can remove their own avatar file.

## 4. Vercel Environment Variables

Add these in Vercel Project Settings:

```bash
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-or-publishable-key
```

Do not add service role keys to Vercel.

## 5. Vercel Build Settings

- Framework preset: Vite
- Build command: `npm run build`
- Output directory: `dist`
- Install command: `npm install`

The repo includes `vercel.json` to route all paths back to `index.html` for React Router.

## 6. Manual Smoke Test After Deploy

1. Open `/login` and sign in as admin.
2. Open `/dashboard` and confirm KPI cards load.
3. Open `/tasks`, create or edit one video task, then refresh.
4. Open `/calendar`, create or edit one shoot, assign an editor, then refresh.
5. Open `/content-plan`, edit a row according to role permissions.
6. Open `/users`, create a test editor account.
7. Edit that member email and confirm they can log in with the new email.
8. Delete a test member and confirm the account disappears from Auth and `public.profiles`.
9. Open `/profile`, update profile fields and test avatar upload.
10. Toggle dark mode.
11. Open an unknown path and confirm the Vietnamese 404 page appears.
12. Sign in as each role and verify `docs/ROLE_QA_CHECKLIST.md`.
