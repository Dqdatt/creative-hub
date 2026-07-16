export const NOTIFICATION_TYPES = [
  'shoot_created',
  'shoot_updated',
  'shoot_cancelled',
  'shoot_member_added',
  'shoot_member_removed',
  'content_plan_created',
  'content_plan_assigned',
  'content_plan_reassigned',
  'content_plan_deleted',
  'video_task_created',
  'video_task_accepted',
  'video_task_execution_updated',
  'video_task_completed',
  'video_task_deleted',
] as const;

export type NotificationType = typeof NOTIFICATION_TYPES[number];

export const NOTIFICATION_ENTITY_TYPES = ['shoot', 'content_plan', 'video_task'] as const;

export type NotificationEntityType = typeof NOTIFICATION_ENTITY_TYPES[number];

export type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

export type NotificationMetadata = Record<string, JsonValue>;

export interface InternalNotification {
  id: string;
  recipientId: string;
  actorId: string | null;
  type: NotificationType;
  title: string;
  body: string;
  entityType: NotificationEntityType | null;
  entityId: string | null;
  actionUrl: string | null;
  metadata: NotificationMetadata;
  eventKey: string | null;
  readAt: string | null;
  createdAt: string;
}

export interface RecentNotificationsOptions {
  limit?: number;
}

export interface NotificationsSnapshot {
  notifications: InternalNotification[];
  unreadCount: number;
}

export interface NotificationSubscriptionHandlers {
  onInsert: (notification: InternalNotification) => void;
  onUpdate?: (notification: InternalNotification) => void;
  onDelete?: (notificationId: string) => void;
  onError?: (message: string) => void;
  onReconnect?: () => void;
}

export interface DeleteNotificationResult {
  notificationId: string;
  wasUnread: boolean;
}

export interface DeleteOldNotificationsResult {
  deletedCount: number;
  unreadDeletedCount: number;
}
