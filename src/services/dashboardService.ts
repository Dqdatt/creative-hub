import { fetchShoots } from './shootsService';
import { fetchContentPlan, fetchContentPlanEditorOptions } from './contentPlanService';
import type { ContentPlanItem } from '../types/contentPlan';
import { isSafeHttpUrl } from '../utils/url';
import type { ShootSchedule } from '../types/shoot';
import type { Editor, VideoTask } from '../types/task';
import { getMonthRange, getCurrentMonthValue, isDisplayDateInMonth, shiftMonthValue } from '../utils/month';

export interface DashboardData {
  tasks: VideoTask[];
  shoots: ShootSchedule[];
  editors: Editor[];
  previousTasks: VideoTask[];
  previousShoots: ShootSchedule[];
  previousMonthValue: string;
}

function toDashboardEditor(editor: Awaited<ReturnType<typeof fetchContentPlanEditorOptions>>[number]): Editor {
  return {
    id: editor.id,
    profileId: editor.profile_id,
    name: editor.name,
    short: editor.short,
    shortName: editor.short,
    role: 'Video Editor',
    color: editor.color,
    bgColor: editor.bgColor,
    initial: editor.initial,
    avatarUrl: editor.avatarUrl,
    crewKey: '',
  };
}

// v2.0.0: dashboard tính từ danh sách Task (content_plan), không còn từ Video tháng.
// - Task thuộc tháng theo ngày Air (ngày 1 đến ngày cuối tháng).
// - Chỉ task có link thành phẩm mới là "Đã xong"; có editor = "Đang làm"; chưa có editor = "Chờ".
function toDashboardTask(item: ContentPlanItem, index: number): VideoTask {
  const link = item.link.trim();
  const done = isSafeHttpUrl(link);
  const [, month, day] = item.air_date.split('-');
  return {
    dbId: item.linkedTaskId ?? item.id,
    contentPlanId: item.id,
    id: index + 1,
    name: item.video_name,
    resize: '',
    editorId: item.editor_id,
    orderTeam: item.order_team,
    category: item.category === 'Motion' ? 'Motion' : 'Video dài',
    receiveDate: '',
    returnDate: '',
    airDate: `${Number(day)}/${Number(month)}`,
    status: done ? 'Đã xong' : item.editor_id ? 'Đang làm' : 'Chờ',
    priority: '',
    link: done ? link : '',
    note: item.note,
    completedAt: null,
  };
}

// Lấy luôn hai tháng trong một lượt (tháng đang xem + tháng liền trước) để dashboard so sánh
// tăng/giảm mà không phải gọi thêm request.
export async function fetchDashboardData(monthValue = getCurrentMonthValue()): Promise<DashboardData> {
  const previousMonthValue = shiftMonthValue(monthValue, -1);
  const current = getMonthRange(monthValue);
  const previous = getMonthRange(previousMonthValue);
  const [tasks, shoots, editorOptions] = await Promise.all([
    fetchContentPlan(undefined, { startDate: previous.startDate, endDate: current.endDate })
      .then((items) => items.map(toDashboardTask)),
    fetchShoots(previous.startDate, current.endDate),
    fetchContentPlanEditorOptions(),
  ]);

  return {
    tasks: tasks.filter((task) => isDisplayDateInMonth(task.airDate, monthValue)),
    shoots: shoots.filter((shoot) => shoot.date.startsWith(monthValue)),
    editors: editorOptions.map(toDashboardEditor),
    previousTasks: tasks.filter((task) => isDisplayDateInMonth(task.airDate, previousMonthValue)),
    previousShoots: shoots.filter((shoot) => shoot.date.startsWith(previousMonthValue)),
    previousMonthValue,
  };
}
