export type ActivityEntityType = 'video_task' | 'shoot' | 'content_plan' | 'profile';

export type ActivityAction =
  | 'created'
  | 'updated'
  | 'deleted'
  | 'status_changed'
  | 'assigned'
  | 'uploaded'
  | 'password_changed'
  | 'content_plan_assigned'
  | 'content_plan_reassigned'
  | 'video_task_generated'
  | 'video_task_editor_changed'
  | 'video_task_accepted'
  | 'video_task_execution_updated'
  | 'video_task_completed'
  | 'content_plan_completed';

export interface ActivityLog {
  id: string;
  actorId: string | null;
  actorName: string;
  entityType: ActivityEntityType;
  entityId: string | null;
  action: ActivityAction;
  title: string;
  description: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface ActivityLogInput {
  actorId: string | null | undefined;
  entityType: ActivityEntityType;
  entityId?: string | null;
  action: ActivityAction;
  title?: string | null;
  description?: string | null;
  metadata?: Record<string, unknown>;
}
