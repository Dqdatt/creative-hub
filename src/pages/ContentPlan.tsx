import { useMemo, useState } from 'react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { ContentPlanFilters } from '../components/content-plan/ContentPlanFilters';
import { ContentPlanModal } from '../components/content-plan/ContentPlanModal';
import { ContentPlanTable } from '../components/content-plan/ContentPlanTable';
import { canEditContentPlanField } from '../config/permissions';
import { useAuth } from '../context/authContext';
import { useContentPlan } from '../hooks/useContentPlan';
import type { ContentPlanCategory, ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';

function toFormData(item: ContentPlanItem): ContentPlanFormData {
  return {
    air_date: item.air_date,
    video_name: item.video_name,
    note: item.note,
    category: item.category,
    editor_id: item.editor_id,
  };
}

function getDefaultDate(monthValue: string) {
  return `${monthValue}-01`;
}

type ContentPlanModalMode = 'create' | 'edit' | 'assign';

export default function ContentPlan() {
  const { role, permissions, can } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { selectedMonth } = useMonth();
  const {
    items,
    editorOptions,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    saveError,
    refetch,
    createItem,
    updateItem,
    deleteItem,
    clearSaveError,
  } = useContentPlan(selectedMonth);
  const [search, setSearch] = useState('');
  const [editorFilter, setEditorFilter] = useState<string | 'all'>('all');
  const [categoryFilter, setCategoryFilter] = useState<ContentPlanCategory | 'all'>('all');
  const [modalMode, setModalMode] = useState<ContentPlanModalMode>('create');
  const [selectedItem, setSelectedItem] = useState<ContentPlanItem | null>(null);
  const [draft, setDraft] = useState<ContentPlanFormData | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  const canCreate = can('content_plan:create');
  const canUpdate = can('content_plan:update');
  const canAssign = can('content_plan:assign');
  const canDelete = can('content_plan:delete');
  const canEditAirDate = canEditContentPlanField(role, 'air_date', permissions);
  const canEditVideoName = canEditContentPlanField(role, 'video_name', permissions);
  const canEditNote = canEditContentPlanField(role, 'note', permissions);
  const canEditCategory = canEditContentPlanField(role, 'category', permissions);
  const canEditEditor = canEditContentPlanField(role, 'editor_id', permissions);
  const canOpenEditor = canEditAirDate || canEditVideoName || canEditNote || canEditCategory || canEditEditor;

  const monthItems = useMemo(() =>
    items.filter((item) => item.air_date.startsWith(selectedMonth)),
    [items, selectedMonth]
  );

  const filteredItems = useMemo(() =>
    monthItems
      .filter((item) => {
        if (editorFilter !== 'all' && item.editor_id !== editorFilter) return false;
        if (categoryFilter !== 'all' && item.category !== categoryFilter) return false;
        const searchValue = search.trim().toLowerCase();
        if (!searchValue) return true;
        return item.video_name.toLowerCase().includes(searchValue);
      })
      .sort((a, b) => a.air_date.localeCompare(b.air_date) || a.id.localeCompare(b.id)),
    [categoryFilter, editorFilter, monthItems, search]
  );

  const closeModal = () => {
    setSelectedItem(null);
    setDraft(null);
    setFormError(null);
  };

  const handleAddRow = () => {
    if (!canCreate) return;

    clearSaveError();
    setSelectedItem(null);
    setModalMode('create');
    setDraft({
      air_date: getDefaultDate(selectedMonth),
      video_name: '',
      note: '',
      category: 'Video dài',
      editor_id: canEditEditor ? editorOptions[0]?.id ?? '' : '',
    });
    setFormError(null);
  };

  const handleOpenEditor = (item: ContentPlanItem) => {
    if (!canOpenEditor) return;
    clearSaveError();
    setSelectedItem(item);
    setModalMode(canUpdate ? 'edit' : 'assign');
    setDraft(toFormData(item));
    setFormError(null);
  };

  const handleDraftChange = (data: Partial<ContentPlanFormData>) => {
    setDraft((current) => current ? { ...current, ...data } : current);
    setFormError(null);
    clearSaveError();
  };

  const handleSave = async () => {
    if (!draft) return;
    if (modalMode === 'create' && !canCreate) return;
    if (modalMode === 'edit' && !canUpdate) return;
    if (modalMode === 'assign' && !canAssign) return;

    if (!draft.air_date) {
      setFormError('Vui lòng chọn ngày Air.');
      return;
    }
    if (!draft.video_name.trim()) {
      setFormError('Vui lòng nhập tên video.');
      return;
    }
    if (modalMode === 'assign' && !draft.editor_id) {
      setFormError('Vui lòng chọn editor.');
      return;
    }

    if (modalMode !== 'create' && !selectedItem) {
      setFormError('Không tìm thấy dòng lịch air cần lưu.');
      return;
    }

    const sourceItem = selectedItem ? toFormData(selectedItem) : null;
    const nextData: ContentPlanFormData = {
      air_date: canEditAirDate ? draft.air_date : sourceItem?.air_date ?? draft.air_date,
      video_name: canEditVideoName ? draft.video_name.trim() : sourceItem?.video_name ?? draft.video_name.trim(),
      note: canEditNote ? draft.note.trim() : sourceItem?.note ?? draft.note.trim(),
      category: canEditCategory ? draft.category : sourceItem?.category ?? draft.category,
      editor_id: canEditEditor ? draft.editor_id : sourceItem?.editor_id ?? '',
    };

    const saved = modalMode === 'create'
      ? await createItem(nextData)
      : selectedItem
        ? await updateItem(selectedItem, nextData)
        : false;

    if (saved) {
      closeModal();
      showToast({
        type: 'success',
        message: modalMode === 'assign' ? 'Đã phân công editor.' : 'Đã lưu lịch air.',
      });
    }
  };

  const handleCancel = () => {
    if (isSaving || isDeleting) return;
    closeModal();
    clearSaveError();
  };

  const handleDelete = async (item: ContentPlanItem) => {
    if (!canDelete) return;
    if (isSaving || isDeleting) return;
    const confirmed = await requestConfirm({
      title: 'Xóa kế hoạch content?',
      description: 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa dòng',
      variant: 'danger',
    });

    if (!confirmed) return;

    const deleted = await deleteItem(item);

    if (deleted) {
      if (selectedItem?.id === item.id) closeModal();
      showToast({ type: 'success', message: 'Đã xóa dòng lịch air.' });
    }
  };

  const renderTableContent = () => {
    if (isLoading) {
      return (
        <LoadingState
          variant="table"
          message="Đang tải Content Plan..."
          colSpan={5}
          minWidthClass="min-w-[1040px]"
          rows={8}
        />
      );
    }

    return (
      <ContentPlanTable
        items={filteredItems}
        editorOptions={editorOptions}
        canEdit={canOpenEditor && !isSaving && !isDeleting}
        onEdit={handleOpenEditor}
      />
    );
  };

  return (
    <div className="space-y-4" data-view="content-plan">
      <ContentPlanFilters
        search={search}
        editorFilter={editorFilter}
        categoryFilter={categoryFilter}
        editorOptions={editorOptions}
        totalCount={monthItems.length}
        filteredCount={filteredItems.length}
        canCreate={canCreate && !isLoading && !isSaving && !isDeleting}
        onSearchChange={setSearch}
        onEditorChange={setEditorFilter}
        onCategoryChange={setCategoryFilter}
        onCreate={handleAddRow}
      />

      {loadError ? (
        <ErrorState title="Không thể tải Content Plan" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {saveError && !draft ? (
        <ErrorState title="Không thể lưu lịch air" message={saveError} />
      ) : null}

      {!isLoading && !loadError && (items.length === 0 || monthItems.length === 0) ? (
        <EmptyState
          title="Chưa có kế hoạch content"
          message="Thêm dòng lịch air cho tháng đã chọn."
          actionLabel={canCreate ? 'Thêm dòng' : undefined}
          onAction={canCreate ? handleAddRow : undefined}
        />
      ) : null}

      <div className="card p-2 overflow-x-auto">
        {renderTableContent()}
      </div>

      <ContentPlanModal
        isOpen={draft !== null}
        mode={modalMode}
        draft={draft}
        editorOptions={editorOptions}
        canEditAirDate={canEditAirDate && modalMode !== 'assign'}
        canEditVideoName={canEditVideoName && modalMode !== 'assign'}
        canEditNote={canEditNote && modalMode !== 'assign'}
        canEditCategory={canEditCategory && modalMode !== 'assign'}
        canEditEditor={canEditEditor}
        canDelete={Boolean(selectedItem) && canDelete && modalMode === 'edit' && !isDeleting}
        isSaving={isSaving}
        errorMessage={formError ?? saveError}
        onClose={handleCancel}
        onChange={handleDraftChange}
        onSave={() => void handleSave()}
        onDelete={selectedItem ? () => void handleDelete(selectedItem) : undefined}
      />
    </div>
  );
}
