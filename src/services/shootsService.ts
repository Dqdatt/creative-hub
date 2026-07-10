import { supabase, supabaseConfigError } from '../lib/supabase';
import { logActivity } from './activityLogService';
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
  status: 'scheduled';
  priority: '';
  created_by?: string | null;
  updated_by?: string | null;
};

const editorIdCache = new Map<string, string | null>();

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

function toShootPayload(data: ShootFormData, userId?: string | null, includeCreatedBy = false): ShootPayload {
  const place = data.place.trim();
  if (!place) throw new Error('Vui lòng nhập địa điểm lịch quay.');

  return {
    shoot_date: validateIsoDate(data.date, 'Ngày quay'),
    shoot_type: data.type,
    crew: data.crew.trim() || null,
    time_slot: data.time.trim() || null,
    location: place,
    content_note: data.note.trim() || null,
    status: 'scheduled',
    priority: '',
    ...(includeCreatedBy ? { created_by: userId ?? null } : {}),
    updated_by: userId ?? null,
  };
}

async function resolveEditorProfileId(editorCode: string) {
  const cleanCode = editorCode.trim().toLowerCase();
  if (!cleanCode) return null;
  if (editorIdCache.has(cleanCode)) return editorIdCache.get(cleanCode) ?? null;

  const client = requireSupabase();
  const { data, error } = await client
    .from('profiles')
    .select('id')
    .eq('is_editor_member', true)
    .ilike('editor_code', cleanCode)
    .maybeSingle();

  if (error) throw new Error(mapDatabaseError(error));

  const editorProfileId = data?.id ?? null;
  editorIdCache.set(cleanCode, editorProfileId);
  return editorProfileId;
}

async function syncShootEditors(shootId: string, editorIds: string[], userId?: string | null) {
  const client = requireSupabase();
  const uniqueEditorIds = Array.from(new Set(editorIds.map((id) => id.trim().toLowerCase()).filter(Boolean)));
  const profileIds = (await Promise.all(uniqueEditorIds.map(resolveEditorProfileId))).filter((id): id is string => Boolean(id));

  if (profileIds.length !== uniqueEditorIds.length) {
    throw new Error('Không tìm thấy profile editor hợp lệ. Hãy kiểm tra Editor Code và bật "Tham gia team editor" trong Thành viên.');
  }

  const { data: currentRows, error: fetchError } = await client
    .from('shoot_editors')
    .select('profile_id')
    .eq('shoot_id', shootId);

  if (fetchError) throw new Error(mapDatabaseError(fetchError));

  const currentProfileIds = new Set((currentRows ?? []).map((row) => row.profile_id as string));
  const nextProfileIds = new Set(profileIds);
  const profileIdsToInsert = profileIds.filter((profileId) => !currentProfileIds.has(profileId));
  const profileIdsToDelete = Array.from(currentProfileIds).filter((profileId) => !nextProfileIds.has(profileId));

  if (profileIdsToInsert.length > 0) {
    const { error: insertError } = await client
      .from('shoot_editors')
      .insert(profileIdsToInsert.map((profileId) => ({
        shoot_id: shootId,
        profile_id: profileId,
        created_by: userId ?? null,
      })));

    if (insertError) throw new Error(mapDatabaseError(insertError));
  }

  if (profileIdsToDelete.length === 0) return;

  const { error: deleteError } = await client
    .from('shoot_editors')
    .delete()
    .eq('shoot_id', shootId)
    .in('profile_id', profileIdsToDelete);

  if (deleteError) throw new Error(mapDatabaseError(deleteError));
}

function getErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : 'Không thể lưu phân công editor cho lịch quay.';
}

async function rollbackCreatedShoot(shootId: string) {
  const client = requireSupabase();
  const { error } = await client
    .from('shoots')
    .delete()
    .eq('id', shootId);

  return !error;
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

export async function createShoot(data: ShootFormData, userId?: string | null) {
  const client = requireSupabase();
  const payload = toShootPayload(data, userId, true);
  const { data: createdRow, error } = await client
    .from('shoots')
    .insert(payload)
    .select('id')
    .single();

  if (error) throw new Error(mapDatabaseError(error));
  if (!createdRow?.id) throw new Error('Không nhận được mã lịch quay. Vui lòng thử lại.');

  try {
    await syncShootEditors(createdRow.id, data.editorIds, userId);
  } catch (assignmentError) {
    const didRollback = await rollbackCreatedShoot(createdRow.id);
    if (!didRollback) {
      throw new Error(`${getErrorMessage(assignmentError)} Lịch quay đã được tạo nhưng phân công editor chưa được lưu. Vui lòng liên hệ quản trị viên.`);
    }
    throw assignmentError;
  }

  void logActivity({
    actorId: userId,
    entityType: 'shoot',
    entityId: createdRow.id,
    action: 'created',
    title: data.place.trim(),
    description: `Đã tạo lịch quay "${data.place.trim()}".`,
    metadata: {
      shoot_date: data.date,
      shoot_type: data.type,
      crew: data.crew,
      editor_ids: data.editorIds,
      time_slot: data.time,
    },
  });
}

export async function updateShoot(shootId: string, data: ShootFormData, userId?: string | null) {
  const client = requireSupabase();
  const payload = toShootPayload(data, userId);
  const { error } = await client
    .from('shoots')
    .update(payload)
    .eq('id', shootId);

  if (error) throw new Error(mapDatabaseError(error));
  await syncShootEditors(shootId, data.editorIds, userId);

  void logActivity({
    actorId: userId,
    entityType: 'shoot',
    entityId: shootId,
    action: 'updated',
    title: data.place.trim(),
    description: `Đã cập nhật lịch quay "${data.place.trim()}".`,
    metadata: {
      shoot_date: data.date,
      shoot_type: data.type,
      crew: data.crew,
      editor_ids: data.editorIds,
      time_slot: data.time,
    },
  });
}

export async function deleteShoot(shootId: string, userId?: string | null, title?: string) {
  const client = requireSupabase();
  const { error } = await client
    .from('shoots')
    .delete()
    .eq('id', shootId);

  if (error) throw new Error(mapDatabaseError(error));

  void logActivity({
    actorId: userId,
    entityType: 'shoot',
    entityId: shootId,
    action: 'deleted',
    title: title ?? 'Lịch quay',
    description: `Đã xóa lịch quay "${title ?? shootId}".`,
    metadata: {
      shoot_id: shootId,
    },
  });
}
