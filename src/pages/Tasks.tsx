import { useCallback, useEffect, useState, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import type { VideoTask, TaskFormData, LinkedVideoTaskExecutionData } from '../types/task';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { TaskFilters } from '../components/tasks/TaskFilters';
import { TaskTable } from '../components/tasks/TaskTable';
import { useAuth } from '../context/authContext';
import { TaskModal } from '../components/tasks/TaskModal';
import { useTasks } from '../hooks/useTasks';
import { useRouteHighlight } from '../hooks/useRouteHighlight';
import { fetchVideoTaskById } from '../services/tasksService';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';
import { isUuid } from '../utils/id';

export default function Tasks() {
  const { can, profile } = useAuth();
  const { showToast } = useToast();
  const { selectedMonth, setSelectedMonth } = useMonth();
  const [searchParams, setSearchParams] = useSearchParams();
  const {
    tasks,
    editors,
    isLoading,
    isSaving,
    loadError,
    saveError,
    refetch,
    createTask,
    updateTask,
    acceptTask,
    updateLinkedExecution,
    saveExecutionAndCompleteTask,
    clearSaveError,
  } = useTasks(selectedMonth);
  const [search, setSearch] = useState('');
  const [editorFilter, setEditorFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState<VideoTask | null>(null);
  const canCreateTask = can('video_tasks:create');
  const canUpdateTask = can('video_tasks:update');
  const highlightParam = searchParams.get('highlight');
  const legacyTaskParam = searchParams.get('task');
  const targetTaskId = highlightParam ?? legacyTaskParam;
  const selectedTaskEditorProfileId = selectedTask
    ? editors.find((editor) => editor.id === selectedTask.editorId)?.profileId
    : null;
  const canAcceptSelectedTask = Boolean(
    selectedTask?.dbId &&
    selectedTask.contentPlanId &&
    selectedTask.status === 'Chờ' &&
    canUpdateTask &&
    profile?.id &&
    selectedTaskEditorProfileId === profile.id
  );
  const canCompleteSelectedTask = Boolean(
    selectedTask?.dbId &&
    selectedTask.contentPlanId &&
    selectedTask.status === 'Đang làm' &&
    canUpdateTask &&
    profile?.id &&
    selectedTaskEditorProfileId === profile.id
  );

  const filteredTasks = useMemo(() =>
    tasks
      .filter((t) => {
        if (editorFilter !== 'all' && t.editorId !== editorFilter) return false;
        if (statusFilter !== 'all' && t.status !== statusFilter) return false;
        if (search && !t.name.toLowerCase().includes(search.toLowerCase())) return false;
        return true;
      })
      .sort((a, b) => a.id - b.id),
    [tasks, search, editorFilter, statusFilter]
  );

  const openAddModal = () => {
    if (!canCreateTask) return;
    clearSaveError();
    setSelectedTask(null);
    setIsModalOpen(true);
  };

  const openEditModal = (task: VideoTask) => {
    if (!canUpdateTask) return;
    clearSaveError();
    setSelectedTask(task);
    setIsModalOpen(true);
  };

  const clearHighlightParams = useCallback(() => {
    setSearchParams((current) => {
      const next = new URLSearchParams(current);
      next.delete('highlight');
      next.delete('task');
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  const closeModal = () => {
    if (isSaving) return;
    setIsModalOpen(false);
    setSelectedTask(null);
    clearSaveError();
  };

  useEffect(() => {
    if (!targetTaskId) return;

    if (!isUuid(targetTaskId)) {
      showToast({ type: 'warning', message: 'Đường dẫn Video Task không hợp lệ.' });
      clearHighlightParams();
      return;
    }

    const visibleTask = tasks.find((task) => task.dbId === targetTaskId);
    if (visibleTask) {
      if (search || editorFilter !== 'all' || statusFilter !== 'all') {
        setSearch('');
        setEditorFilter('all');
        setStatusFilter('all');
      }
      return;
    }

    if (isLoading) return;

    let cancelled = false;

    void fetchVideoTaskById(targetTaskId)
      .then((target) => {
        if (cancelled) return;
        if (!target) {
          showToast({ type: 'warning', message: 'Không tìm thấy Task liên quan.' });
          clearHighlightParams();
          return;
        }

        if (target.monthValue && target.monthValue !== selectedMonth) {
          setSelectedMonth(target.monthValue);
        }
      })
      .catch(() => {
        if (cancelled) return;
        showToast({ type: 'warning', message: 'Nội dung liên quan không còn tồn tại hoặc bạn không có quyền xem.' });
        clearHighlightParams();
      });

    return () => {
      cancelled = true;
    };
  }, [clearHighlightParams, editorFilter, isLoading, search, selectedMonth, setSelectedMonth, showToast, statusFilter, targetTaskId, tasks]);

  const handleHighlightMissing = useCallback(() => {
    showToast({ type: 'warning', message: 'Không tìm thấy Task liên quan.' });
  }, [showToast]);

  const highlightedTaskId = useRouteHighlight({
    targetId: targetTaskId && isUuid(targetTaskId) ? targetTaskId : null,
    selector: targetTaskId && isUuid(targetTaskId) ? `[data-video-task-id="${targetTaskId}"]` : null,
    ready: !isLoading && filteredTasks.some((task) => task.dbId === targetTaskId),
    clearQuery: clearHighlightParams,
    onMissing: handleHighlightMissing,
  });

  const handleSave = async (data: TaskFormData) => {
    if (selectedTask && !canUpdateTask) return;
    if (!selectedTask && !canCreateTask) return;

    const saved = selectedTask
      ? await updateTask(selectedTask, data)
      : await createTask(data);

    if (saved) {
      setIsModalOpen(false);
      setSelectedTask(null);
      clearSaveError();
      showToast({
        type: 'success',
        message: selectedTask ? 'Đã lưu thay đổi video task.' : 'Đã thêm video task.',
      });
    }
  };

  const handleAccept = async (data: { receiveDate: string; returnDate: string }) => {
    if (!selectedTask || !canAcceptSelectedTask) return;

    const accepted = await acceptTask(selectedTask, data.receiveDate, data.returnDate);

    if (accepted) {
      setIsModalOpen(false);
      setSelectedTask(null);
      clearSaveError();
      showToast({
        type: 'success',
        message: 'Đã nhận Task.',
      });
    }
  };

  const handleSaveExecution = async (data: LinkedVideoTaskExecutionData) => {
    if (!selectedTask || !canCompleteSelectedTask) return;

    const saved = await updateLinkedExecution(selectedTask, data);

    if (saved) {
      setIsModalOpen(false);
      setSelectedTask(null);
      clearSaveError();
      showToast({
        type: 'success',
        message: 'Đã lưu thông tin thực hiện Task.',
      });
    }
  };

  const handleComplete = async (data: LinkedVideoTaskExecutionData) => {
    if (!selectedTask || !canCompleteSelectedTask) return;

    const completed = await saveExecutionAndCompleteTask(selectedTask, data);

    if (completed) {
      setIsModalOpen(false);
      setSelectedTask(null);
      clearSaveError();
      showToast({
        type: 'success',
        message: 'Đã hoàn thành Task.',
      });
    }
  };

  const renderTableContent = () => {
    if (isLoading) {
      return (
        <LoadingState
          variant="table"
          message="Đang tải dữ liệu video..."
          colSpan={12}
          minWidthClass="min-w-[1200px]"
          rows={7}
        />
      );
    }

    return <TaskTable tasks={filteredTasks} editors={editors} onRowClick={openEditModal} canEditTask={canUpdateTask} highlightedId={highlightedTaskId} />;
  };

  return (
    <div className="space-y-4" data-view="tasks">
      <TaskFilters
        editors={editors}
        search={search}
        editorFilter={editorFilter}
        statusFilter={statusFilter}
        totalCount={tasks.length}
        filteredCount={filteredTasks.length}
        onSearchChange={setSearch}
        onEditorChange={setEditorFilter}
        onStatusChange={setStatusFilter}
        onAddTask={openAddModal}
        canAddTask={canCreateTask}
      />

      {loadError ? (
        <ErrorState title="Không thể tải video tháng" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {!isLoading && !loadError && tasks.length === 0 ? (
        <EmptyState
          title="Chưa có video task"
          message="Tạo task đầu tiên để bắt đầu theo dõi tiến độ."
          actionLabel={canCreateTask ? 'Thêm video task' : undefined}
          onAction={canCreateTask ? openAddModal : undefined}
        />
      ) : null}

      <div className="card p-3 overflow-x-auto">
        {renderTableContent()}
      </div>

      <TaskModal
        isOpen={isModalOpen}
        task={selectedTask}
        editors={editors}
        selectedMonth={selectedMonth}
        onClose={closeModal}
        onSave={handleSave}
        onSaveExecution={handleSaveExecution}
        onAccept={handleAccept}
        onComplete={handleComplete}
        canAcceptLinkedTask={canAcceptSelectedTask}
        canCompleteLinkedTask={canCompleteSelectedTask}
        isSaving={isSaving}
        errorMessage={saveError}
      />
    </div>
  );
}
