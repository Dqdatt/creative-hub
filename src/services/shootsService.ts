import { supabase, supabaseConfigError } from '../lib/supabase';
import type { ShootFormData, ShootSchedule, ShootType } from '../types/shoot';

type Nullable<T> = T | null;

interface ShootRow {
  id: string;
  shoot_date: string;
  shoot_type: ShootType;
  crew: Nullable<string>;
  time_slot: Nullable<string>;
  location: Nullable<string>;
  content_note: Nullable<string>;
  shoot_editors: ShootEditorRow[] | null;
}

interface ProfileRow {
  id: string;
  editor_code: Nullable<string>;
  short_name: Nullable<string>;
  display_name: Nullable<string>;
  full_name: Nullable<string>;
  ui_color: Nullable<string>;
}

interface ShootEditorRow {
  profile_id: string;
  profiles: ProfileRow | ProfileRow[] | null;
}

type ShootPayload = {
  shoot_date: string;
  shoot_type: ShootType;
  crew: string | null;
  time_slot: string | null;
  location: string;
  content_note: string | null;
};

function requireSupabase() {
  if (!supabase) {
    throw new Error(supabaseConfigError ? 'Kết nối dữ liệu chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : 'Kết nối dữ liệu chưa sẵn sàng.');
  }
  return supabase;
}

function mapDatabaseError(error: { message?: string; code?: string } | null) {
  if (!error) return 'Không thể xử lý lịch quay. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('violates check constraint')) {
    return 'Dữ liệu lịch quay chưa đúng định dạng.';
  }
  if (message.includes('bạn không có quyền tạo lịch quay')) {
    return 'Bạn không có quyền tạo lịch quay.';
  }
  if (message.includes('bạn không có quyền cập nhật lịch quay')) {
    return 'Bạn không có quyền cập nhật lịch quay.';
  }
  if (message.includes('bạn không có quyền xóa lịch quay')) {
    return 'Bạn không có quyền xóa lịch quay.';
  }
  if (message.includes('không tìm thấy lịch quay')) {
    return 'Không tìm thấy lịch quay.';
  }
  if (message.includes('loại lịch quay không hợp lệ')) {
    return 'Loại lịch quay không hợp lệ.';
  }
  if (message.includes('shoot_editors') || message.includes('is_editor_member')) {
    return 'Phân công editor chưa sẵn sàng. Vui lòng liên hệ quản trị viên.';
  }

  return error.message || 'Không thể xử lý lịch quay. Vui lòng thử lại.';
}

function validateIsoDate(value: string, label: string) {
  const cleanValue = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(cleanValue)) {
    throw new Error(`${label} chưa đúng định dạng YYYY-MM-DD.`);
  }

  const [yearValue, monthValue, dayValue] = cleanValue.split('-').map(Number);
  const date = new Date(Date.UTC(yearValue, monthValue - 1, dayValue));
  if (
    date.getUTCFullYear() !== yearValue ||
    date.getUTCMonth() !== monthValue - 1 ||
    date.getUTCDate() !== dayValue
  ) {
    throw new Error(`${label} không hợp lệ.`);
  }

  return cleanValue;
}

function firstProfile(profile: ShootEditorRow['profiles']) {
  if (Array.isArray(profile)) return profile[0] ?? null;
  return profile;
}

function getEditorCrewLabel(profile: ProfileRow) {
  const codeLabelMap: Record<string, string> = {
    dat: 'ĐẠT',
    hai: 'HẢI',
    minh: 'MINH',
  };
  const editorCode = profile.editor_code?.trim().toLowerCase() ?? '';
  if (codeLabelMap[editorCode]) return codeLabelMap[editorCode];

  const source = profile.full_name || profile.display_name || profile.short_name || profile.editor_code || '';
  const parts = source.trim().split(/\s+/).filter(Boolean);
  return (parts[parts.length - 1] || source || profile.editor_code || '').toUpperCase();
}

function getShootEditors(rows: ShootEditorRow[] | null) {
  return (rows ?? [])
    .map((row) => {
      const profile = firstProfile(row.profiles);
      if (!profile?.editor_code) return null;
      return {
        editorId: profile.editor_code.trim().toLowerCase(),
        profileId: row.profile_id,
        label: getEditorCrewLabel(profile),
      };
    })
    .filter((editor): editor is { editorId: string; profileId: string; label: string } => Boolean(editor?.editorId && editor.profileId));
}

function combineDisplayCrew(editorLabels: string[], crew: string) {
  return [...editorLabels, crew.trim()].filter(Boolean).join(' - ');
}

function mapShootRow(row: ShootRow): ShootSchedule {
  const assignedEditors = getShootEditors(row.shoot_editors);
  const editorLabels = assignedEditors.map((editor) => editor.label);
  const crew = row.crew ?? '';

  return {
    id: row.id,
    date: row.shoot_date,
    type: row.shoot_type,
    crew,
    editorIds: assignedEditors.map((editor) => editor.editorId),
    editorProfileIds: assignedEditors.map((editor) => editor.profileId),
    editorLabels,
    displayCrew: combineDisplayCrew(editorLabels, crew),
    place: row.location ?? '',
    time: row.time_slot ?? '',
    note: row.content_note ?? '',
  };
}

function toShootPayload(data: ShootFormData): ShootPayload {
  const place = data.place.trim();
  if (!place) throw new Error('Vui lòng nhập địa điểm lịch quay.');

  return {
    shoot_date: validateIsoDate(data.date, 'Ngày quay'),
    shoot_type: data.type,
    crew: data.crew.trim() || null,
    time_slot: data.time.trim() || null,
    location: place,
    content_note: data.note.trim() || null,
  };
}

export async function fetchShoots(startDate: string, endDate: string): Promise<ShootSchedule[]> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('shoots')
    .select(`
      id,
      shoot_date,
      shoot_type,
      crew,
      time_slot,
      location,
      content_note,
      shoot_editors (
        profile_id,
        profiles!shoot_editors_profile_id_fkey (
          id,
          editor_code,
          short_name,
          display_name,
          full_name,
          ui_color
        )
      )
    `)
    .gte('shoot_date', startDate)
    .lte('shoot_date', endDate)
    .order('shoot_date', { ascending: true })
    .order('created_at', { ascending: true });

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as unknown as ShootRow[]).map(mapShootRow);
}

export async function fetchShootById(shootId: string): Promise<ShootSchedule | null> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('shoots')
    .select(`
      id,
      shoot_date,
      shoot_type,
      crew,
      time_slot,
      location,
      content_note,
      shoot_editors (
        profile_id,
        profiles!shoot_editors_profile_id_fkey (
          id,
          editor_code,
          short_name,
          display_name,
          full_name,
          ui_color
        )
      )
    `)
    .eq('id', shootId)
    .maybeSingle();

  if (error) throw new Error(mapDatabaseError(error));
  if (!data) return null;

  return mapShootRow(data as unknown as ShootRow);
}

export async function createShoot(data: ShootFormData) {
  const client = requireSupabase();
  const payload = toShootPayload(data);
  const { data: result, error } = await client.rpc('create_shoot_with_notifications', {
    p_shoot_date: payload.shoot_date,
    p_shoot_type: payload.shoot_type,
    p_crew: payload.crew,
    p_time_slot: payload.time_slot,
    p_location: payload.location,
    p_content_note: payload.content_note,
    p_editor_codes: data.editorIds,
  });

  if (error) throw new Error(mapDatabaseError(error));
  if (!Array.isArray(result) || !result[0]?.shoot_id) throw new Error('Không nhận được mã lịch quay. Vui lòng thử lại.');
}

export async function updateShoot(shootId: string, data: ShootFormData) {
  const client = requireSupabase();
  const payload = toShootPayload(data);
  const { error } = await client.rpc('update_shoot_with_notifications', {
    p_shoot_id: shootId,
    p_shoot_date: payload.shoot_date,
    p_shoot_type: payload.shoot_type,
    p_crew: payload.crew,
    p_time_slot: payload.time_slot,
    p_location: payload.location,
    p_content_note: payload.content_note,
    p_editor_codes: data.editorIds,
  });

  if (error) throw new Error(mapDatabaseError(error));
}

export async function deleteShoot(shootId: string) {
  const client = requireSupabase();
  const { error } = await client.rpc('delete_shoot_with_notifications', {
    p_shoot_id: shootId,
  });

  if (error) throw new Error(mapDatabaseError(error));
}
