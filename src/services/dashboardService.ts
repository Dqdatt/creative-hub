import { fetchShoots } from './shootsService';
import { fetchVideoTasks } from './tasksService';
import { fetchContentPlanEditorOptions } from './contentPlanService';
import type { ShootSchedule } from '../types/shoot';
import type { Editor, VideoTask } from '../types/task';
import { getMonthRange, getCurrentMonthValue } from '../utils/month';

export interface DashboardData {
  tasks: VideoTask[];
  shoots: ShootSchedule[];
  editors: Editor[];
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

export async function fetchDashboardData(monthValue = getCurrentMonthValue()): Promise<DashboardData> {
  const { startDate, endDate } = getMonthRange(monthValue);
  const [tasks, shoots, editorOptions] = await Promise.all([
    fetchVideoTasks(monthValue),
    fetchShoots(startDate, endDate),
    fetchContentPlanEditorOptions(),
  ]);

  return { tasks, shoots, editors: editorOptions.map(toDashboardEditor) };
}
