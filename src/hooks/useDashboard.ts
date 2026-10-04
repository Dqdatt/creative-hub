import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { fetchDashboardData } from '../services/dashboardService';
import { ORDER_TEAMS, TASK_STATUSES } from '../data/tasks';

import type { ShootSchedule } from '../types/shoot';
import type { Editor, TaskStatus, VideoTask } from '../types/task';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import { countShootsOfEditor, isCountedShoot } from '../utils/shoot';
import { displayDateToLocalDate, getCurrentMonthValue, shiftMonthValue, startOfToday } from '../utils/month';
import { isLateTask } from '../utils/taskDeadline';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

// Trễ hạn = chưa xong mà hạn trả (hoặc ngày air nếu trống hạn trả) đã qua.
function isOverdue(task: VideoTask, monthValue: string, today: Date) {
  if (task.status === 'Đã xong') return false;
  const deadline = displayDateToLocalDate(task.returnDate || task.airDate, monthValue);
  return Boolean(deadline && deadline < today);
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

// Bảng chéo: editor là nhóm cột cấp trên, team order là cột con, loại video là hàng.
export interface MatrixCell {
  longVideos: number;
  motion: number;
  total: number;
  done: number;
  /** Trễ deadline: xong sau Ngày Air, hoặc chưa xong khi Ngày Air đã qua. */
  late: number;
  completionRate: number;
  share: number;
}

export interface MatrixEditorGroup {
  key: string;
  label: string;
  editor: Editor | null;
  /** Cùng thứ tự với EditorMatrix.teams. */
  cells: MatrixCell[];
  /** Cộng mọi team order của editor này. */
  totals: MatrixCell;
  shoots: number;
  load: number;
}

export interface EditorMatrix {
  teams: string[];
  editors: MatrixEditorGroup[];
  /** Cộng mọi editor theo từng team order, cùng thứ tự với teams. */
  teamTotals: MatrixCell[];
  /** Cột cuối: cộng toàn bộ editor. */
  grand: MatrixCell;
  shoots: number;
  load: number;
}

// KPI riêng của team order BRAND: tự đếm theo tháng đang xem, không có chỉ tiêu
// đặt trước. Liệt kê đủ mọi editor để người không có việc BRAND vẫn hiện số 0.
export interface BrandKpiRow {
  key: string;
  label: string;
  editor: Editor | null;
  longVideos: number;
  motion: number;
  total: number;
  /** Phần trăm trên tổng BRAND của tháng. */
  share: number;
}

export interface BrandKpi {
  team: string;
  rows: BrandKpiRow[];
  longVideos: number;
  motion: number;
  total: number;
}

export interface DashboardMetrics extends PeriodSummary {
  previous: PeriodSummary;
  previousMonthValue: string;
  statusCounts: StatusCount[];
  pendingVideos: number;
  doneWithoutResultLinks: number;
  editorStats: EditorStat[];
  teamStats: TeamStat[];
  editorMatrix: EditorMatrix;
  brandKpi: BrandKpi;
}

const BRAND_TEAM = 'BRAND';
const NO_TEAM_LABEL = 'Chưa gắn team order';
const NO_EDITOR_LABEL = 'Chưa phân công';
const NO_EDITOR_KEY = '__unassigned__';

function rate(done: number, total: number) {
  return total ? Math.round((done / total) * 100) : 0;
}

function taskTeam(task: VideoTask) {
  return task.orderTeam?.trim() || NO_TEAM_LABEL;
}

function toMatrixCell(
  cellTasks: VideoTask[],
  monthTotal: number,
  monthValue: string,
  today: Date,
): MatrixCell {
  const done = cellTasks.filter((task) => task.status === 'Đã xong').length;

  return {
    longVideos: cellTasks.filter((task) => task.category === 'Video dài').length,
    motion: cellTasks.filter((task) => task.category === 'Motion').length,
    total: cellTasks.length,
    done,
    late: cellTasks.filter((task) => isLateTask(task, monthValue, today)).length,
    completionRate: rate(done, cellTasks.length),
    share: rate(cellTasks.length, monthTotal),
  };
}

// Cột con dùng chung cho mọi editor để các nhóm cột thẳng hàng nhau; chỉ giữ
// team order thực sự có việc trong tháng, nếu không bảng phình ra rất rộng.
function buildMatrixTeams(tasks: VideoTask[]): string[] {
  const totals = new Map<string, number>();
  tasks.forEach((task) => {
    const team = taskTeam(task);
    totals.set(team, (totals.get(team) ?? 0) + 1);
  });

  return Array.from(totals.entries())
    .sort((a, b) => {
      if (a[0] === NO_TEAM_LABEL) return 1;
      if (b[0] === NO_TEAM_LABEL) return -1;
      if (b[1] !== a[1]) return b[1] - a[1];
      return a[0].localeCompare(b[0], 'vi');
    })
    .map(([team]) => team);
}

function buildEditorMatrix(
  tasks: VideoTask[],
  shoots: ShootSchedule[],
  editors: Editor[],
  monthValue: string,
  today: Date,
): EditorMatrix {
  const monthTotal = tasks.length;
  const teams = buildMatrixTeams(tasks);

  const toGroup = (
    key: string,
    label: string,
    editor: Editor | null,
    groupTasks: VideoTask[],
    groupShoots: number,
  ): MatrixEditorGroup => ({
    key,
    label,
    editor,
    cells: teams.map((team) =>
      toMatrixCell(groupTasks.filter((task) => taskTeam(task) === team), monthTotal, monthValue, today)
    ),
    totals: toMatrixCell(groupTasks, monthTotal, monthValue, today),
    shoots: groupShoots,
    load: groupTasks.length + groupShoots,
  });

  const groups = editors.map((editor) =>
    toGroup(
      editor.id,
      editor.short || editor.name,
      editor,
      tasks.filter((task) => task.editorId === editor.id),
      countShootsOfEditor(shoots, editor),
    )
  );

  // Task mất editor vẫn phải có nhóm cột, nếu không cộng ngang sẽ hụt so với tổng tháng.
  const unassigned = tasks.filter(
    (task) => !task.editorId || !editors.some((editor) => editor.id === task.editorId)
  );
  if (unassigned.length) {
    groups.push(toGroup(NO_EDITOR_KEY, NO_EDITOR_LABEL, null, unassigned, 0));
  }

  const countedShoots = shoots.filter(isCountedShoot).length;

  return {
    teams,
    teamTotals: teams.map((team) =>
      toMatrixCell(tasks.filter((task) => taskTeam(task) === team), monthTotal, monthValue, today)
    ),
    editors: groups
      .filter((group) => group.totals.total > 0 || group.shoots > 0)
      .sort((a, b) => {
        if (a.key === NO_EDITOR_KEY) return 1;
        if (b.key === NO_EDITOR_KEY) return -1;
        if (b.load !== a.load) return b.load - a.load;
        return a.label.localeCompare(b.label, 'vi');
      }),
    grand: toMatrixCell(tasks, monthTotal, monthValue, today),
    shoots: countedShoots,
    load: monthTotal + countedShoots,
  };
}

function buildBrandKpi(tasks: VideoTask[], editors: Editor[]): BrandKpi {
  const brandTasks = tasks.filter((task) => taskTeam(task) === BRAND_TEAM);
  const total = brandTasks.length;

  const toRow = (key: string, label: string, editor: Editor | null, rowTasks: VideoTask[]): BrandKpiRow => ({
    key,
    label,
    editor,
    longVideos: rowTasks.filter((task) => task.category === 'Video dài').length,
    motion: rowTasks.filter((task) => task.category === 'Motion').length,
    total: rowTasks.length,
    share: rate(rowTasks.length, total),
  });

  const rows = editors.map((editor) =>
    toRow(editor.id, editor.short || editor.name, editor, brandTasks.filter((task) => task.editorId === editor.id))
  );

  // Việc BRAND mất editor vẫn phải hiện, nếu không cộng cột sẽ hụt so với tổng BRAND.
  const unassigned = brandTasks.filter(
    (task) => !task.editorId || !editors.some((editor) => editor.id === task.editorId)
  );
  if (unassigned.length) {
    rows.push(toRow(NO_EDITOR_KEY, NO_EDITOR_LABEL, null, unassigned));
  }

  return {
    team: BRAND_TEAM,
    rows,
    longVideos: brandTasks.filter((task) => task.category === 'Video dài').length,
    motion: brandTasks.filter((task) => task.category === 'Motion').length,
    total,
  };
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
        const editorShoots = countShootsOfEditor(shoots, editor);

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
      editorMatrix: buildEditorMatrix(tasks, shoots, editors, monthValue, today),
      brandKpi: buildBrandKpi(tasks, editors),
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
