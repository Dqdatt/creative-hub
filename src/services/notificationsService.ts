import type {
  RealtimeChannel,
  RealtimePostgresDeletePayload,
  RealtimePostgresInsertPayload,
  RealtimePostgresUpdatePayload,
} from '@supabase/supabase-js';
import { supabase, supabaseConfigError } from '../lib/supabase';
import type {
  InternalNotification,
  NotificationEntityType,
  NotificationMetadata,
  NotificationSubscriptionHandlers,
  NotificationType,
  RecentNotificationsOptions,
  DeleteNotificationResult,
  DeleteOldNotificationsResult,
} from '../types/notification';

const DEFAULT_RECENT_LIMIT = 15;
const MAX_RECENT_LIMIT = 50;

type Nullable<T> = T | null;

interface NotificationRow {
  id: string;
  recipient_id: string;
  actor_id: Nullable<string>;
  type: NotificationType;
  title: string;
  body: string;
  entity_type: Nullable<NotificationEntityType>;
  entity_id: Nullable<string>;
  action_url: Nullable<string>;
  metadata: NotificationMetadata | null;
  event_key: Nullable<string>;
  read_at: Nullable<string>;
  created_at: string;
}

interface DeleteNotificationRpcRow {
  notification_id: string;
  was_unread: boolean;
}

interface DeleteOldNotificationsRpcRow {
  deleted_count: number;
  unread_deleted_count: number;
}

function requireSupabase() {
  if (!supabase) {
    throw new Error(supabaseConfigError ? 'Kết nối dữ liệu chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : 'Kết nối dữ liệu chưa sẵn sàng.');
  }
  return supabase;
}

function mapDatabaseError(error: { message?: string; code?: string } | null, fallback: string) {
  if (!error) return fallback;

  const message = (error.message ?? '').toLowerCase();
  if (error.code === '42501' || message.includes('row-level security') || message.includes('permission denied')) {
    return 'Bạn không có quyền xử lý thông báo này.';
  }
  if (message.includes('failed to fetch') || message.includes('network')) {
    return 'Không thể kết nối dữ liệu. Vui lòng kiểm tra mạng.';
  }
  if (message.includes('does not exist')) {
    return 'Nền tảng thông báo chưa sẵn sàng.';
  }

  return fallback;
}

function normalizeLimit(limit: number | undefined) {
  if (!Number.isFinite(limit)) return DEFAULT_RECENT_LIMIT;
  return Math.min(Math.max(Math.trunc(limit ?? DEFAULT_RECENT_LIMIT), 1), MAX_RECENT_LIMIT);
}

function isMetadata(value: unknown): value is NotificationMetadata {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function mapNotificationRow(row: NotificationRow): InternalNotification {
  return {
    id: row.id,
    recipientId: row.recipient_id,
    actorId: row.actor_id,
    type: row.type,
    title: row.title,
    body: row.body,
    entityType: row.entity_type,
    entityId: row.entity_id,
    actionUrl: row.action_url,
    metadata: isMetadata(row.metadata) ? row.metadata : {},
    eventKey: row.event_key,
    readAt: row.read_at,
    createdAt: row.created_at,
  };
}

export async function getRecentNotifications(options?: RecentNotificationsOptions): Promise<InternalNotification[]> {
  const client = requireSupabase();
  const limit = normalizeLimit(options?.limit);

  const { data, error } = await client
    .from('notifications')
    .select(`
      id,
      recipient_id,
      actor_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      action_url,
      metadata,
      event_key,
      read_at,
      created_at
    `)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new Error(mapDatabaseError(error, 'Không thể tải thông báo.'));

  return ((data ?? []) as NotificationRow[]).map(mapNotificationRow);
}

export async function getUnreadNotificationCount(): Promise<number> {
  const client = requireSupabase();

  const { count, error } = await client
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .is('read_at', null);

  if (error) throw new Error(mapDatabaseError(error, 'Không thể tải số thông báo chưa đọc.'));

  return count ?? 0;
}

export async function markNotificationRead(notificationId: string): Promise<string> {
  const client = requireSupabase();

  const { data, error } = await client.rpc('mark_notification_read', {
    p_notification_id: notificationId,
  });

  if (error) throw new Error(mapDatabaseError(error, 'Không thể cập nhật trạng thái thông báo.'));
  if (typeof data !== 'string') throw new Error('Không nhận được thời điểm đọc thông báo.');

  return data;
}

export async function markAllNotificationsRead(): Promise<number> {
  const client = requireSupabase();

  const { data, error } = await client.rpc('mark_all_notifications_read');

  if (error) throw new Error(mapDatabaseError(error, 'Không thể cập nhật trạng thái thông báo.'));
  if (typeof data !== 'number') return 0;

  return data;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function isDeleteNotificationRpcRow(value: unknown): value is DeleteNotificationRpcRow {
  return isRecord(value)
    && typeof value.notification_id === 'string'
    && typeof value.was_unread === 'boolean';
}

function isDeleteOldNotificationsRpcRow(value: unknown): value is DeleteOldNotificationsRpcRow {
  return isRecord(value)
    && typeof value.deleted_count === 'number'
    && typeof value.unread_deleted_count === 'number';
}

function firstRpcRow(data: unknown): unknown {
  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

export async function deleteNotification(notificationId: string): Promise<DeleteNotificationResult> {
  const client = requireSupabase();

  const { data, error } = await client.rpc('delete_notification', {
    p_notification_id: notificationId,
  });

  if (error) throw new Error(mapDatabaseError(error, 'Không thể xóa thông báo.'));
  const row = firstRpcRow(data);
  if (!isDeleteNotificationRpcRow(row)) throw new Error('Không nhận được kết quả xóa thông báo.');

  return {
    notificationId: row.notification_id,
    wasUnread: Boolean(row.was_unread),
  };
}

export async function deleteNotificationsOlderThan(days = 15): Promise<DeleteOldNotificationsResult> {
  const client = requireSupabase();
  const normalizedDays = Math.min(Math.max(Math.trunc(days), 1), 365);

  const { data, error } = await client.rpc('delete_notifications_older_than', {
    p_days: normalizedDays,
  });

  if (error) throw new Error(mapDatabaseError(error, 'Không thể xóa thông báo cũ.'));
  const row = firstRpcRow(data);

  return {
    deletedCount: isDeleteOldNotificationsRpcRow(row) ? row.deleted_count : 0,
    unreadDeletedCount: isDeleteOldNotificationsRpcRow(row) ? row.unread_deleted_count : 0,
  };
}

export function subscribeToNotifications(
  profileId: string,
  handlers: NotificationSubscriptionHandlers,
): RealtimeChannel | null {
  if (!supabase) return null;

  const channel = supabase.channel(`notifications-${profileId}`);

  channel.on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'notifications',
      filter: `recipient_id=eq.${profileId}`,
    },
    (payload: RealtimePostgresInsertPayload<NotificationRow>) => {
      handlers.onInsert(mapNotificationRow(payload.new));
    }
  );

  channel.on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'notifications',
      filter: `recipient_id=eq.${profileId}`,
    },
    (payload: RealtimePostgresUpdatePayload<NotificationRow>) => {
      handlers.onUpdate?.(mapNotificationRow(payload.new));
    }
  );

  channel.on(
    'postgres_changes',
    {
      event: 'DELETE',
      schema: 'public',
      table: 'notifications',
      filter: `recipient_id=eq.${profileId}`,
    },
    (payload: RealtimePostgresDeletePayload<Partial<NotificationRow>>) => {
      const notificationId = payload.old.id;
      if (notificationId) handlers.onDelete?.(notificationId);
    }
  );

  channel.subscribe((status) => {
    if (status === 'SUBSCRIBED') {
      handlers.onReconnect?.();
    }
    if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
      const message = 'Realtime thông báo tạm thời gián đoạn.';
      if (import.meta.env.DEV) console.warn('[Notifications]', message, status);
      handlers.onError?.(message);
    }
  });

  return channel;
}

export async function unsubscribeFromNotifications(channel: RealtimeChannel | null) {
  if (!supabase || !channel) return;
  await supabase.removeChannel(channel);
}
