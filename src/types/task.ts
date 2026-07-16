// Core data types for the Video Task module

export type TaskStatus = 'Chờ' | 'Đang làm' | 'Đã xong';
export type TaskCategory = 'Video dài' | 'Motion' | 'Ads';
export type TaskPriority = '' | 'Gấp';

export interface Editor {
  id: string;
  profileId?: string;
  name: string;      // Full name
  short: string;     // Display name
  shortName?: string; // alias
  role: string;
  color: string;     // Accent color
  bgColor: string;   // Soft background color
  initial: string;   // Single letter for avatar
  avatarUrl?: string;
  crewKey: string;   // Legacy only; shoot workload uses shoot_editors
}

export interface VideoTask {
  dbId?: string;     // Supabase row id
  contentPlanId: string | null; // null means manually created Video tháng task
  id: number;        // Display STT
  name: string;
  resize: string;
  editorId: string;  // references Editor.id
  orderTeam: string;
  category: TaskCategory;
  receiveDate: string;
  returnDate: string;
  airDate: string;
  status: TaskStatus;
  priority: TaskPriority;
  link: string;
}

export interface TaskFormData {
  name: string;
  resize: string;
  editorId: string;
  orderTeam: string;
  category: TaskCategory;
  receiveDate: string;
  returnDate: string;
  airDate: string;
  status: TaskStatus;
  priority: TaskPriority;
  link: string;
}

export interface CreateLinkedVideoTaskInput extends TaskFormData {
  contentPlanId: string;
}

export interface AcceptLinkedVideoTaskInput {
  taskId: string;
  receiveDate: string;
  returnDate: string;
}

export interface AcceptLinkedVideoTaskResult {
  videoTaskId: string;
  contentPlanId: string;
  status: TaskStatus;
  receiveDate: string;
  returnDate: string;
  airDate: string;
  editorId: string;
}

export interface CompleteLinkedVideoTaskInput {
  taskId: string;
  resultLink: string;
}

export interface CompleteLinkedVideoTaskResult {
  videoTaskId: string;
  contentPlanId: string;
  status: TaskStatus;
  resultLink: string;
  contentPlanLink: string;
  completedAt: string;
  editorId: string;
  airDate: string;
}

export interface LinkedVideoTaskExecutionData {
  orderTeam: string;
  priority: TaskPriority;
  resize: string;
  receiveDate: string;
  returnDate: string;
  link: string;
}

export interface UpdateLinkedVideoTaskExecutionInput extends LinkedVideoTaskExecutionData {
  taskId: string;
}

export interface UpdateLinkedVideoTaskExecutionResult {
  videoTaskId: string;
  contentPlanId: string;
  status: TaskStatus;
  orderTeam: string;
  priority: TaskPriority;
  resize: string;
  receiveDate: string;
  returnDate: string;
  resultLink: string;
  editorId: string;
  changedFields: string[];
}
