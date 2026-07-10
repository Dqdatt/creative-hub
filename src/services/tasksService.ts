import { supabase, supabaseConfigError } from '../lib/supabase';
import { logActivity } from './activityLogService';
import type { TaskCategory, TaskFormData, TaskPriority, TaskStatus, VideoTask } from '../types/task';
import { getMonthRange } from '../utils/month';

const DEFAULT_TASK_YEAR = 2026;

type Nullable<T> = T | null;

interface ProfileRow {
  id: string;
  editor_code: Nullable<string>;
  short_name: Nullable<string>;
  display_name: Nullable<string>;
  full_name: Nullable<string>;
  ui_color: Nullable<string>;
}

interface VideoTaskRow {
  id: string;
  stt: Nullable<number>;
  title: string;
  resize_reqs: Nullable<string>;
  editor_id: Nullable<string>;
  order_team: Nullable<string>;
  category: Nullable<TaskCategory>;
  receive_date: Nullable<string>;
  return_date: Nullable<string>;
  air_date: Nullable<string>;
  status: TaskStatus;
  priority: Nullable<TaskPriority>;
  result_link: Nullable<string>;
  profiles: ProfileRow | ProfileRow[] | null;
}

type VideoTaskPayload = {
  title: string;
  resize_reqs: string | null;
  editor_id: string | null;
  order_team: string | null;
  category: TaskCategory | null;
  receive_date: string | null;
  return_date: string | null;
  air_date: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  result_link: string | null;
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
  if (!error) return 'Không thể xử lý dữ liệu video. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('violates check constraint')) {
    return 'Dữ liệu video chưa đúng định dạng.';
  }
  if (message.includes('is_editor_member')) {
    return 'Danh sách editor chưa sẵn sàng. Vui lòng liên hệ quản trị viên.';
  }

  return error.message || 'Không thể xử lý dữ liệu video. Vui lòng thử lại.';
}

function firstProfile(profile: VideoTaskRow['profiles']) {
  if (Array.isArray(profile)) return profile[0] ?? null;
  return profile;
}

function toDisplayDate(value: string | null) {
  if (!value) return '';
  const [year, month, day] = value.split('-');
  if (!year || !month || !day) return value;
  return `${Number(day)}/${Number(month)}`;
}

function toDatabaseDate(value: string, label: string) {
  const cleanValue = value.trim();
  if (!cleanValue) return null;

  if (/^\d{4}-\d{2}-\d{2}$/.test(cleanValue)) return cleanValue;

  const match = cleanValue.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
  if (!match) {
    throw new Error(`${label} chưa đúng định dạng. Dùng DD/MM hoặc YYYY-MM-DD.`);
  }

  const day = Number(match[1]);
  const month = Number(match[2]);
  const inputYear = match[3] ? Number(match[3]) : DEFAULT_TASK_YEAR;
  const year = inputYear < 100 ? 2000 + inputYear : inputYear;
  const date = new Date(Date.UTC(year, month - 1, day));

  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new Error(`${label} không hợp lệ.`);
  }

  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function mapTaskRow(row: VideoTaskRow): VideoTask {
  const profile = firstProfile(row.profiles);

  return {
    dbId: row.id,
    id: row.stt ?? 0,
    name: row.title,
    resize: row.resize_reqs ?? '',
    editorId: profile?.editor_code ?? '',
    orderTeam: row.order_team ?? '',
    category: row.category ?? 'Video dài',
    receiveDate: toDisplayDate(row.receive_date),
    returnDate: toDisplayDate(row.return_date),
    airDate: toDisplayDate(row.air_date),
    status: row.status ?? 'Chờ',
    priority: row.priority ?? '',
    link: row.result_link ?? '',
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

async function toTaskPayload(data: TaskFormData, userId?: string | null, includeCreatedBy = false): Promise<VideoTaskPayload> {
  const editorProfileId = await resolveEditorProfileId(data.editorId);

  return {
    title: data.name.trim(),
    resize_reqs: data.resize.trim() || null,
    editor_id: editorProfileId,
    order_team: data.orderTeam || null,
    category: data.category || null,
    receive_date: toDatabaseDate(data.receiveDate, 'Ngày nhận'),
    return_date: toDatabaseDate(data.returnDate, 'Ngày trả'),
    air_date: toDatabaseDate(data.airDate, 'Ngày Air'),
    status: data.status,
    priority: data.priority,
    result_link: data.link.trim() || null,
    ...(includeCreatedBy ? { created_by: userId ?? null } : {}),
    updated_by: userId ?? null,
  };
}

export async function fetchVideoTasks(monthValue?: string): Promise<VideoTask[]> {
  const client = requireSupabase();
  let query = client
    .from('video_tasks')
    .select(`
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
      profiles!video_tasks_editor_id_fkey (
        id,
        editor_code,
        short_name,
        display_name,
        full_name,
        ui_color
      )
    `);

  if (monthValue) {
    const { startDate, endDate } = getMonthRange(monthValue);
    query = query.gte('air_date', startDate).lte('air_date', endDate);
  }

  const { data, error } = await query
    .order('stt', { ascending: true });

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as unknown as VideoTaskRow[]).map(mapTaskRow);
}

export async function createVideoTask(data: TaskFormData, userId?: string | null) {
  const client = requireSupabase();
  const payload = await toTaskPayload(data, userId, true);
  const { data: createdRow, error } = await client
    .from('video_tasks')
    .insert(payload)
    .select('id')
    .single();

  if (error) throw new Error(mapDatabaseError(error));

  void logActivity({
    actorId: userId,
    entityType: 'video_task',
    entityId: createdRow?.id ?? null,
    action: 'created',
    title: data.name.trim(),
    description: `Đã tạo video task "${data.name.trim()}".`,
    metadata: {
      status: data.status,
      editor_id: data.editorId,
      order_team: data.orderTeam,
      category: data.category,
      air_date: data.airDate,
    },
  });
}

export async function updateVideoTask(
  taskId: string,
  data: TaskFormData,
  userId?: string | null,
  previousTask?: VideoTask
) {
  const client = requireSupabase();
  const payload = await toTaskPayload(data, userId);
  const { error } = await client
    .from('video_tasks')
    .update(payload)
    .eq('id', taskId);

  if (error) throw new Error(mapDatabaseError(error));

  const action = previousTask?.status && previousTask.status !== data.status
    ? 'status_changed'
    : previousTask?.editorId && previousTask.editorId !== data.editorId
      ? 'assigned'
      : 'updated';

  const description = action === 'status_changed'
    ? `Đã đổi trạng thái video task "${data.name.trim()}" sang ${data.status}.`
    : action === 'assigned'
      ? `Đã phân công editor cho video task "${data.name.trim()}".`
      : `Đã cập nhật video task "${data.name.trim()}".`;

  void logActivity({
    actorId: userId,
    entityType: 'video_task',
    entityId: taskId,
    action,
    title: data.name.trim(),
    description,
    metadata: {
      previous_status: previousTask?.status,
      status: data.status,
      previous_editor_id: previousTask?.editorId,
      editor_id: data.editorId,
      order_team: data.orderTeam,
      category: data.category,
      air_date: data.airDate,
    },
  });
}
