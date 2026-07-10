import { ROLE_LABELS, normalizeRole } from '../config/permissions';
import { supabase, supabaseConfigError } from '../lib/supabase';
import { logActivity } from './activityLogService';
import type { CreateMemberFormData, ManagedUserProfile, UserProfileFormData } from '../types/userManagement';

type Nullable<T> = T | null;

interface ProfileRow {
  id: string;
  email: Nullable<string>;
  full_name: Nullable<string>;
  display_name: Nullable<string>;
  short_name: Nullable<string>;
  phone: Nullable<string>;
  role: Nullable<string>;
  department: Nullable<string>;
  avatar_url: Nullable<string>;
  editor_code: Nullable<string>;
  crew_key: Nullable<string>;
  is_editor_member: Nullable<boolean>;
  active: Nullable<boolean>;
  is_active: Nullable<boolean>;
  created_at: string;
  updated_at: Nullable<string>;
}

function requireSupabase() {
  if (!supabase) {
    throw new Error(supabaseConfigError ? 'Quản lý thành viên chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : 'Quản lý thành viên chưa sẵn sàng.');
  }
  return supabase;
}

function mapDatabaseError(error: { message?: string; code?: string } | null) {
  if (!error) return 'Không thể xử lý thành viên. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền quản lý thành viên.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('is_editor_member')) {
    return 'Cấu hình team editor chưa sẵn sàng. Vui lòng liên hệ quản trị viên.';
  }
  if (message.includes('is_active') || message.includes('does not exist')) {
    return 'Quản lý thành viên chưa sẵn sàng. Vui lòng liên hệ quản trị viên.';
  }
  if (message.includes('violates check constraint')) {
    return 'Vai trò hoặc dữ liệu thành viên chưa đúng định dạng.';
  }

  return error.message || 'Không thể xử lý thành viên. Vui lòng thử lại.';
}

interface FunctionErrorBody {
  error: string;
  code?: string;
  step?: string;
  details?: string;
  hint?: string;
}

async function readFunctionErrorBody(error: unknown): Promise<FunctionErrorBody | null> {
  if (!error || typeof error !== 'object' || !('context' in error)) return null;

  const context = (error as { context?: unknown }).context;
  if (!(context instanceof Response)) return null;

  try {
    const body = await context.clone().json();
    if (body && typeof body === 'object' && 'error' in body) {
      const rawError = (body as { error?: unknown }).error;
      const errorMessage = typeof rawError === 'string'
        ? rawError
        : rawError && typeof rawError === 'object' && 'message' in rawError && typeof rawError.message === 'string'
          ? rawError.message
          : 'Không thể xử lý tài khoản. Vui lòng thử lại.';

      return {
        error: errorMessage,
        code: 'code' in body && typeof body.code === 'string' ? body.code : undefined,
        step: 'step' in body && typeof body.step === 'string' ? body.step : undefined,
        details: 'details' in body && typeof body.details === 'string' ? body.details : undefined,
        hint: 'hint' in body && typeof body.hint === 'string' ? body.hint : undefined,
      };
    }
  } catch {
    try {
      const text = await context.clone().text();
      return text ? { error: text } : null;
    } catch {
      return null;
    }
  }

  return null;
}

async function mapFunctionError(error: { message?: string } | null) {
  if (!error) return 'Không thể xử lý tài khoản. Vui lòng thử lại.';

  const bodyMessage = await readFunctionErrorBody(error);
  if (bodyMessage?.error) {
    const debugDetails = import.meta.env.DEV
      ? [
        bodyMessage.step ? `Bước: ${bodyMessage.step}` : '',
        bodyMessage.code ? `Mã: ${bodyMessage.code}` : '',
        bodyMessage.details ? `Chi tiết: ${bodyMessage.details}` : '',
        bodyMessage.hint ? `Gợi ý: ${bodyMessage.hint}` : '',
      ].filter(Boolean).join(' · ')
      : '';

    return debugDetails ? `${bodyMessage.error} (${debugDetails})` : bodyMessage.error;
  }

  const message = error.message ?? '';
  if (message.trim() === '{}' || !message.trim()) {
    return 'Không thể xử lý tài khoản. Vui lòng thử lại.';
  }
  const lowerMessage = message.toLowerCase();
  if (lowerMessage.includes('failed to fetch') || lowerMessage.includes('cors') || lowerMessage.includes('network')) {
    return 'Không thể xử lý tài khoản lúc này. Vui lòng liên hệ quản trị viên.';
  }
  if (lowerMessage.includes('non-2xx') || lowerMessage.includes('functionshttp')) {
    return 'Không thể xử lý tài khoản lúc này. Vui lòng thử lại sau.';
  }

  return message || 'Không thể xử lý tài khoản. Vui lòng thử lại.';
}

function mapProfile(row: ProfileRow): ManagedUserProfile {
  const role = normalizeRole(row.role);
  const displayName = row.display_name || row.short_name || row.full_name || row.email || 'Thành viên';

  return {
    id: row.id,
    email: row.email ?? '',
    fullName: row.full_name || displayName,
    displayName,
    phone: row.phone ?? '',
    role,
    roleLabel: ROLE_LABELS[role],
    department: row.department || 'Team Marketing',
    avatarUrl: row.avatar_url ?? '',
    editorCode: row.editor_code ?? '',
    crewKey: row.crew_key ?? '',
    isEditorMember: row.is_editor_member ?? (Boolean(row.editor_code) || role === 'editor'),
    isActive: row.is_active ?? row.active ?? true,
    createdAt: row.created_at,
    updatedAt: row.updated_at ?? row.created_at,
  };
}

function toProfilePayload(data: UserProfileFormData) {
  return {
    full_name: data.fullName.trim(),
    display_name: data.displayName.trim(),
    short_name: data.displayName.trim(),
    phone: data.phone.trim() || null,
    role: data.role,
    department: data.department.trim() || 'Team Marketing',
    editor_code: data.isEditorMember ? data.editorCode.trim().toLowerCase() || null : null,
    crew_key: data.crewKey.trim().toUpperCase() || null,
    is_editor_member: data.isEditorMember,
    active: data.isActive,
    is_active: data.isActive,
  };
}

function isEmailChanged(data: UserProfileFormData, previousProfile?: ManagedUserProfile) {
  if (!previousProfile) return false;
  return data.email.trim().toLowerCase() !== previousProfile.email.trim().toLowerCase();
}

function hasProfileFieldChanges(data: UserProfileFormData, previousProfile?: ManagedUserProfile) {
  if (!previousProfile) return true;

  return (
    data.fullName.trim() !== previousProfile.fullName ||
    data.displayName.trim() !== previousProfile.displayName ||
    data.phone.trim() !== previousProfile.phone ||
    data.role !== previousProfile.role ||
    data.department.trim() !== previousProfile.department ||
    data.editorCode.trim().toLowerCase() !== previousProfile.editorCode ||
    data.crewKey.trim().toUpperCase() !== previousProfile.crewKey ||
    data.isEditorMember !== previousProfile.isEditorMember ||
    data.isActive !== previousProfile.isActive
  );
}

async function getAccessToken() {
  const client = requireSupabase();
  const { data: sessionData, error: sessionError } = await client.auth.getSession();
  const accessToken = sessionData.session?.access_token;

  if (sessionError || !accessToken) {
    throw new Error('Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.');
  }

  return accessToken;
}

async function invokeManageUser<TResponse = unknown>(body: Record<string, unknown>): Promise<TResponse> {
  const client = requireSupabase();
  const accessToken = await getAccessToken();
  const { data, error } = await client.functions.invoke('manage-user', {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    body,
  });

  if (error) throw new Error(await mapFunctionError(error));
  return data as TResponse;
}

export async function fetchUserProfiles(): Promise<ManagedUserProfile[]> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('profiles')
    .select(`
      id,
      email,
      full_name,
      display_name,
      short_name,
      phone,
      role,
      department,
      avatar_url,
      editor_code,
      crew_key,
      is_editor_member,
      active,
      is_active,
      created_at,
      updated_at
    `)
    .order('full_name', { ascending: true });

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as ProfileRow[]).map(mapProfile);
}

export async function updateManagedUserProfile(
  profileId: string,
  data: UserProfileFormData,
  actorId?: string | null,
  previousProfile?: ManagedUserProfile
) {
  const client = requireSupabase();

  const emailChanged = isEmailChanged(data, previousProfile);
  if (emailChanged) {
    await invokeManageUser({
      action: 'update_email',
      user_id: profileId,
      email: data.email.trim().toLowerCase(),
    });
  }

  const shouldUpdateProfile = hasProfileFieldChanges(data, previousProfile);
  if (shouldUpdateProfile) {
    const payload = toProfilePayload(data);
    const { error } = await client
      .from('profiles')
      .update(payload)
      .eq('id', profileId);

    if (error) throw new Error(mapDatabaseError(error));
  }

  const roleChanged = previousProfile?.role && previousProfile.role !== data.role;
  const statusChanged = previousProfile && previousProfile.isActive !== data.isActive;

  if (shouldUpdateProfile) {
    void logActivity({
      actorId,
      entityType: 'profile',
      entityId: profileId,
      action: 'updated',
      title: data.displayName || data.fullName,
      description: roleChanged
        ? `Đã đổi vai trò thành viên "${data.displayName || data.fullName}" sang ${ROLE_LABELS[data.role]}.`
        : statusChanged
          ? `Đã cập nhật trạng thái thành viên "${data.displayName || data.fullName}".`
          : `Đã cập nhật hồ sơ thành viên "${data.displayName || data.fullName}".`,
      metadata: {
        previous_role: previousProfile?.role,
        role: data.role,
        previous_is_active: previousProfile?.isActive,
        is_active: data.isActive,
        editor_code: data.editorCode,
        is_editor_member: data.isEditorMember,
        crew_key: data.crewKey,
        email_updated: emailChanged,
      },
    });
  }
}

export async function createManagedUser(data: CreateMemberFormData, actorId?: string | null) {
  const client = requireSupabase();
  const accessToken = await getAccessToken();

  const { data: createdUser, error } = await client.functions.invoke('create-user', {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    body: {
      email: data.email.trim().toLowerCase(),
      password: data.password,
      full_name: data.fullName.trim(),
      display_name: data.displayName.trim() || data.fullName.trim(),
      phone: data.phone.trim(),
      role: data.role,
      department: data.department.trim() || 'Team Marketing',
      editor_code: data.isEditorMember ? data.editorCode.trim().toLowerCase() : '',
      is_editor_member: data.isEditorMember,
      crew_key: data.crewKey.trim().toUpperCase(),
    },
  });

  if (error) throw new Error(await mapFunctionError(error));

  const createdUserId = typeof createdUser === 'object' && createdUser && 'user_id' in createdUser
    ? String(createdUser.user_id)
    : null;

  void logActivity({
    actorId,
    entityType: 'profile',
    entityId: createdUserId,
    action: 'created',
    title: data.displayName || data.fullName,
    description: `Đã tạo thành viên "${data.displayName || data.fullName}".`,
    metadata: {
      email: data.email.trim().toLowerCase(),
      role: data.role,
      department: data.department,
      editor_code: data.editorCode,
      is_editor_member: data.isEditorMember,
      crew_key: data.crewKey,
    },
  });
}

export async function deleteManagedUserAccount(targetUser: ManagedUserProfile) {
  await invokeManageUser({
    action: 'delete_user',
    user_id: targetUser.id,
  });
}
