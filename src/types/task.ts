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
