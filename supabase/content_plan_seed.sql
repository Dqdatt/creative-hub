-- ============================================================
-- Video Ops - Content Plan seed
-- Phase 9C: seed dữ liệu mock hiện tại, chưa kết nối CRUD frontend
-- Safe to run nhiều lần sau khi đã chạy:
-- 1. supabase/setup.sql
-- 2. supabase/content_plan_schema.sql
-- ============================================================

do $$
declare
  v_creator_id uuid;
begin
  select p.id
  into v_creator_id
  from public.profiles p
  where p.role in ('admin', 'creative_manager', 'content_creator', 'team_lead')
  order by
    case p.role
      when 'admin' then 1
      when 'creative_manager' then 2
      when 'content_creator' then 3
      when 'team_lead' then 4
      else 5
    end,
    p.created_at
  limit 1;

  if v_creator_id is null then
    select p.id
    into v_creator_id
    from public.profiles p
    order by p.created_at
    limit 1;
  end if;

  if v_creator_id is null then
    raise exception 'Chưa có profile nào. Hãy tạo user Supabase Auth, chạy setup.sql, rồi chạy lại content_plan_seed.sql.';
  end if;

  -- ----------------------------------------------------------
  -- Seed Content Plan từ src/data/contentPlan.ts.
  -- Dùng UUID cố định để chạy lại không bị trùng dữ liệu.
  -- Editor được map qua profiles.editor_code: dat, hai, minh.
  -- ----------------------------------------------------------

  insert into public.content_plan (
    id,
    air_date,
    title,
    category,
    editor_id,
    created_by,
    updated_by
  )
  values
    (
      '00000000-0000-7200-8000-000000000001',
      date '2026-07-01',
      'Video Motion Nệm L''ADOME',
      'Motion',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000002',
      date '2026-07-01',
      'Video Motion Combo kháng khuẩn',
      'Ads',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000003',
      date '2026-07-02',
      'Video Motion Shopee sale 7.7',
      'Motion',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000004',
      date '2026-07-02',
      'Video Chạm vào an yên tập 9',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000005',
      date '2026-07-03',
      'Video Motion Nệm Cocoon Grey',
      'Ads',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000006',
      date '2026-07-03',
      'Video Motion Nệm L''ADOME Cool',
      'Ads',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000007',
      date '2026-07-07',
      'Video Những thứ khiến phòng ngủ đắt tiền',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000008',
      date '2026-07-08',
      'Video Review IKI Premium',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000009',
      date '2026-07-10',
      'Video COCOON - 3 Lợi ích khi sử dụng nệm lò xo túi độc lập',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'dat' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000010',
      date '2026-07-14',
      'Hiểu đúng nệm - Sống vui khỏe tập tháng 8',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'dat' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000011',
      date '2026-07-15',
      'Livestream Shopee - Combo phòng ngủ mùa mưa',
      'Livestream',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000012',
      date '2026-07-16',
      'Short review IKI Premium cho TikTok',
      'Short/Reels',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000013',
      date '2026-07-21',
      'Content tháng 8 - showroom An Sương',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'dat' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000014',
      date '2026-07-22',
      'Motion ưu đãi Cocoon Grey cuối tháng',
      'Motion',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000015',
      date '2026-07-24',
      'On set TIDO - tổng hợp highlight',
      'Short/Reels',
      (select id from public.profiles where lower(editor_code) = 'hai' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000016',
      date '2026-07-28',
      'Ảnh sản phẩm drap mới phông trắng',
      'Ảnh',
      (select id from public.profiles where lower(editor_code) = 'dat' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000017',
      date '2026-07-30',
      'Theo dấu giấc ngủ - showroom Hòa Bình',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'minh' limit 1),
      v_creator_id,
      v_creator_id
    ),
    (
      '00000000-0000-7200-8000-000000000018',
      date '2026-08-01',
      'Video khai trương showroom Cần Thơ',
      'Video dài',
      (select id from public.profiles where lower(editor_code) = 'dat' limit 1),
      v_creator_id,
      v_creator_id
    )
  on conflict (id) do update
  set
    air_date = excluded.air_date,
    title = excluded.title,
    category = excluded.category,
    editor_id = excluded.editor_id,
    created_by = coalesce(public.content_plan.created_by, excluded.created_by),
    updated_by = excluded.updated_by;
end;
$$;

-- ------------------------------------------------------------
-- Kiểm tra nhanh sau khi chạy seed
-- ------------------------------------------------------------

select
  count(*) as total_content_plan,
  count(*) filter (where editor_id is not null) as rows_da_map_editor
from public.content_plan
where id between '00000000-0000-7200-8000-000000000001'::uuid
  and '00000000-0000-7200-8000-000000000018'::uuid;

select
  cp.air_date,
  cp.title,
  cp.category,
  p.short_name as editor
from public.content_plan cp
left join public.profiles p on p.id = cp.editor_id
where cp.air_date >= date '2026-07-01'
  and cp.air_date < date '2026-08-01'
order by cp.air_date, cp.title;
