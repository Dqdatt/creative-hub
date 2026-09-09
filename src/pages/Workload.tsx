import { useCallback, useMemo, useState } from 'react';
import { Plus, Search } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { MultiSelect } from '../components/common/MultiSelect';
import { ShootModal } from '../components/calendar/ShootModal';
import { ContentPlanModal } from '../components/content-plan/ContentPlanModal';
import { TaskModal } from '../components/tasks/TaskModal';
import { WorkloadCalendar } from '../components/workload/WorkloadCalendar';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { canEditContentPlanField } from '../config/permissions';
import { ORDER_TEAMS, TASK_CATEGORIES, TASK_STATUSES } from '../data/tasks';
import { useAuth } from '../context/authContext';
import { useMonth } from '../context/monthContext';
import { useContentPlan } from '../hooks/useContentPlan';
import { useShoots } from '../hooks/useShoots';
import { useTasks } from '../hooks/useTasks';
import { editorBadgeMap, toIsoDate, useWorkload } from '../hooks/useWorkload';
import type { WorkloadDay, WorkloadItem } from '../hooks/useWorkload';
import type { ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';
import type { ShootFormData, ShootSchedule } from '../types/shoot';
import type { LinkedVideoTaskExecutionData, TaskFormData, VideoTask } from '../types/task';
import { getDefaultContentDate, hasContentFieldChanges, toContentPlanFormData } from '../utils/contentPlanForm';
import { monthValueToDate } from '../utils/month';

type KindFilter = 'task' | 'lichquay' | 'live';

const KIND_OPTIONS: Array<{ value: KindFilter; label: string }> = [
  { value: 'task', label: 'Task' },
  { value: 'lichquay', label: 'Lịch quay' },
  { value: 'live', label: 'Live' },
];

function getCalendarRange(date: Date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cellCount = Math.ceil((startDow + daysInMonth) / 7) * 7;

  return {
    startDate: toIsoDate(new Date(year, month, 1 - startDow)),
    endDate: toIsoDate(new Date(year, month, cellCount - startDow)),
  };
}

function matchesKind(item: WorkloadItem, kind: KindFilter) {
  // Task chính là lịch dựng, gồm cả việc chưa dựng lẫn đã dựng xong.
  if (kind === 'task') return item.kind === 'task' || item.kind === 'plan';
  if (kind === 'live') return item.shootType === 'livestream';
  return item.shootType === 'lichquay' || item.shootType === 'onset' || item.shootType === 'other';
}

export default function Workload() {
  const { profile, role, permissions, can } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { selectedMonth } = useMonth();
  const currentDate = useMemo(() => monthValueToDate(selectedMonth), [selectedMonth]);
  const visibleRange = useMemo(() => getCalendarRange(currentDate), [currentDate]);
  const todayIso = useMemo(() => toIsoDate(new Date()), []);
  const defaultDate = todayIso.startsWith(selectedMonth) ? todayIso : `${selectedMonth}-01`;

  const tasksData = useTasks(selectedMonth);
  const contentData = useContentPlan(selectedMonth);
  const shootsData = useShoots(visibleRange);

  const [editorFilter, setEditorFilter] = useState<string>('all');
  const [kindFilters, setKindFilters] = useState<KindFilter[]>([]);
  const [unassignedOnly, setUnassignedOnly] = useState(false);
  const [search, setSearch] = useState('');
  const [statusFilters, setStatusFilters] = useState<string[]>([]);
  const [orderFilters, setOrderFilters] = useState<string[]>([]);
  const [categoryFilters, setCategoryFilters] = useState<string[]>([]);

  const [isShootModalOpen, setIsShootModalOpen] = useState(false);
  const [selectedShoot, setSelectedShoot] = useState<ShootSchedule | null>(null);
  const [isTaskModalOpen, setIsTaskModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState<VideoTask | null>(null);
  const [defaultDateForTask, setDefaultDateForTask] = useState('');
  const [contentModalMode, setContentModalMode] = useState<'create' | 'edit' | 'assign'>('create');
  const [selectedContentItem, setSelectedContentItem] = useState<ContentPlanItem | null>(null);
  const [contentDraft, setContentDraft] = useState<ContentPlanFormData | null>(null);
  const [contentFormError, setContentFormError] = useState<string | null>(null);

  const canCreateShoot = can('shoots:create');
  const canUpdateShoot = can('shoots:update');
  const canDeleteShoot = can('shoots:delete');
  const canCreateTask = can('video_tasks:create');
  const canUpdateTask = can('video_tasks:update');
  const canDeleteTask = can('video_tasks:delete');
  const canCreateContent = can('content_plan:create');
  const canUpdateContent = can('content_plan:update');
  const canAssignContent = can('content_plan:assign');
  const canDeleteContent = can('content_plan:delete');
  const canEditAirDate = canEditContentPlanField(role, 'air_date', permissions);
  const canEditVideoName = canEditContentPlanField(role, 'video_name', permissions);
  const canEditNote = canEditContentPlanField(role, 'note', permissions);
  const canEditCategory = canEditContentPlanField(role, 'category', permissions);
  const canEditEditor = canEditContentPlanField(role, 'editor_id', permissions);
  const canEditLink = canEditContentPlanField(role, 'link', permissions);

  const workload = useWorkload({
    monthValue: selectedMonth,
    tasks: tasksData.tasks,
    contentItems: contentData.items,
    shoots: shootsData.shoots,
    editors: tasksData.editors,
  });

  const badges = useMemo(
    () => editorBadgeMap(tasksData.editors.map((editor) => ({
      id: editor.id,
      initial: editor.initial,
      label: editor.short || editor.name,
      color: editor.color,
    }))),
    [tasksData.editors]
  );

  const filteredDays = useMemo(() => {
    const keyword = search.trim().toLowerCase();
    const next = new Map<string, WorkloadDay>();

    workload.days.forEach((day, date) => {
      const items = day.items.filter((item) => {
        if (editorFilter !== 'all' && !item.editorIds.includes(editorFilter)) return false;
        if (unassignedOnly && !item.needsAssign) return false;
        if (kindFilters.length && !kindFilters.some((kind) => matchesKind(item, kind))) return false;
        if (statusFilters.length && (!item.status || !statusFilters.includes(item.status))) return false;
        if (orderFilters.length && (!item.orderTeam || !orderFilters.includes(item.orderTeam))) return false;
        if (categoryFilters.length && (!item.category || !categoryFilters.includes(item.category))) return false;
        if (keyword) {
          const haystack = `${item.title} ${item.subtitle} ${item.detail}`.toLowerCase();
          if (!haystack.includes(keyword)) return false;
        }
        return true;
      });
      if (items.length === 0) return;
      next.set(date, { date, items });
    });

    return next;
  }, [categoryFilters, editorFilter, kindFilters, orderFilters, search, statusFilters, unassignedOnly, workload.days]);

  const visibleCount = useMemo(() => {
    let total = 0;
    filteredDays.forEach((day) => { total += day.items.length; });
    return total;
  }, [filteredDays]);

  const isLoading = tasksData.isLoading || contentData.isLoading || shootsData.isLoading;
  const loadError = tasksData.loadError || contentData.loadError || shootsData.loadError;

  const closeShootModal = () => {
    if (shootsData.isSaving || shootsData.isDeleting) return;
    setIsShootModalOpen(false);
    setSelectedShoot(null);
    shootsData.clearModalError();
  };

  const closeTaskModal = useCallback(() => {
    if (tasksData.isSaving) return;
    setIsTaskModalOpen(false);
    setSelectedTask(null);
    setDefaultDateForTask('');
    tasksData.clearSaveError();
  }, [tasksData]);

  const closeContentModal = () => {
    setSelectedContentItem(null);
    setContentDraft(null);
    setContentFormError(null);
  };

  const openTaskCreate = () => {
    if (!canCreateTask) return;
    tasksData.clearSaveError();
    setSelectedTask(null);
    setDefaultDateForTask(defaultDate);
    setIsTaskModalOpen(true);
  };

  const openContentCreate = () => {
    if (!canCreateContent) return;
    contentData.clearSaveError();
    setSelectedContentItem(null);
    setContentModalMode('create');
    setContentDraft({
      air_date: getDefaultContentDate(selectedMonth, defaultDate),
      video_name: '',
      note: '',
      category: 'Video dài',
      editor_id: '',
      link: '',
    });
    setContentFormError(null);
  };

  const openShootEdit = (shoot: ShootSchedule) => {
    shootsData.clearModalError();
    setSelectedShoot(shoot);
    setIsShootModalOpen(true);
  };

  const openTaskEdit = (task: VideoTask) => {
    if (!canUpdateTask) return;
    tasksData.clearSaveError();
    setSelectedTask(task);
    setDefaultDateForTask('');
    setIsTaskModalOpen(true);
  };

  const openContentEdit = (item: ContentPlanItem) => {
    if (!canUpdateContent && !canAssignContent) return;
    contentData.clearSaveError();
    setSelectedContentItem(item);
    setContentModalMode(canUpdateContent ? 'edit' : 'assign');
    setContentDraft(toContentPlanFormData(item));
    setContentFormError(null);
  };

  const handleOpenItem = (item: WorkloadItem) => {
    if (item.kind === 'shoot') {
      const shoot = shootsData.shoots.find((entry) => entry.id === item.sourceId);
      if (shoot) openShootEdit(shoot);
      return;
    }

    if (item.kind === 'plan') {
      const contentItem = contentData.items.find((entry) => entry.id === item.sourceId);
      if (!contentItem) return;

      // Dòng đã phân công editor thì mở modal Video tháng, dòng chưa phân công mở modal Content Plan.
      if (contentItem.editor_id && contentItem.linkedTaskId) {
        const linkedTask = tasksData.tasks.find((entry) => entry.dbId === contentItem.linkedTaskId);
        if (linkedTask) {
          openTaskEdit(linkedTask);
          return;
        }
      }

      openContentEdit(contentItem);
      return;
    }

    const task = tasksData.tasks.find((entry) => (entry.dbId ?? String(entry.id)) === item.sourceId);
    if (task) openTaskEdit(task);
  };

  const handleShootSave = async (data: ShootFormData) => {
    if (selectedShoot && !canUpdateShoot) return;
    if (!selectedShoot && !canCreateShoot) return;
    const saved = selectedShoot
      ? await shootsData.updateShoot(selectedShoot.id, data)
      : await shootsData.createShoot(data);
    if (saved) {
      closeShootModal();
      showToast({ type: 'success', message: selectedShoot ? 'Đã lưu thay đổi lịch quay.' : 'Đã thêm lịch quay.' });
    }
  };

  const handleShootDelete = async (id: string) => {
    if (!canDeleteShoot) return;
    const confirmed = await requestConfirm({
      title: 'Xóa lịch quay?',
      description: 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa lịch quay',
      variant: 'danger',
    });
    if (!confirmed) return;
    const deleted = await shootsData.deleteShoot(id);
    if (deleted) {
      closeShootModal();
      showToast({ type: 'success', message: 'Đã xóa lịch quay.' });
    }
  };

  const handleTaskSave = async (data: TaskFormData) => {
    if (selectedTask && !canUpdateTask) return;
    if (!selectedTask && !canCreateTask) return;
    const saved = selectedTask
      ? await tasksData.updateTask(selectedTask, data)
      : await tasksData.createTask(data);
    if (saved) {
      closeTaskModal();
      void contentData.refetch();
      showToast({ type: 'success', message: selectedTask ? 'Đã lưu thay đổi video task.' : 'Đã thêm video task.' });
    }
  };

  const handleTaskAccept = async (data: { receiveDate: string; returnDate: string }) => {
    if (!selectedTask || !canAcceptSelectedTask) return;
    const accepted = await tasksData.acceptTask(selectedTask, data.receiveDate, data.returnDate);
    if (accepted) {
      closeTaskModal();
      void contentData.refetch();
      showToast({ type: 'success', message: 'Đã nhận Task.' });
    }
  };

  const handleTaskExecutionSave = async (data: LinkedVideoTaskExecutionData) => {
    if (!selectedTask || !canCompleteSelectedTask) return;
    const saved = await tasksData.updateLinkedExecution(selectedTask, data);
    if (saved) {
      closeTaskModal();
      void contentData.refetch();
      showToast({ type: 'success', message: 'Đã lưu thông tin thực hiện Task.' });
    }
  };

  const handleTaskComplete = async (data: LinkedVideoTaskExecutionData) => {
    if (!selectedTask || !canCompleteSelectedTask) return;
    const completed = await tasksData.saveExecutionAndCompleteTask(selectedTask, data);
    if (completed) {
      closeTaskModal();
      void contentData.refetch();
      showToast({ type: 'success', message: 'Đã hoàn thành Task.' });
    }
  };

  const handleTaskDelete = async (task: VideoTask) => {
    if (!canDeleteTask || tasksData.isSaving || tasksData.isDeleting) return;
    const confirmed = await requestConfirm({
      title: 'Xóa video task?',
      description: task.contentPlanId
        ? 'Task này được tạo từ Content Plan. Thao tác xóa sẽ gỡ task khỏi Video tháng nhưng không xóa dòng Content Plan.'
        : 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa Task',
      variant: 'danger',
    });
    if (!confirmed) return;
    const deleted = await tasksData.deleteTask(task);
    if (deleted) {
      if (selectedTask?.dbId === task.dbId) closeTaskModal();
      void contentData.refetch();
      showToast({ type: 'success', message: 'Đã xóa video task.' });
    }
  };

  const handleContentDraftChange = (data: Partial<ContentPlanFormData>) => {
    setContentDraft((current) => current ? { ...current, ...data } : current);
    setContentFormError(null);
    contentData.clearSaveError();
  };

  const handleContentSave = async () => {
    if (!contentDraft) return;
    if (contentModalMode === 'create' && !canCreateContent) return;
    if (contentModalMode === 'edit' && !canUpdateContent) return;
    if (contentModalMode === 'assign' && !canAssignContent) return;
    if (!contentDraft.air_date) {
      setContentFormError('Vui lòng chọn ngày Air.');
      return;
    }
    if (!contentDraft.video_name.trim()) {
      setContentFormError('Vui lòng nhập tên video.');
      return;
    }
    if (contentModalMode === 'assign' && !contentDraft.editor_id) {
      setContentFormError('Vui lòng chọn editor.');
      return;
    }
    if (contentModalMode !== 'create' && !selectedContentItem) {
      setContentFormError('Không tìm thấy dòng lịch air cần lưu.');
      return;
    }

    const sourceItem = selectedContentItem ? toContentPlanFormData(selectedContentItem) : null;
    const nextData: ContentPlanFormData = {
      air_date: canEditAirDate ? contentDraft.air_date : sourceItem?.air_date ?? contentDraft.air_date,
      video_name: canEditVideoName ? contentDraft.video_name.trim() : sourceItem?.video_name ?? contentDraft.video_name.trim(),
      note: canEditNote ? contentDraft.note.trim() : sourceItem?.note ?? contentDraft.note.trim(),
      category: canEditCategory ? contentDraft.category : sourceItem?.category ?? contentDraft.category,
      editor_id: canEditEditor ? contentDraft.editor_id : sourceItem?.editor_id ?? '',
      link: canEditLink && !selectedContentItem?.hasLinkedTask ? contentDraft.link.trim() : sourceItem?.link ?? contentDraft.link.trim(),
    };

    let saved = false;
    if (contentModalMode === 'create') {
      saved = await contentData.createItem({ ...nextData, editor_id: '' });
    } else if (selectedContentItem) {
      const editorChanged = selectedContentItem.editor_id !== nextData.editor_id;
      const contentChanged = hasContentFieldChanges(selectedContentItem, nextData);
      if (editorChanged && contentChanged) {
        setContentFormError('Vui lòng lưu nội dung trước, rồi phân công editor.');
        return;
      }
      if (editorChanged) {
        saved = await contentData.assignEditor(selectedContentItem, nextData.editor_id);
      } else if (contentChanged) {
        saved = await contentData.updateItem(selectedContentItem, nextData);
      } else {
        closeContentModal();
        return;
      }
    }

    if (saved) {
      closeContentModal();
      // Phân công editor sẽ sinh Video Task, nên phải tải lại task để nó hiện ngay.
      void tasksData.refetch();
      showToast({
        type: 'success',
        message: selectedContentItem && selectedContentItem.editor_id !== nextData.editor_id
          ? 'Đã phân công editor.'
          : 'Đã lưu lịch air.',
      });
    }
  };

  const handleContentDelete = async (item: ContentPlanItem) => {
    if (!canDeleteContent || contentData.isSaving || contentData.isDeleting) return;
    const confirmed = await requestConfirm({
      title: 'Xóa kế hoạch content?',
      description: 'Thao tác này không thể hoàn tác. Nếu dòng đã sinh Video Task, task liên kết cũng sẽ bị xóa.',
      confirmLabel: 'Xóa dòng',
      variant: 'danger',
    });
    if (!confirmed) return;
    const deleted = await contentData.deleteItem(item);
    if (deleted) {
      if (selectedContentItem?.id === item.id) closeContentModal();
      void tasksData.refetch();
      showToast({ type: 'success', message: 'Đã xóa dòng lịch air.' });
    }
  };

  const retry = () => {
    void tasksData.refetch();
    void contentData.refetch();
    void shootsData.refetch();
  };

  const selectedTaskEditorProfileId = selectedTask
    ? tasksData.editors.find((editor) => editor.id === selectedTask.editorId)?.profileId
    : null;
  const canManageSelectedLinkedTask = Boolean(
    selectedTask?.contentPlanId &&
    canUpdateTask &&
    (profile?.role === 'admin' || profile?.role === 'creative_manager')
  );
  const canAcceptSelectedTask = Boolean(
    selectedTask?.dbId &&
    selectedTask.contentPlanId &&
    selectedTask.status === 'Chờ' &&
    canUpdateTask &&
    !canManageSelectedLinkedTask &&
    profile?.id &&
    selectedTaskEditorProfileId === profile.id
  );
  const canCompleteSelectedTask = Boolean(
    selectedTask?.dbId &&
    selectedTask.contentPlanId &&
    selectedTask.status === 'Đang làm' &&
    canUpdateTask &&
    !canManageSelectedLinkedTask &&
    profile?.id &&
    selectedTaskEditorProfileId === profile.id
  );
  const canEditSelectedLinkedTask = Boolean(
    selectedTask?.contentPlanId &&
    canManageSelectedLinkedTask
  );

  if (loadError) {
    return (
      <div className="calendar-page" data-view="workload">
        <ErrorState title="Không thể tải Workload" message={loadError} onRetry={retry} />
      </div>
    );
  }

  return (
    <div className="calendar-page" data-view="workload">
      <div className="card wl-toolbar">
        <div className="wl-row">
          <div className="wl-search">
            <Search />
            <input
              className="field"
              placeholder="Tìm tên video..."
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              aria-label="Tìm tên video"
            />
          </div>

          <MultiSelect
            className="wl-select"
            options={KIND_OPTIONS}
            values={kindFilters}
            onChange={(next) => setKindFilters(next as KindFilter[])}
            allLabel="Tất cả"
            summaryUnit="loại"
            ariaLabel="Lọc theo nguồn việc"
          />

          <MultiSelect
            className="wl-select"
            options={TASK_STATUSES.map((status) => ({ value: status, label: status }))}
            values={statusFilters}
            onChange={setStatusFilters}
            allLabel="Tất cả trạng thái"
            summaryUnit="trạng thái"
            ariaLabel="Lọc theo trạng thái"
          />

          <MultiSelect
            className="wl-select"
            options={ORDER_TEAMS.map((team) => ({ value: team, label: team }))}
            values={orderFilters}
            onChange={setOrderFilters}
            allLabel="Tất cả order"
            summaryUnit="order"
            ariaLabel="Lọc theo order"
          />

          <MultiSelect
            className="wl-select"
            options={TASK_CATEGORIES.map((category) => ({ value: category, label: category }))}
            values={categoryFilters}
            onChange={setCategoryFilters}
            allLabel="Tất cả thể loại"
            summaryUnit="thể loại"
            ariaLabel="Lọc theo thể loại"
          />

          <div className="wl-people" role="group" aria-label="Lọc theo editor">
            {workload.summaries.map((summary) => (
              <button
                key={summary.editorId}
                type="button"
                className={`wl-person ${editorFilter === summary.editorId ? 'is-active' : ''}`}
                onClick={() => setEditorFilter((current) => current === summary.editorId ? 'all' : summary.editorId)}
                aria-pressed={editorFilter === summary.editorId}
                title={`${summary.label}: ${summary.total} việc, ${summary.shoots} buổi quay`}
              >
                <span className="wl-ava" style={{ background: summary.color }}>{summary.initial}</span>
                <b>{summary.total}</b>
              </button>
            ))}

            {workload.unassignedCount ? (
              <button
                type="button"
                className={`wl-person ${unassignedOnly ? 'is-active' : ''}`}
                onClick={() => setUnassignedOnly((current) => !current)}
                aria-pressed={unassignedOnly}
                title={`Chưa phân công: ${workload.unassignedCount} việc`}
              >
                <span className="wl-ava wl-ava--none">?</span>
                <b>{workload.unassignedCount}</b>
              </button>
            ) : null}
          </div>

          <div className="wl-actions">
            <span className="wl-total">{visibleCount} việc</span>
            {canCreateTask ? (
              <button type="button" className="btn btn-sm wl-btn" onClick={openTaskCreate} title="Thêm video task">
                <Plus style={{ width: '15px', height: '15px' }} /><span className="wl-btn-text">Thêm </span>task
              </button>
            ) : null}
            {canCreateContent ? (
              <button type="button" className="btn-ghost wl-btn" onClick={openContentCreate} title="Thêm dòng Content Plan">
                <Plus style={{ width: '15px', height: '15px' }} /><span className="wl-btn-text">Thêm </span>content
              </button>
            ) : null}
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="calendar-card card">
          <LoadingState
            variant="block"
            message="Đang tải..."
            shape="calendar"
            className="calendar-loading px-3 py-12 text-center text-sub"
          />
        </div>
      ) : workload.itemCount === 0 ? (
        <EmptyState title="Tháng này chưa có việc nào" />
      ) : (
        <WorkloadCalendar
          currentDate={currentDate}
          days={filteredDays}
          badges={badges}
          todayIso={todayIso}
          onOpenItem={handleOpenItem}
        />
      )}

      <ShootModal
        isOpen={isShootModalOpen}
        shoot={selectedShoot}
        editorOptions={shootsData.editorOptions}
        defaultDate={selectedShoot?.date ?? defaultDate}
        canEdit={selectedShoot ? canUpdateShoot : canCreateShoot}
        onClose={closeShootModal}
        onSave={handleShootSave}
        onDelete={canDeleteShoot ? handleShootDelete : undefined}
        isSaving={shootsData.isSaving}
        isDeleting={shootsData.isDeleting}
        errorMessage={shootsData.modalError}
      />

      <TaskModal
        isOpen={isTaskModalOpen}
        task={selectedTask}
        editors={tasksData.editors}
        selectedMonth={selectedMonth}
        defaultAirDate={defaultDateForTask}
        onClose={closeTaskModal}
        onSave={handleTaskSave}
        onSaveExecution={handleTaskExecutionSave}
        onAccept={handleTaskAccept}
        onComplete={handleTaskComplete}
        onDelete={selectedTask ? () => void handleTaskDelete(selectedTask) : undefined}
        canDelete={Boolean(selectedTask) && canDeleteTask && !tasksData.isDeleting}
        canEditLinkedTask={canEditSelectedLinkedTask}
        canAcceptLinkedTask={canAcceptSelectedTask}
        canCompleteLinkedTask={canCompleteSelectedTask}
        isSaving={tasksData.isSaving || tasksData.isDeleting}
        errorMessage={tasksData.saveError}
      />

      <ContentPlanModal
        isOpen={contentDraft !== null}
        mode={contentModalMode}
        draft={contentDraft}
        editorOptions={contentData.editorOptions}
        canEditAirDate={canEditAirDate && contentModalMode !== 'assign'}
        canEditVideoName={canEditVideoName && contentModalMode !== 'assign'}
        canEditNote={canEditNote && contentModalMode !== 'assign'}
        canEditCategory={canEditCategory && contentModalMode !== 'assign'}
        canEditEditor={canEditEditor && contentModalMode !== 'create'}
        canEditLink={canEditLink && contentModalMode !== 'assign' && !selectedContentItem?.hasLinkedTask}
        isLinkSynced={Boolean(selectedContentItem?.hasLinkedTask)}
        canDelete={Boolean(selectedContentItem) && canDeleteContent && contentModalMode === 'edit' && !contentData.isDeleting}
        isSaving={contentData.isSaving}
        errorMessage={contentFormError ?? contentData.saveError}
        onClose={closeContentModal}
        onChange={handleContentDraftChange}
        onSave={() => void handleContentSave()}
        onDelete={selectedContentItem ? () => void handleContentDelete(selectedContentItem) : undefined}
      />
    </div>
  );
}
