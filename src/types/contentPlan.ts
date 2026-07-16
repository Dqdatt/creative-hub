export type ContentPlanCategory = 'Video dài' | 'Short/Reels' | 'Livestream' | 'Ảnh' | 'Motion' | 'Ads';

export interface ContentPlanItem {
  id: string;
  air_date: string;
  video_name: string;
  note: string;
  category: ContentPlanCategory;
  editor_id: string;
  link: string;
  hasLinkedTask: boolean;
}

export interface ContentPlanFormData {
  air_date: string;
  video_name: string;
  note: string;
  category: ContentPlanCategory;
  editor_id: string;
  link: string;
}

export interface ContentPlanEditorOption {
  id: string;
  profile_id: string;
  name: string;
  short: string;
  initial: string;
  color: string;
  bgColor: string;
  avatarUrl: string;
  role: string;
}

export interface AssignContentPlanEditorResult {
  contentPlanId: string;
  videoTaskId: string | null;
  editorId: string | null;
  taskCreated: boolean;
  taskStatus: string | null;
  airDate: string;
}
