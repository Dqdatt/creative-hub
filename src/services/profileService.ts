import type { User } from '@supabase/supabase-js';
import { ROLE_LABELS, normalizeRole } from '../config/permissions';
import { supabase, supabaseConfigError } from '../lib/supabase';
import type { EmployeeProfile } from '../types/profile';

const AVATAR_BUCKET = 'avatars';
const DEFAULT_DEPARTMENT = 'Team Marketing';

interface ProfileRow {
  id: string;
  email: string | null;
  full_name: string | null;
  display_name: string | null;
  short_name: string | null;
  phone: string | null;
  role: string | null;
  department: string | null;
  avatar_url: string | null;
}

interface ProfileUpdateData {
  fullName: string;
  displayName: string;
  phone: string;
  department: string;
  avatarUrl?: string | null;
}

function requireSupabase() {
  if (!supabase) {
    throw new Error(supabaseConfigError ? 'Kết nối hồ sơ chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : 'Kết nối hồ sơ chưa sẵn sàng.');
  }
  return supabase;
}

function readUserMeta(value: unknown) {
  return typeof value === 'string' ? value : '';
}

function mapDatabaseError(error: { message?: string; code?: string } | null) {
  if (!error) return 'Không thể xử lý hồ sơ. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền cập nhật hồ sơ này.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('violates check constraint')) {
    return 'Dữ liệu hồ sơ chưa đúng định dạng.';
  }

  return error.message || 'Không thể xử lý hồ sơ. Vui lòng thử lại.';
}

function mapStorageError(error: { message?: string; statusCode?: string } | null) {
  if (!error) return 'Không thể xử lý ảnh đại diện. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (message.includes('bucket not found') || message.includes('not found')) {
    return 'Chưa thể lưu ảnh đại diện. Vui lòng liên hệ quản trị viên.';
  }
  if (message.includes('row-level security') || message.includes('permission denied') || error.statusCode === '403') {
    return 'Bạn không có quyền tải ảnh đại diện.';
  }
  if (message.includes('payload too large') || message.includes('exceeded')) {
    return 'Ảnh đại diện quá lớn.';
  }

  return error.message || 'Không thể xử lý ảnh đại diện. Vui lòng thử lại.';
}

function fallbackProfileFromUser(user: User): EmployeeProfile {
  const fullName = readUserMeta(user.user_metadata.full_name)
    || readUserMeta(user.user_metadata.name)
    || user.email?.split('@')[0]
    || 'Nhân sự';
  const displayName = readUserMeta(user.user_metadata.display_name)
    || readUserMeta(user.user_metadata.name)
    || fullName;

  return {
    fullName,
    displayName,
    email: user.email ?? '',
    phone: readUserMeta(user.user_metadata.phone),
    role: ROLE_LABELS.editor,
    department: readUserMeta(user.user_metadata.department) || DEFAULT_DEPARTMENT,
    avatarUrl: readUserMeta(user.user_metadata.avatar_url),
  };
}

function mapProfileRow(row: ProfileRow, user: User): EmployeeProfile {
  const fallbackProfile = fallbackProfileFromUser(user);
  const role = normalizeRole(row.role);
  const displayName = row.display_name || row.short_name || row.full_name || fallbackProfile.displayName;

  return {
    fullName: row.full_name || displayName,
    displayName,
    email: row.email || user.email || fallbackProfile.email,
    phone: row.phone || '',
    role: ROLE_LABELS[role],
    department: row.department || DEFAULT_DEPARTMENT,
    avatarUrl: row.avatar_url || '',
  };
}

function cleanFileName(fileName: string) {
  const cleanName = fileName
    .toLowerCase()
    .replace(/[^a-z0-9.]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return cleanName || 'avatar.png';
}

export async function fetchProfile(user: User): Promise<EmployeeProfile> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('profiles')
    .select('id, email, full_name, display_name, short_name, phone, role, department, avatar_url')
    .eq('id', user.id)
    .maybeSingle();

  if (error) throw new Error(mapDatabaseError(error));
  if (!data) throw new Error('Chưa tìm thấy hồ sơ người dùng trong public.profiles.');

  return mapProfileRow(data as ProfileRow, user);
}

export async function updateProfile(userId: string, data: ProfileUpdateData) {
  const client = requireSupabase();
  const payload: Record<string, string | null> = {
    full_name: data.fullName.trim(),
    display_name: data.displayName.trim(),
    short_name: data.displayName.trim(),
    phone: data.phone.trim() || null,
    department: data.department.trim() || DEFAULT_DEPARTMENT,
  };

  if ('avatarUrl' in data) {
    payload.avatar_url = data.avatarUrl?.trim() || null;
  }

  const { error } = await client
    .from('profiles')
    .update(payload)
    .eq('id', userId);

  if (error) throw new Error(mapDatabaseError(error));
}

export async function uploadAvatar(userId: string, file: File) {
  const client = requireSupabase();
  const filePath = `${userId}/${Date.now()}-${cleanFileName(file.name)}`;
  const { error } = await client.storage
    .from(AVATAR_BUCKET)
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: true,
    });

  if (error) throw new Error(mapStorageError(error));

  const { data } = client.storage
    .from(AVATAR_BUCKET)
    .getPublicUrl(filePath);

  return data.publicUrl;
}

export async function updatePassword(email: string, currentPassword: string, newPassword: string) {
  const client = requireSupabase();
  const { error: signInError } = await client.auth.signInWithPassword({
    email,
    password: currentPassword,
  });

  if (signInError) {
    throw new Error('Mật khẩu hiện tại chưa đúng.');
  }

  const { error } = await client.auth.updateUser({ password: newPassword });

  if (error) {
    const message = error.message.toLowerCase();
    if (message.includes('weak password') || message.includes('should be at least')) {
      throw new Error('Mật khẩu mới chưa đủ mạnh.');
    }
    if (message.includes('requires recent login') || message.includes('reauthentication')) {
      throw new Error('Phiên đăng nhập cần xác thực lại trước khi đổi mật khẩu.');
    }
    throw new Error('Không thể cập nhật mật khẩu. Vui lòng thử lại.');
  }
}
