import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/authContext';
import { fetchContentPlanEditorOptions } from '../services/contentPlanService';
import { acceptLinkedVideoTask, completeLinkedVideoTask, createVideoTask, fetchVideoTasks, updateLinkedVideoTaskExecution, updateVideoTask } from '../services/tasksService';
import type { ContentPlanEditorOption } from '../types/contentPlan';
import type { Editor, LinkedVideoTaskExecutionData, TaskFormData, VideoTask } from '../types/task';
import { useRealtimeSubscription } from './useRealtimeSubscription';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

function toTaskEditor(editor: ContentPlanEditorOption): Editor {
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

export function useTasks(monthValue: string) {
  const { user } = useAuth();
  const requestIdRef = useRef(0);
  const [tasks, setTasks] = useState<VideoTask[]>([]);
  const [editors, setEditors] = useState<Editor[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  const loadTasks = useCallback(async (options?: LoadOptions) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!options?.silent) {
      setIsLoading(true);
    }
    setLoadError(null);

    try {
      const [nextTasks, nextEditors] = await Promise.all([
        fetchVideoTasks(monthValue),
        fetchContentPlanEditorOptions(),
      ]);
      if (requestId !== requestIdRef.current) return;
      setTasks(nextTasks);
      setEditors(nextEditors.map(toTaskEditor));
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setLoadError(getErrorMessage(error, 'Không thể tải danh sách video. Vui lòng thử lại.'));
      setTasks([]);
      setEditors([]);
    } finally {
      if (requestId === requestIdRef.current) {
        setIsLoading(false);
      }
    }
  }, [monthValue]);

  useEffect(() => {
    void loadTasks();
  }, [loadTasks]);

  useRealtimeSubscription({
    tables: ['video_tasks'],
    onChange: () => loadTasks({ silent: true }),
  });

  const createTask = useCallback(async (data: TaskFormData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      await createVideoTask(data, user?.id);
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu task. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks, user?.id]);

  const updateTask = useCallback(async (task: VideoTask, data: TaskFormData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      if (!task.dbId) {
        throw new Error('Không tìm thấy mã task cần cập nhật.');
      }
      await updateVideoTask(task.dbId, data, user?.id, task);
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu task. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks, user?.id]);

  const acceptTask = useCallback(async (task: VideoTask, receiveDate: string, returnDate: string) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      if (!task.dbId) {
        throw new Error('Không tìm thấy mã task cần nhận.');
      }
      await acceptLinkedVideoTask({
        taskId: task.dbId,
        receiveDate,
        returnDate,
      });
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể nhận Task. Vui lòng thử lại.'));
      await loadTasks({ silent: true });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks]);

  const completeTask = useCallback(async (task: VideoTask, resultLink: string) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      if (!task.dbId) {
        throw new Error('Không tìm thấy mã task cần hoàn thành.');
      }
      await completeLinkedVideoTask({
        taskId: task.dbId,
        resultLink,
      });
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể hoàn thành Task. Vui lòng thử lại.'));
      await loadTasks({ silent: true });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks]);

  const updateLinkedExecution = useCallback(async (task: VideoTask, data: LinkedVideoTaskExecutionData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      if (!task.dbId) {
        throw new Error('Không tìm thấy mã task cần cập nhật.');
      }
      await updateLinkedVideoTaskExecution({
        taskId: task.dbId,
        ...data,
      });
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu thông tin thực hiện Task. Vui lòng thử lại.'));
      await loadTasks({ silent: true });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks]);

  const saveExecutionAndCompleteTask = useCallback(async (task: VideoTask, data: LinkedVideoTaskExecutionData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      if (!task.dbId) {
        throw new Error('Không tìm thấy mã task cần hoàn thành.');
      }
      await updateLinkedVideoTaskExecution({
        taskId: task.dbId,
        ...data,
      });
      await completeLinkedVideoTask({
        taskId: task.dbId,
        resultLink: data.link,
      });
      await loadTasks();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể hoàn thành Task. Vui lòng thử lại.'));
      await loadTasks({ silent: true });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadTasks]);

  const clearSaveError = useCallback(() => {
    setSaveError(null);
  }, []);

  return {
    tasks,
    editors,
    isLoading,
    isSaving,
    loadError,
    saveError,
    refetch: loadTasks,
    createTask,
    updateTask,
    acceptTask,
    completeTask,
    updateLinkedExecution,
    saveExecutionAndCompleteTask,
    clearSaveError,
  };
}
