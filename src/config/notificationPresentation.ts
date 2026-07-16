import {
  CalendarDays,
  CheckCircle2,
  Clapperboard,
  ClipboardList,
  FilePlus2,
  Trash2,
  UserCheck,
  UserPlus,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { NotificationType } from '../types/notification';

export type NotificationAccent = 'calendar' | 'assignment' | 'task' | 'success' | 'warning';

export interface NotificationPresentation {
  icon: LucideIcon;
  category: 'calendar' | 'content_plan' | 'video_task';
  accent: NotificationAccent;
}

export const NOTIFICATION_PRESENTATION: Record<NotificationType, NotificationPresentation> = {
  shoot_created: { icon: CalendarDays, category: 'calendar', accent: 'calendar' },
  shoot_updated: { icon: CalendarDays, category: 'calendar', accent: 'calendar' },
  shoot_cancelled: { icon: Trash2, category: 'calendar', accent: 'warning' },
  shoot_member_added: { icon: UserPlus, category: 'calendar', accent: 'assignment' },
  shoot_member_removed: { icon: Trash2, category: 'calendar', accent: 'warning' },
  content_plan_created: { icon: FilePlus2, category: 'content_plan', accent: 'assignment' },
  content_plan_assigned: { icon: UserCheck, category: 'content_plan', accent: 'assignment' },
  content_plan_reassigned: { icon: UserCheck, category: 'content_plan', accent: 'assignment' },
  content_plan_deleted: { icon: Trash2, category: 'content_plan', accent: 'warning' },
  video_task_created: { icon: Clapperboard, category: 'video_task', accent: 'task' },
  video_task_accepted: { icon: ClipboardList, category: 'video_task', accent: 'task' },
  video_task_execution_updated: { icon: ClipboardList, category: 'video_task', accent: 'task' },
  video_task_completed: { icon: CheckCircle2, category: 'video_task', accent: 'success' },
  video_task_deleted: { icon: Trash2, category: 'video_task', accent: 'warning' },
};

export function getNotificationPresentation(type: NotificationType) {
  return NOTIFICATION_PRESENTATION[type];
}
