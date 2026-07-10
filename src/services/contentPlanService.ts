import { supabase, supabaseConfigError } from '../lib/supabase';
import { logActivity } from './activityLogService';
import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';
import { getMonthRange } from '../utils/month';

type Nullable<T> = T | null;

interface ProfileRow {
  id: string;
  editor_code: Nullable<string>;
  short_name: Nullable<string>;
  display_name: Nullable<string>;
  full_name: Nullable<string>;
  ui_color: Nullable<string>;
  avatar_url?: Nullable<string>;
  role?: Nullable<string>;
  active?: Nullable<boolean>;
  is_active?: Nullable<boolean>;
  is_editor_member?: Nullable<boolean>;
}

interface ContentPlanRow {
  id: string;
  air_date: string;
  title: string;
  note: Nullable<string>;
  category: Nullable<ContentPlanCategory>;
  editor_id: Nullable<string>;
  profiles: ProfileRow | ProfileRow[] | null;
}

type ContentPlanPayload = {
  air_date: string;
  title: string;
  note: string | null;
  category: ContentPlanCategory | null;
  editor_id: string | null;
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
  if (!error) return 'Không thể xử lý Content Plan. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('violates check constraint')) {
    return 'Dữ liệu Content Plan chưa đúng định dạng.';
  }
  if (message.includes('is_editor_member')) {
    return 'Danh sách editor chưa sẵn sàng. Vui lòng liên hệ quản trị viên.';
  }

  return error.message || 'Không thể xử lý Content Plan. Vui lòng thử lại.';
}

function firstProfile(profile: ContentPlanRow['profiles']) {
  if (Array.isArray(profile)) return profile[0] ?? null;
  return profile;
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

function mapContentPlanRow(row: ContentPlanRow): ContentPlanItem {
  const profile = firstProfile(row.profiles);

  return {
    id: row.id,
    air_date: row.air_date,
    video_name: row.title,
    note: row.note ?? '',
    category: row.category ?? 'Video dài',
    editor_id: profile?.editor_code ?? '',
  };
}

function getInitial(value: string) {
  return value.trim().charAt(0).toUpperCase() || '?';
}

function getSoftColor(hexColor: string | null | undefined) {
  const color = hexColor && /^#[0-9A-Fa-f]{6}$/.test(hexColor) ? hexColor : '#64748b';
  return `color-mix(in srgb, ${color} 14%, var(--card))`;
}

function getFallbackColor(seed: string) {
  const palette = ['#0ea5e9', '#22c55e', '#f59e0b', '#ef4444', '#14b8a6', '#8b5cf6', '#ec4899'];
  const cleanSeed = seed || 'editor';
  const index = Array.from(cleanSeed).reduce((sum, char) => sum + char.charCodeAt(0), 0) % palette.length;
  return palette[index];
}

function mapEditorOption(row: ProfileRow): ContentPlanEditorOption | null {
  const editorCode = row.editor_code?.trim().toLowerCase();
  if (!editorCode) return null;
  if ((row.is_active ?? row.active ?? true) === false) return null;
  if (row.is_editor_member !== true) return null;

  const name = row.full_name || row.display_name || row.short_name || editorCode;
  const short = row.short_name || row.display_name || name;
  const color = row.ui_color && /^#[0-9A-Fa-f]{6}$/.test(row.ui_color) ? row.ui_color : getFallbackColor(editorCode);

  return {
    id: editorCode,
    profile_id: row.id,
    name,
    short,
    initial: getInitial(short),
    color,
    bgColor: getSoftColor(color),
    avatarUrl: row.avatar_url ?? '',
    role: row.role ?? 'editor',
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
    .neq('is_active', false)
    .ilike('editor_code', cleanCode)
    .maybeSingle();

  if (error) throw new Error(mapDatabaseError(error));

  const editorProfileId = data?.id ?? null;
  editorIdCache.set(cleanCode, editorProfileId);
  return editorProfileId;
}

async function toContentPlanPayload(
  data: ContentPlanFormData,
  userId?: string | null,
  includeCreatedBy = false
): Promise<ContentPlanPayload> {
  const title = data.video_name.trim();
  if (!title) throw new Error('Vui lòng nhập tên video.');
  const note = data.note.trim();
  if (note.length > 2000) throw new Error('Ghi chú tối đa 2000 ký tự.');

  const editorProfileId = await resolveEditorProfileId(data.editor_id);

  return {
    air_date: validateIsoDate(data.air_date, 'Ngày Air'),
    title,
    note: note || null,
    category: data.category || null,
    editor_id: editorProfileId,
    ...(includeCreatedBy ? { created_by: userId ?? null } : {}),
    updated_by: userId ?? null,
  };
}

export async function fetchContentPlan(monthValue?: string): Promise<ContentPlanItem[]> {
  const client = requireSupabase();
  let query = client
    .from('content_plan')
    .select(`
      id,
      air_date,
      title,
      note,
      category,
      editor_id,
      profiles!content_plan_editor_id_fkey (
        id,
        editor_code,
        short_name,
        display_name,
        full_name,
        ui_color,
        avatar_url
      )
    `);

  if (monthValue) {
    const { startDate, endDate } = getMonthRange(monthValue);
    query = query.gte('air_date', startDate).lte('air_date', endDate);
  }

  const { data, error } = await query
    .order('air_date', { ascending: true })
    .order('created_at', { ascending: true });

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as unknown as ContentPlanRow[]).map(mapContentPlanRow);
}

export async function fetchContentPlanEditorOptions(): Promise<ContentPlanEditorOption[]> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('profiles')
    .select(`
      id,
      editor_code,
      short_name,
      display_name,
      full_name,
      ui_color,
      avatar_url,
      role,
      active,
      is_active,
      is_editor_member
    `)
    .order('role', { ascending: true })
    .order('short_name', { ascending: true });

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as ProfileRow[])
    .map(mapEditorOption)
    .filter((editor): editor is ContentPlanEditorOption => Boolean(editor))
    .sort((a, b) => {
      if (a.role === 'editor' && b.role !== 'editor') return -1;
      if (a.role !== 'editor' && b.role === 'editor') return 1;
      return a.short.localeCompare(b.short, 'vi');
    });
}

export async function createContentPlanRow(data: ContentPlanFormData, userId?: string | null) {
  const client = requireSupabase();
  const payload = await toContentPlanPayload(data, userId, true);
  const { data: createdRow, error } = await client
    .from('content_plan')
    .insert(payload)
    .select('id')
    .single();

  if (error) throw new Error(mapDatabaseError(error));

  void logActivity({
    actorId: userId,
    entityType: 'content_plan',
    entityId: createdRow?.id ?? null,
    action: 'created',
    title: data.video_name.trim(),
    description: `Đã tạo kế hoạch content "${data.video_name.trim()}".`,
    metadata: {
      air_date: data.air_date,
      category: data.category,
      note: data.note.trim(),
      editor_id: data.editor_id,
    },
  });
}

export async function updateContentPlanRow(
  rowId: string,
  data: ContentPlanFormData,
  userId?: string | null,
  previousItem?: ContentPlanItem
) {
  const client = requireSupabase();
  const payload = await toContentPlanPayload(data, userId);
  const { error } = await client
    .from('content_plan')
    .update(payload)
    .eq('id', rowId);

  if (error) throw new Error(mapDatabaseError(error));

  const action = previousItem && previousItem.editor_id !== data.editor_id
    ? 'assigned'
    : 'updated';

  void logActivity({
    actorId: userId,
    entityType: 'content_plan',
    entityId: rowId,
    action,
    title: data.video_name.trim(),
    description: action === 'assigned'
      ? `Đã phân công editor cho kế hoạch content "${data.video_name.trim()}".`
      : `Đã cập nhật kế hoạch content "${data.video_name.trim()}".`,
    metadata: {
      air_date: data.air_date,
      category: data.category,
      note: data.note.trim(),
      previous_editor_id: previousItem?.editor_id,
      editor_id: data.editor_id,
    },
  });
}

export async function deleteContentPlanRow(rowId: string, userId?: string | null, title?: string) {
  const client = requireSupabase();
  const { error } = await client
    .from('content_plan')
    .delete()
    .eq('id', rowId);

  if (error) throw new Error(mapDatabaseError(error));

  void logActivity({
    actorId: userId,
    entityType: 'content_plan',
    entityId: rowId,
    action: 'deleted',
    title: title ?? 'Kế hoạch content',
    description: `Đã xóa kế hoạch content "${title ?? rowId}".`,
    metadata: {
      content_plan_id: rowId,
    },
  });
}
