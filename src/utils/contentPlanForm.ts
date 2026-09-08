import type { ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';

export function toContentPlanFormData(item: ContentPlanItem): ContentPlanFormData {
  return {
    air_date: item.air_date,
    video_name: item.video_name,
    note: item.note,
    category: item.category,
    editor_id: item.editor_id,
    link: item.link,
  };
}

export function hasContentFieldChanges(current: ContentPlanItem, nextData: ContentPlanFormData) {
  return current.air_date !== nextData.air_date
    || current.video_name !== nextData.video_name
    || current.note !== nextData.note
    || current.category !== nextData.category
    || current.link !== nextData.link;
}

export function getDefaultContentDate(monthValue: string, selectedDate: string) {
  return selectedDate.startsWith(monthValue) ? selectedDate : `${monthValue}-01`;
}
