import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { fetchDashboardData } from '../services/dashboardService';
import type { ShootSchedule } from '../types/shoot';
import type { Editor, VideoTask } from '../types/task';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import { getCurrentMonthValue, isDisplayDateInMonth } from '../utils/month';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

function isTaskInMonth(task: VideoTask, monthValue: string) {
  return [
    task.airDate,
    task.returnDate,
    task.receiveDate,
  ].some((dateValue) => isDisplayDateInMonth(dateValue, monthValue));
}

export function useDashboard(monthValue = getCurrentMonthValue()) {
  const requestIdRef = useRef(0);
  const [tasks, setTasks] = useState<VideoTask[]>([]);
  const [shoots, setShoots] = useState<ShootSchedule[]>([]);
  const [editors, setEditors] = useState<Editor[]>([]);
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
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setLoadError(getErrorMessage(error, 'Không thể tải dữ liệu dashboard. Vui lòng thử lại.'));
      setTasks([]);
      setShoots([]);
      setEditors([]);
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

  const monthTasks = useMemo(
    () => tasks.filter((task) => isTaskInMonth(task, monthValue)),
    [monthValue, tasks]
  );

  const metrics = useMemo(() => {
    const totalVideos = monthTasks.length;
    const doneVideos = monthTasks.filter((task) => task.status === 'Đã xong').length;
    const missingResultLinks = monthTasks.filter((task) => !task.link || task.link === '#').length;
    const completionRate = totalVideos ? Math.round((doneVideos / totalVideos) * 100) : 0;
    const upcomingAirTasks = monthTasks
      .filter((task) => task.airDate && task.status !== 'Đã xong')
      .sort((a, b) => a.airDate.localeCompare(b.airDate));

    return {
      totalVideos,
      doneVideos,
      totalShoots: shoots.length,
      completionRate,
      missingResultLinks,
      upcomingAirTasks,
    };
  }, [monthTasks, shoots.length]);

  return {
    tasks: monthTasks,
    shoots,
    editors,
    metrics,
    isLoading,
    loadError,
    isEmpty: !isLoading && !loadError && monthTasks.length === 0 && shoots.length === 0,
    refetch: loadDashboard,
  };
}
