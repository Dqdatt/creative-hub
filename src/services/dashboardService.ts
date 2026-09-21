import { fetchShoots } from './shootsService';
import { fetchVideoTasks } from './tasksService';
import { fetchContentPlanEditorOptions } from './contentPlanService';
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

// Lấy luôn hai tháng trong một lượt (tháng đang xem + tháng liền trước) để dashboard so sánh
// tăng/giảm mà không phải gọi thêm request.
export async function fetchDashboardData(monthValue = getCurrentMonthValue()): Promise<DashboardData> {
  const previousMonthValue = shiftMonthValue(monthValue, -1);
  const current = getMonthRange(monthValue);
  const previous = getMonthRange(previousMonthValue);
  const [tasks, shoots, editorOptions] = await Promise.all([
    fetchVideoTasks(undefined, { startDate: previous.startDate, endDate: current.endDate }),
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
