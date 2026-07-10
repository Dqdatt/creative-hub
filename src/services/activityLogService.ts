import { supabase, supabaseConfigError } from '../lib/supabase';
import type { ActivityLog, ActivityLogInput, ActivityAction, ActivityEntityType } from '../types/activityLog';

type Nullable<T> = T | null;

interface ProfileRow {
  id: string;
  display_name: Nullable<string>;
  short_name: Nullable<string>;
  full_name: Nullable<string>;
  email: Nullable<string>;
}

interface ActivityLogRow {
  id: string;
  actor_id: Nullable<string>;
  entity_type: ActivityEntityType;
  entity_id: Nullable<string>;
  action: ActivityAction;
  title: Nullable<string>;
  description: Nullable<string>;
  metadata: Record<string, unknown> | null;
  created_at: string;
  profiles: ProfileRow | ProfileRow[] | null;
}

function firstProfile(profile: ActivityLogRow['profiles']) {
  if (Array.isArray(profile)) return profile[0] ?? null;
  return profile;
}

function mapDatabaseError(error: { message?: string; code?: string } | null) {
  if (!error) return 'Không thể xử lý nhật ký hoạt động. Vui lòng thử lại.';

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền xử lý nhật ký hoạt động.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối dữ liệu. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('does not exist')) {
    return 'Chưa thể tải nhật ký hoạt động.';
  }

  return error.message || 'Không thể xử lý nhật ký hoạt động. Vui lòng thử lại.';
}

function mapActivityLogRow(row: ActivityLogRow): ActivityLog {
  const profile = firstProfile(row.profiles);
  const actorName = profile?.display_name
    || profile?.short_name
    || profile?.full_name
    || profile?.email
    || 'Hệ thống';

  return {
    id: row.id,
    actorId: row.actor_id,
    actorName,
    entityType: row.entity_type,
    entityId: row.entity_id,
    action: row.action,
    title: row.title ?? '',
    description: row.description ?? '',
    metadata: row.metadata ?? {},
    createdAt: row.created_at,
  };
}

export async function logActivity(input: ActivityLogInput) {
  if (!supabase) {
    console.error(supabaseConfigError ?? 'Chưa cấu hình dữ liệu, bỏ qua activity log.');
    return;
  }

  try {
    const { error } = await supabase
      .from('activity_logs')
      .insert({
        actor_id: input.actorId ?? null,
        entity_type: input.entityType,
        entity_id: input.entityId ?? null,
        action: input.action,
        title: input.title ?? null,
        description: input.description ?? null,
        metadata: input.metadata ?? {},
      });

    if (error) {
      console.error('Không thể ghi activity log:', error);
    }
  } catch (error) {
    console.error('Không thể ghi activity log:', error);
  }
}

export async function fetchRecentActivityLogs(limit = 20): Promise<ActivityLog[]> {
  if (!supabase) {
    throw new Error(supabaseConfigError ?? 'Chưa cấu hình dữ liệu.');
  }

  const { data, error } = await supabase
    .from('activity_logs')
    .select(`
      id,
      actor_id,
      entity_type,
      entity_id,
      action,
      title,
      description,
      metadata,
      created_at,
      profiles!activity_logs_actor_id_fkey (
        id,
        display_name,
        short_name,
        full_name,
        email
      )
    `)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new Error(mapDatabaseError(error));

  return ((data ?? []) as unknown as ActivityLogRow[]).map(mapActivityLogRow);
}
