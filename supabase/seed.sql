  -- ============================================================
  -- Video Ops - Seed dữ liệu mock hiện tại
  -- Phase 7B: chỉ seed database, chưa kết nối CRUD frontend
  -- Safe to run nhiều lần sau khi đã chạy supabase/setup.sql.
  -- ============================================================

  -- Yêu cầu trước khi chạy:
  -- 1. Đã chạy supabase/setup.sql.
  -- 2. Đã có ít nhất 1 user trong Authentication.
  -- 3. Nên set user đầu tiên thành admin hoặc team_lead trong public.profiles.

  do $$
  declare
    v_creator_id uuid;
  begin
    select p.id
    into v_creator_id
    from public.profiles p
    where p.role in ('admin', 'team_lead')
    order by case p.role when 'admin' then 1 when 'team_lead' then 2 else 3 end, p.created_at
    limit 1;

    if v_creator_id is null then
      select p.id
      into v_creator_id
      from public.profiles p
      order by p.created_at
      limit 1;
    end if;

    if v_creator_id is null then
      raise exception 'Chưa có profile nào. Hãy tạo user Supabase Auth, chạy setup.sql, rồi chạy lại seed.sql.';
    end if;

    -- ----------------------------------------------------------
    -- Map editor mock vào profile có sẵn nếu tìm được.
    -- Không tạo profile giả vì profiles.id phải tham chiếu auth.users.id.
    -- Nếu chưa có user cho Hải/Minh, task vẫn được seed và editor_id sẽ null.
    -- ----------------------------------------------------------

    update public.profiles p
    set
      editor_code = e.editor_code,
      crew_key = e.crew_key,
      ui_color = e.ui_color,
      display_name = e.short_name,
      short_name = e.short_name,
      full_name = e.full_name,
      department = 'Team Marketing',
      role = case
        when p.role in ('admin', 'team_lead') then p.role
        else 'editor'
      end
    from (
      values
        ('dat',  'Đoàn Quốc Đạt',      'Đạt Đoàn',   'ĐẠT',  '#0ea5e9'),
        ('hai',  'Nguyễn Thanh Hải',    'Thanh Hải',  'HẢI',  '#22c55e'),
        ('minh', 'Hoàng Hữu Lê Minh',   'Hữu Minh',   'MINH', '#f59e0b')
    ) as e(editor_code, full_name, short_name, crew_key, ui_color)
    where
      lower(coalesce(p.editor_code, '')) = e.editor_code
      or lower(p.full_name) = lower(e.full_name)
      or lower(p.short_name) = lower(e.short_name)
      or lower(coalesce(p.display_name, '')) = lower(e.short_name);

    -- ----------------------------------------------------------
    -- Seed video_tasks từ src/data/tasks.ts.
    -- stt là khóa chống trùng cho seed mock.
    -- ----------------------------------------------------------

    insert into public.video_tasks (
      id,
      stt,
      title,
      resize_reqs,
      editor_id,
      order_team,
      category,
      receive_date,
      return_date,
      air_date,
      status,
      priority,
      result_link,
      created_by,
      updated_by
    )
    values
      (
        '00000000-0000-7000-8000-000000000001',
        1,
        'Video Motion Shopee sale 7.7',
        '',
        (select id from public.profiles where editor_code = 'minh' limit 1),
        'ECOM',
        'Motion',
        date '2026-06-26',
        date '2026-06-26',
        date '2026-07-02',
        'Đã xong',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000002',
        2,
        'Video Chạm vào an yên tập 9',
        '9x16 & 1x1',
        (select id from public.profiles where editor_code = 'minh' limit 1),
        'BRAND',
        'Video dài',
        date '2026-06-30',
        date '2026-07-01',
        date '2026-07-02',
        'Đã xong',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000003',
        3,
        'Video Review IKI Premium',
        '9x16 & 1x1',
        (select id from public.profiles where editor_code = 'hai' limit 1),
        'BRAND',
        'Video dài',
        date '2026-06-30',
        date '2026-07-06',
        date '2026-07-08',
        'Đang làm',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000004',
        4,
        'Video Motion Nệm L''ADOME',
        '',
        (select id from public.profiles where editor_code = 'hai' limit 1),
        'BRAND',
        'Motion',
        date '2026-06-30',
        date '2026-07-01',
        date '2026-07-01',
        'Đã xong',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000005',
        5,
        'Video Motion Combo kháng khuẩn',
        '1x1',
        (select id from public.profiles where editor_code = 'minh' limit 1),
        'DIGITAL',
        'Ads',
        date '2026-07-01',
        date '2026-07-01',
        date '2026-07-01',
        'Đã xong',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000006',
        6,
        'Video Những thứ khiến phòng ngủ đắt tiền',
        '9x16 & 1x1',
        (select id from public.profiles where editor_code = 'minh' limit 1),
        'BRAND',
        'Video dài',
        date '2026-07-02',
        date '2026-07-06',
        date '2026-07-07',
        'Đang làm',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000007',
        7,
        'Video Motion Nệm Cocoon Grey',
        '1x1',
        (select id from public.profiles where editor_code = 'hai' limit 1),
        'DIGITAL',
        'Ads',
        date '2026-07-02',
        date '2026-07-03',
        date '2026-07-03',
        'Đã xong',
        'Gấp',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000008',
        8,
        'Video COCOON - 3 Lợi ích khi sử dụng nệm lò xo túi độc lập',
        '9x16 & 1x1',
        (select id from public.profiles where editor_code = 'dat' limit 1),
        'BRAND',
        'Video dài',
        date '2026-07-01',
        date '2026-07-07',
        date '2026-07-10',
        'Đang làm',
        '',
        '',
        v_creator_id,
        v_creator_id
      ),
      (
        '00000000-0000-7000-8000-000000000009',
        9,
        'Video Motion Nệm L''ADOME Cool',
        '1x1',
        (select id from public.profiles where editor_code = 'hai' limit 1),
        'DIGITAL',
        'Ads',
        date '2026-07-02',
        date '2026-07-03',
        date '2026-07-03',
        'Đã xong',
        'Gấp',
        '',
        v_creator_id,
        v_creator_id
      )
    on conflict (stt) do update
    set
      title = excluded.title,
      resize_reqs = excluded.resize_reqs,
      editor_id = excluded.editor_id,
      order_team = excluded.order_team,
      category = excluded.category,
      receive_date = excluded.receive_date,
      return_date = excluded.return_date,
      air_date = excluded.air_date,
      status = excluded.status,
      priority = excluded.priority,
      result_link = excluded.result_link,
      updated_by = excluded.updated_by;

    perform setval(
      pg_get_serial_sequence('public.video_tasks', 'stt')::regclass,
      greatest(
        coalesce((select max(stt) from public.video_tasks), 1),
        1
      ),
      true
    );

    -- ----------------------------------------------------------
    -- Seed shoots từ src/data/shoots.ts.
    -- Dùng UUID cố định để chạy lại không bị trùng dữ liệu.
    -- ----------------------------------------------------------

    insert into public.shoots (
      id,
      shoot_date,
      shoot_type,
      crew,
      time_slot,
      location,
      content_note,
      status,
      priority,
      created_by,
      updated_by
    )
    values
      ('00000000-0000-7100-8000-000000000001', date '2026-07-07', 'livestream', 'KHANG + ĐẠT', 'BUỔI TỐI', 'LIVESTREAM SHOPEE', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000002', date '2026-07-08', 'lichquay', 'HẰNG - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM HÒA BÌNH', 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000003', date '2026-07-09', 'lichquay', 'LINH - MINH - BUMI', 'ALL MORNING', 'SHOWROOM AN SƯƠNG', 'THEO DẤU GIẤC NGỦ TẬP 2 - SHOWROOM TRƯỜNG CHINH', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000004', date '2026-07-10', 'livestream', 'MINH + HẢI', 'BUỔI TỐI', 'LIVESTREAM SHOPEE', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000005', date '2026-07-10', 'onset', 'ĐẠT - BUMI', '', 'ONSET TIDO', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000006', date '2026-07-13', 'other', '', '', 'QUAY CHỤP BELLO', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000007', date '2026-07-14', 'lichquay', 'MY - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM HÒA BÌNH', 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000008', date '2026-07-15', 'livestream', 'KHANG + MINH', 'BUỔI TỐI', 'LIVESTREAM SHOPEE', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000009', date '2026-07-16', 'lichquay', 'MY - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM AN SƯƠNG', 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000010', date '2026-07-17', 'onset', 'ĐẠT - BUMI', '', 'ON SET TIDO', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000011', date '2026-07-20', 'livestream', 'HẢI + ĐẠT', 'BUỔI TỐI', 'LIVESTREAM SHOPEE', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000012', date '2026-07-21', 'lichquay', 'HẰNG - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM AN SƯƠNG', 'CONTENT THÁNG 8', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000013', date '2026-07-22', 'lichquay', 'NHƯ - MINH - BUMI', 'ALL MORNING', 'SHOWROOM AN SƯƠNG', 'CONTENT THÁNG 8', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000014', date '2026-07-24', 'onset', 'ĐẠT - BUMI', '', 'ON SET TIDO', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000015', date '2026-07-25', 'lichquay', 'BUMI - ĐẠT - ÂN', '', 'SCOUT SHOWROOM CẦN THƠ', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000016', date '2026-07-28', 'lichquay', 'MY - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM HÒA BÌNH', 'CONTENT THÁNG 8 HOẶC CHỤP/QUAY DRAP MỚI PHÔNG TRẮNG', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000017', date '2026-07-29', 'lichquay', 'LONG - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM AN SƯƠNG', 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000018', date '2026-07-30', 'lichquay', 'LINH - ĐẠT - BUMI', 'ALL MORNING', 'SHOWROOM HÒA BÌNH', 'HIỂU ĐÚNG NỆM - SỐNG VUI KHỎE', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000019', date '2026-07-31', 'onset', 'ĐẠT - BUMI', '', 'ON SET TIDO', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000020', date '2026-08-01', 'lichquay', 'BUMI - ĐẠT', '', 'KHAI TRƯƠNG CẦN THƠ', '', 'scheduled', '', v_creator_id, v_creator_id),
      ('00000000-0000-7100-8000-000000000021', date '2026-08-05', 'onset', 'ĐẠT - BUMI', '', 'ON SET TIDO', '', 'scheduled', '', v_creator_id, v_creator_id)
    on conflict (id) do update
    set
      shoot_date = excluded.shoot_date,
      shoot_type = excluded.shoot_type,
      crew = excluded.crew,
      time_slot = excluded.time_slot,
      location = excluded.location,
      content_note = excluded.content_note,
      status = excluded.status,
      priority = excluded.priority,
      updated_by = excluded.updated_by;
  end;
  $$;

  -- ------------------------------------------------------------
  -- Kiểm tra nhanh sau khi chạy seed
  -- ------------------------------------------------------------

  select
    count(*) as total_video_tasks,
    count(*) filter (where editor_id is not null) as tasks_da_map_editor
  from public.video_tasks
  where stt between 1 and 9;

  select
    count(*) as total_shoots
  from public.shoots
  where id between '00000000-0000-7100-8000-000000000001'::uuid
    and '00000000-0000-7100-8000-000000000021'::uuid;
