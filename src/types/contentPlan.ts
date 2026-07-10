export type ContentPlanCategory = 'Video dài' | 'Short/Reels' | 'Livestream' | 'Ảnh' | 'Motion' | 'Ads';

export interface ContentPlanItem {
  id: string;
  air_date: string;
  video_name: string;
  note: string;
  category: ContentPlanCategory;
  editor_id: string;
}

export interface ContentPlanFormData {
  air_date: string;
  video_name: string;
  note: string;
  category: ContentPlanCategory;
  editor_id: string;
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
