import { supabase, supabaseConfigError } from '../lib/supabase';
import { logActivity } from './activityLogService';
import type {
  AcceptLinkedVideoTaskInput,
  AcceptLinkedVideoTaskResult,
  CompleteLinkedVideoTaskInput,
  CompleteLinkedVideoTaskResult,
  CreateLinkedVideoTaskInput,
  UpdateLinkedVideoTaskExecutionInput,
  UpdateLinkedVideoTaskExecutionResult,
  TaskCategory,
  TaskFormData,
  TaskPriority,
  TaskStatus,
  VideoTask,
} from '../types/task';
import { getMonthRange } from '../utils/month';
import { normalizeHttpUrl, normalizeOptionalHttpUrl } from '../utils/url';

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
  content_plan_id: Nullable<string>;
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
  content_plan_id?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
};

interface AcceptLinkedVideoTaskRpcRow {
  video_task_id: string;
  content_plan_id: string;
  status: TaskStatus;
  receive_date: string;
  return_date: string;
  air_date: string;
  editor_id: string;
}

interface CompleteLinkedVideoTaskRpcRow {
  video_task_id: string;
  content_plan_id: string;
  status: TaskStatus;
  result_link: string;
  content_plan_link: string;
  completed_at: string;
  editor_id: string;
  air_date: string;
}

interface UpdateLinkedVideoTaskExecutionRpcRow {
  video_task_id: string;
  content_plan_id: string;
  status: TaskStatus;
  order_team: string | null;
  priority: TaskPriority | null;
  resize_reqs: string | null;
  receive_date: string;
  return_date: string;
  result_link: string | null;
  editor_id: string;
  changed_fields: string[] | null;
}

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
  if (message.includes('video_tasks_content_plan_id_unique')) {
    return 'Content Plan này đã có Video Task liên kết.';
  }
  if (message.includes('video_tasks_content_plan_id_fkey')) {
    return 'Không tìm thấy Content Plan hợp lệ để liên kết Video Task.';
  }
  if (message.includes('không được đổi liên kết content plan')) {
    return 'Không thể đổi liên kết Content Plan của Video Task.';
  }
  if (message.includes('hãy đổi editor của task liên kết từ content plan')) {
    return 'Hãy đổi Editor của Task liên kết từ Content Plan.';
  }
  if (message.includes('thông tin kế hoạch của task liên kết được quản lý từ content plan')) {
    return 'Thông tin kế hoạch của Task liên kết được quản lý từ Content Plan.';
  }
  if (message.includes('không tìm thấy task')) {
    return 'Không tìm thấy Task.';
  }
  if (message.includes('task thủ công không sử dụng thao tác nhận task')) {
    return 'Task thủ công không sử dụng thao tác Nhận Task.';
  }
  if (message.includes('bạn không phải editor được giao task này')) {
    return 'Bạn không phải Editor được giao Task này.';
  }
  if (message.includes('tài khoản editor hiện không đủ điều kiện nhận task')) {
    return 'Tài khoản Editor hiện không đủ điều kiện nhận Task.';
  }
  if (message.includes('task này đã được nhận hoặc trạng thái đã thay đổi')) {
    return 'Task này đã được nhận hoặc trạng thái đã thay đổi.';
  }
  if (message.includes('ngày nhận và ngày trả chưa hợp lệ')) {
    return 'Ngày nhận và Ngày trả chưa hợp lệ.';
  }
  if (message.includes('hãy nhận task liên kết qua thao tác nhận task')) {
    return 'Hãy nhận Task liên kết qua thao tác Nhận Task.';
  }
  if (message.includes('task thủ công không sử dụng luồng hoàn thành từ content plan')) {
    return 'Task thủ công không sử dụng luồng hoàn thành từ Content Plan.';
  }
  if (message.includes('task này chưa ở trạng thái có thể hoàn thành')) {
    return 'Task này chưa ở trạng thái có thể hoàn thành.';
  }
  if (message.includes('task này đã hoàn thành hoặc trạng thái đã thay đổi')) {
    return 'Task này đã hoàn thành hoặc trạng thái đã thay đổi.';
  }
  if (message.includes('link thành phẩm chưa hợp lệ')) {
    return 'Link thành phẩm chưa hợp lệ.';
  }
  if (message.includes('không tìm thấy content plan liên kết')) {
    return 'Không tìm thấy Content Plan liên kết.';
  }
  if (message.includes('hãy hoàn thành task liên kết qua thao tác hoàn thành')) {
    return 'Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.';
  }
  if (message.includes('hãy cập nhật thông tin thực hiện task liên kết qua thao tác lưu thay đổi')) {
    return 'Hãy cập nhật thông tin thực hiện Task liên kết qua thao tác Lưu thay đổi.';
  }
  if (message.includes('team order chưa hợp lệ')) {
    return 'Team Order chưa hợp lệ.';
  }
  if (message.includes('độ ưu tiên chưa hợp lệ')) {
    return 'Độ ưu tiên chưa hợp lệ.';
  }
  if (message.includes('link content plan liên kết được đồng bộ từ video tháng')) {
    return 'Link Content Plan liên kết được đồng bộ từ Video tháng.';
  }
  if (message.includes('ngày air của task liên kết')) {
    return 'Ngày Air của Task liên kết được quản lý từ Content Plan.';
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
    contentPlanId: row.content_plan_id,
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

function validateContentPlanId(value: string) {
  const cleanValue = value.trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cleanValue)) {
    throw new Error('Mã Content Plan không hợp lệ.');
  }

  return cleanValue;
}

function validateVideoTaskId(value: string) {
  const cleanValue = value.trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cleanValue)) {
    throw new Error('Mã Task không hợp lệ.');
  }

  return cleanValue;
}

function mapAcceptLinkedVideoTaskRpcRow(row: AcceptLinkedVideoTaskRpcRow): AcceptLinkedVideoTaskResult {
  return {
    videoTaskId: row.video_task_id,
    contentPlanId: row.content_plan_id,
    status: row.status,
    receiveDate: row.receive_date,
    returnDate: row.return_date,
    airDate: row.air_date,
    editorId: row.editor_id,
  };
}

function mapCompleteLinkedVideoTaskRpcRow(row: CompleteLinkedVideoTaskRpcRow): CompleteLinkedVideoTaskResult {
  return {
    videoTaskId: row.video_task_id,
    contentPlanId: row.content_plan_id,
    status: row.status,
    resultLink: row.result_link,
    contentPlanLink: row.content_plan_link,
    completedAt: row.completed_at,
    editorId: row.editor_id,
    airDate: row.air_date,
  };
}

function mapUpdateLinkedVideoTaskExecutionRpcRow(row: UpdateLinkedVideoTaskExecutionRpcRow): UpdateLinkedVideoTaskExecutionResult {
  return {
    videoTaskId: row.video_task_id,
    contentPlanId: row.content_plan_id,
    status: row.status,
    orderTeam: row.order_team ?? '',
    priority: row.priority ?? '',
    resize: row.resize_reqs ?? '',
    receiveDate: row.receive_date,
    returnDate: row.return_date,
    resultLink: row.result_link ?? '',
    editorId: row.editor_id,
    changedFields: row.changed_fields ?? [],
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
      content_plan_id,
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

export async function createVideoTaskFromContentPlan(data: CreateLinkedVideoTaskInput, userId?: string | null) {
  const client = requireSupabase();
  const payload = await toTaskPayload(data, userId, true);
  payload.content_plan_id = validateContentPlanId(data.contentPlanId);

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
    description: `Đã tạo video task từ Content Plan "${data.name.trim()}".`,
    metadata: {
      status: data.status,
      editor_id: data.editorId,
      order_team: data.orderTeam,
      category: data.category,
      air_date: data.airDate,
      content_plan_id: data.contentPlanId,
    },
  });
}

export async function updateVideoTask(
  taskId: string,
  data: TaskFormData,
  userId?: string | null,
  previousTask?: VideoTask
) {
  if (previousTask?.contentPlanId && previousTask.editorId !== data.editorId) {
    throw new Error('Hãy đổi Editor của Task liên kết từ Content Plan.');
  }
  if (previousTask?.contentPlanId && previousTask.airDate !== data.airDate) {
    throw new Error('Ngày Air của Task liên kết được quản lý từ Content Plan.');
  }
  if (
    previousTask?.contentPlanId &&
    previousTask.status === 'Đang làm' &&
    (data.status === 'Đã xong' || previousTask.link !== data.link)
  ) {
    throw new Error('Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.');
  }
  if (
    previousTask?.contentPlanId &&
    previousTask.status === 'Đã xong' &&
    (previousTask.status !== data.status || previousTask.link !== data.link)
  ) {
    throw new Error('Hãy hoàn thành Task liên kết qua thao tác Hoàn thành.');
  }

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

export async function acceptLinkedVideoTask(input: AcceptLinkedVideoTaskInput): Promise<AcceptLinkedVideoTaskResult> {
  const client = requireSupabase();
  const taskId = validateVideoTaskId(input.taskId);
  const receiveDate = toDatabaseDate(input.receiveDate, 'Ngày nhận');
  const returnDate = toDatabaseDate(input.returnDate, 'Ngày trả');

  if (!receiveDate || !returnDate || returnDate < receiveDate) {
    throw new Error('Ngày nhận và Ngày trả chưa hợp lệ.');
  }

  const { data, error } = await client.rpc('accept_linked_video_task', {
    p_video_task_id: taskId,
    p_receive_date: receiveDate,
    p_return_date: returnDate,
  });

  if (error) throw new Error(mapDatabaseError(error));

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error('Không nhận được kết quả nhận Task.');
  }

  return mapAcceptLinkedVideoTaskRpcRow(row as AcceptLinkedVideoTaskRpcRow);
}

export async function updateLinkedVideoTaskExecution(input: UpdateLinkedVideoTaskExecutionInput): Promise<UpdateLinkedVideoTaskExecutionResult> {
  const client = requireSupabase();
  const taskId = validateVideoTaskId(input.taskId);
  const receiveDate = toDatabaseDate(input.receiveDate, 'Ngày nhận');
  const returnDate = toDatabaseDate(input.returnDate, 'Ngày trả');

  if (!receiveDate || !returnDate || returnDate < receiveDate) {
    throw new Error('Ngày nhận và Ngày trả chưa hợp lệ.');
  }

  const resultLink = normalizeOptionalHttpUrl(input.link);

  const { data, error } = await client.rpc('update_linked_video_task_execution', {
    p_video_task_id: taskId,
    p_order_team: input.orderTeam.trim() || null,
    p_priority: input.priority,
    p_resize_reqs: input.resize.trim() || null,
    p_receive_date: receiveDate,
    p_return_date: returnDate,
    p_result_link: resultLink,
  });

  if (error) throw new Error(mapDatabaseError(error));

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error('Không nhận được kết quả lưu thông tin thực hiện Task.');
  }

  return mapUpdateLinkedVideoTaskExecutionRpcRow(row as UpdateLinkedVideoTaskExecutionRpcRow);
}

export async function completeLinkedVideoTask(input: CompleteLinkedVideoTaskInput): Promise<CompleteLinkedVideoTaskResult> {
  const client = requireSupabase();
  const taskId = validateVideoTaskId(input.taskId);
  const resultLink = normalizeHttpUrl(input.resultLink);

  const { data, error } = await client.rpc('complete_linked_video_task', {
    p_video_task_id: taskId,
    p_result_link: resultLink,
  });

  if (error) throw new Error(mapDatabaseError(error));

  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    throw new Error('Không nhận được kết quả hoàn thành Task.');
  }

  return mapCompleteLinkedVideoTaskRpcRow(row as CompleteLinkedVideoTaskRpcRow);
}
