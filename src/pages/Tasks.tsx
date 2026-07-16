import { useState, useMemo } from 'react';
import type { VideoTask, TaskFormData, LinkedVideoTaskExecutionData } from '../types/task';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { TaskFilters } from '../components/tasks/TaskFilters';
import { TaskTable } from '../components/tasks/TaskTable';
import { useAuth } from '../context/authContext';
import { TaskModal } from '../components/tasks/TaskModal';
import { useTasks } from '../hooks/useTasks';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';

export default function Tasks() {
  const { can, profile } = useAuth();
  const { showToast } = useToast();
  const { selectedMonth } = useMonth();
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

  const closeModal = () => {
    if (isSaving) return;
    setIsModalOpen(false);
    setSelectedTask(null);
    clearSaveError();
  };

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

    return <TaskTable tasks={filteredTasks} editors={editors} onRowClick={openEditModal} canEditTask={canUpdateTask} />;
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
