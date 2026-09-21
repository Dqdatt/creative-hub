import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { fetchDashboardData } from '../services/dashboardService';
import { ORDER_TEAMS, TASK_STATUSES } from '../data/tasks';

import type { ShootSchedule } from '../types/shoot';
import type { Editor, TaskStatus, VideoTask } from '../types/task';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import { getCurrentMonthValue, shiftMonthValue } from '../utils/month';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

function displayDateToLocalDate(value: string | undefined, monthValue: string) {
  if (!value) return null;
  const cleanValue = value.trim();
  if (!cleanValue || cleanValue === '#') return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(cleanValue)) return new Date(`${cleanValue}T00:00:00`);

  const match = cleanValue.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
  if (!match) return null;

  const fallbackYear = Number(monthValue.slice(0, 4)) || new Date().getFullYear();
  const parsedYear = match[3] ? Number(match[3]) : fallbackYear;
  const year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
  return new Date(year, Number(match[2]) - 1, Number(match[1]));
}

function startOfToday() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return today;
}

// Trễ hạn = chưa xong mà hạn trả (hoặc ngày air nếu trống hạn trả) đã qua.
function isOverdue(task: VideoTask, monthValue: string, today: Date) {
  if (task.status === 'Đã xong') return false;
  const deadline = displayDateToLocalDate(task.returnDate || task.airDate, monthValue);
  return Boolean(deadline && deadline < today);
}

function isCountedShoot(shoot: ShootSchedule) {
  return shoot.type !== 'livestream';
}

function shootsOfEditor(shoots: ShootSchedule[], editor: Editor) {
  const profileKey = editor.profileId || editor.id;
  return shoots.filter((shoot) =>
    isCountedShoot(shoot) &&
    (shoot.editorProfileIds.includes(profileKey) || shoot.editorIds.includes(editor.id))
  );
}

export interface StatusCount {
  status: TaskStatus;
  value: number;
}

export interface PeriodSummary {
  totalVideos: number;
  doneVideos: number;
  overdueVideos: number;
  totalShoots: number;
  completionRate: number;
}

export interface EditorStat {
  editor: Editor;
  total: number;
  done: number;
  doing: number;
  waiting: number;
  hold: number;
  overdue: number;
  longVideos: number;
  motionVideos: number;
  shoots: number;
  load: number;
  completionRate: number;
}

export interface TeamStat {
  team: string;
  total: number;
  done: number;
  share: number;
  perEditor: number[];
}

export interface DashboardMetrics extends PeriodSummary {
  previous: PeriodSummary;
  previousMonthValue: string;
  statusCounts: StatusCount[];
  pendingVideos: number;
  doneWithoutResultLinks: number;
  editorStats: EditorStat[];
  teamStats: TeamStat[];
}

function summarize(tasks: VideoTask[], shoots: ShootSchedule[], monthValue: string, today: Date): PeriodSummary {
  const totalVideos = tasks.length;
  const doneVideos = tasks.filter((task) => task.status === 'Đã xong').length;

  return {
    totalVideos,
    doneVideos,
    overdueVideos: tasks.filter((task) => isOverdue(task, monthValue, today)).length,
    totalShoots: shoots.filter(isCountedShoot).length,
    completionRate: totalVideos ? Math.round((doneVideos / totalVideos) * 100) : 0,
  };
}

export function useDashboard(monthValue = getCurrentMonthValue()) {
  const requestIdRef = useRef(0);
  const [tasks, setTasks] = useState<VideoTask[]>([]);
  const [shoots, setShoots] = useState<ShootSchedule[]>([]);
  const [editors, setEditors] = useState<Editor[]>([]);
  const [previousTasks, setPreviousTasks] = useState<VideoTask[]>([]);
  const [previousShoots, setPreviousShoots] = useState<ShootSchedule[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadDashboard = useCallback(async (options?: LoadOptions) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!options?.silent) {
      setIsLoading(true);
    }
    setLoadError(null);

    try {
      const data = await fetchDashboardData(monthValue);
      if (requestId !== requestIdRef.current) return;
      setTasks(data.tasks);
      setShoots(data.shoots);
      setEditors(data.editors);
      setPreviousTasks(data.previousTasks);
      setPreviousShoots(data.previousShoots);
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setLoadError(getErrorMessage(error, 'Không thể tải dữ liệu dashboard. Vui lòng thử lại.'));
      setTasks([]);
      setShoots([]);
      setEditors([]);
      setPreviousTasks([]);
      setPreviousShoots([]);
    } finally {
      if (requestId === requestIdRef.current) {
        setIsLoading(false);
      }
    }
  }, [monthValue]);

  useEffect(() => {
    void loadDashboard();
  }, [loadDashboard]);

  useRealtimeSubscription({
    tables: ['video_tasks', 'shoots', 'shoot_editors', 'content_plan'],
    onChange: () => loadDashboard({ silent: true }),
  });

  const metrics = useMemo<DashboardMetrics>(() => {
    const today = startOfToday();
    const previousMonthValue = shiftMonthValue(monthValue, -1);
    const current = summarize(tasks, shoots, monthValue, today);
    const previous = summarize(previousTasks, previousShoots, previousMonthValue, today);

    const statusCounts: StatusCount[] = TASK_STATUSES.map((status) => ({
      status,
      value: tasks.filter((task) => task.status === status).length,
    }));
    const statusValue = (status: TaskStatus) =>
      statusCounts.find((entry) => entry.status === status)?.value ?? 0;

    const editorStats: EditorStat[] = editors
      .map((editor) => {
        const editorTasks = tasks.filter((task) => task.editorId === editor.id);
        const done = editorTasks.filter((task) => task.status === 'Đã xong').length;
        const editorShoots = shootsOfEditor(shoots, editor).length;

        return {
          editor,
          total: editorTasks.length,
          done,
          doing: editorTasks.filter((task) => task.status === 'Đang làm').length,
          waiting: editorTasks.filter((task) => task.status === 'Chờ').length,
          hold: editorTasks.filter((task) => task.status === 'Hoãn').length,
          overdue: editorTasks.filter((task) => isOverdue(task, monthValue, today)).length,
          longVideos: editorTasks.filter((task) => task.category === 'Video dài').length,
          motionVideos: editorTasks.filter((task) => task.category === 'Motion').length,
          shoots: editorShoots,
          load: editorTasks.length + editorShoots,
          completionRate: editorTasks.length ? Math.round((done / editorTasks.length) * 100) : 0,
        };
      })
      .sort((a, b) => b.load - a.load);

    const teamStats: TeamStat[] = ORDER_TEAMS
      .map((team) => {
        const teamTasks = tasks.filter((task) => task.orderTeam === team);
        return {
          team,
          total: teamTasks.length,
          done: teamTasks.filter((task) => task.status === 'Đã xong').length,
          share: current.totalVideos ? Math.round((teamTasks.length / current.totalVideos) * 100) : 0,
          perEditor: editors.map((editor) => teamTasks.filter((task) => task.editorId === editor.id).length),
        };
      })
      .filter((entry) => entry.total > 0)
      .sort((a, b) => b.total - a.total);

    return {
      ...current,
      previous,
      previousMonthValue,
      statusCounts,
      pendingVideos: statusValue('Chờ'),
      doneWithoutResultLinks: tasks.filter((task) =>
        task.status === 'Đã xong' && (!task.link || task.link === '#')
      ).length,
      editorStats,
      teamStats,
    };
  }, [editors, monthValue, previousShoots, previousTasks, shoots, tasks]);

  return {
    tasks,
    shoots,
    editors,
    metrics,
    isLoading,
    loadError,
    isEmpty: !isLoading && !loadError && tasks.length === 0 && shoots.length === 0,
    refetch: loadDashboard,
  };
}
