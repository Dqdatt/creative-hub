import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { ContentPlanFilters } from '../components/content-plan/ContentPlanFilters';
import { ContentPlanModal } from '../components/content-plan/ContentPlanModal';
import { ContentPlanTable } from '../components/content-plan/ContentPlanTable';
import { canEditContentPlanField } from '../config/permissions';
import { useAuth } from '../context/authContext';
import { useContentPlan } from '../hooks/useContentPlan';
import { useRouteHighlight } from '../hooks/useRouteHighlight';
import { fetchContentPlanItemById } from '../services/contentPlanService';
import type { ContentPlanCategory, ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';
import { isUuid } from '../utils/id';
import { isSafeHttpUrl } from '../utils/url';
import { CONTENT_PLAN_CATEGORIES } from '../data/contentPlan';
import { ORDER_TEAMS } from '../data/tasks';
import { useIsMobile } from '../hooks/useIsMobile';
import { useCreateParam } from '../hooks/useCreateParam';
import { MobileToolbar, FilterGroup } from '../components/mobile/MobileToolbar';
import { ContentPlanCardList } from '../components/mobile/ContentPlanCardList';

function toFormData(item: ContentPlanItem): ContentPlanFormData {
  return {
    air_date: item.air_date,
    video_name: item.video_name,
    note: item.note,
    category: item.category,
    order_team: item.order_team,
    editor_id: item.editor_id,
    link: item.link,
  };
}

function getDefaultDate(monthValue: string) {
  return `${monthValue}-01`;
}

function hasValidContentPlanLink(value: string) {
  return isSafeHttpUrl(value);
}

function hasContentFieldChanges(current: ContentPlanItem, nextData: ContentPlanFormData) {
  return current.air_date !== nextData.air_date
    || current.video_name !== nextData.video_name
    || current.note !== nextData.note
    || current.category !== nextData.category
    || current.order_team !== nextData.order_team
    || current.link !== nextData.link;
}

type ContentPlanModalMode = 'create' | 'edit' | 'assign';

export default function ContentPlan() {
  const { role, permissions, can } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { selectedMonth, setSelectedMonth } = useMonth();
  const [searchParams, setSearchParams] = useSearchParams();
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
    assignEditor,
    deleteItem,
    clearSaveError,
  } = useContentPlan(selectedMonth);
  const [search, setSearch] = useState('');
  const [editorFilter, setEditorFilter] = useState<string | 'all'>('all');
  const [categoryFilter, setCategoryFilter] = useState<ContentPlanCategory | 'all'>('all');
  const [orderFilter, setOrderFilter] = useState<string | 'all'>('all');
  const [modalMode, setModalMode] = useState<ContentPlanModalMode>('create');
  const [selectedItem, setSelectedItem] = useState<ContentPlanItem | null>(null);
  const [draft, setDraft] = useState<ContentPlanFormData | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  const canCreate = can('content_plan:create');
  const canUpdate = can('content_plan:update');
  const canDelete = can('content_plan:delete');
  const canEditAirDate = canEditContentPlanField(role, 'air_date', permissions);
  const canEditVideoName = canEditContentPlanField(role, 'video_name', permissions);
  const canEditNote = canEditContentPlanField(role, 'note', permissions);
  const canEditCategory = canEditContentPlanField(role, 'category', permissions);
  const canEditEditor = canEditContentPlanField(role, 'editor_id', permissions);
  const canEditLink = canEditContentPlanField(role, 'link', permissions);
  const canOpenEditor = canEditAirDate || canEditVideoName || canEditNote || canEditCategory || canEditEditor || canEditLink;
  const highlightParam = searchParams.get('highlight');
  const legacyItemParam = searchParams.get('item');
  const targetContentPlanId = highlightParam ?? legacyItemParam;

  const monthItems = useMemo(() =>
    items.filter((item) => item.air_date.startsWith(selectedMonth)),
    [items, selectedMonth]
  );

  const filteredItems = useMemo(() =>
    monthItems
      .filter((item) => {
        if (editorFilter !== 'all' && item.editor_id !== editorFilter) return false;
        if (categoryFilter !== 'all' && item.category !== categoryFilter) return false;
        if (orderFilter !== 'all' && item.order_team !== orderFilter) return false;
        const searchValue = search.trim().toLowerCase();
        if (!searchValue) return true;
        return item.video_name.toLowerCase().includes(searchValue);
      })
      .sort((a, b) => {
        const aCompleted = hasValidContentPlanLink(a.link);
        const bCompleted = hasValidContentPlanLink(b.link);
        if (aCompleted !== bCompleted) return aCompleted ? 1 : -1;
        return a.air_date.localeCompare(b.air_date) || a.id.localeCompare(b.id);
      }),
    [categoryFilter, editorFilter, monthItems, orderFilter, search]
  );

  const clearHighlightParams = useCallback(() => {
    setSearchParams((current) => {
      const next = new URLSearchParams(current);
      next.delete('highlight');
      next.delete('item');
      return next;
    }, { replace: true });
  }, [setSearchParams]);

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
      order_team: 'BRAND',
      editor_id: '',
      link: '',
    });
    setFormError(null);
  };

  const isMobile = useIsMobile();
  useCreateParam({ content: handleAddRow }, !isLoading);

  const handleOpenEditor = (item: ContentPlanItem) => {
    if (!canOpenEditor) return;
    clearSaveError();
    setSelectedItem(item);
    setModalMode(canUpdate ? 'edit' : 'assign');
    setDraft(toFormData(item));
    setFormError(null);
  };

  useEffect(() => {
    if (!targetContentPlanId) return;

    if (!isUuid(targetContentPlanId)) {
      showToast({ type: 'warning', message: 'Đường dẫn Content Plan không hợp lệ.' });
      clearHighlightParams();
      return;
    }

    const visibleItem = items.find((item) => item.id === targetContentPlanId);
    if (visibleItem) {
      const targetMonth = visibleItem.air_date.slice(0, 7);
      if (targetMonth !== selectedMonth) setSelectedMonth(targetMonth);
      if (search || editorFilter !== 'all' || categoryFilter !== 'all' || orderFilter !== 'all') {
        setSearch('');
        setEditorFilter('all');
        setCategoryFilter('all');
        setOrderFilter('all');
      }
      return;
    }

    if (isLoading) return;

    let cancelled = false;

    void fetchContentPlanItemById(targetContentPlanId)
      .then((item) => {
        if (cancelled) return;
        if (!item) {
          showToast({ type: 'warning', message: 'Không tìm thấy Content Plan liên quan.' });
          clearHighlightParams();
          return;
        }

        const targetMonth = item.air_date.slice(0, 7);
        if (targetMonth !== selectedMonth) setSelectedMonth(targetMonth);
      })
      .catch(() => {
        if (cancelled) return;
        showToast({ type: 'warning', message: 'Nội dung liên quan không còn tồn tại hoặc bạn không có quyền xem.' });
        clearHighlightParams();
      });

    return () => {
      cancelled = true;
    };
  }, [categoryFilter, clearHighlightParams, editorFilter, isLoading, items, orderFilter, search, selectedMonth, setSelectedMonth, showToast, targetContentPlanId]);

  const handleHighlightMissing = useCallback(() => {
    showToast({ type: 'warning', message: 'Không tìm thấy Content Plan liên quan.' });
  }, [showToast]);

  const highlightedContentPlanId = useRouteHighlight({
    targetId: targetContentPlanId && isUuid(targetContentPlanId) ? targetContentPlanId : null,
    selector: targetContentPlanId && isUuid(targetContentPlanId) ? `[data-content-plan-id="${targetContentPlanId}"]` : null,
    ready: !isLoading && filteredItems.some((item) => item.id === targetContentPlanId),
    clearQuery: clearHighlightParams,
    onMissing: handleHighlightMissing,
  });

  const handleDraftChange = (data: Partial<ContentPlanFormData>) => {
    setDraft((current) => current ? { ...current, ...data } : current);
    setFormError(null);
    clearSaveError();
  };

  // v2.0.0: không phân quyền. Mọi tài khoản sửa được mọi thông tin và chọn Editor cho Task.
  const handleSave = async () => {
    if (!draft) return;

    if (!draft.air_date) {
      setFormError('Vui lòng chọn ngày Air.');
      return;
    }
    if (!draft.video_name.trim()) {
      setFormError('Vui lòng nhập tên video.');
      return;
    }
    const link = draft.link.trim();
    if (link && !hasValidContentPlanLink(link)) {
      setFormError('Link thành phẩm không hợp lệ.');
      return;
    }

    const nextData: ContentPlanFormData = {
      ...draft,
      video_name: draft.video_name.trim(),
      note: draft.note.trim(),
      link,
    };

    if (modalMode === 'create') {
      const createdId = await createItem({ ...nextData, editor_id: '' });
      if (!createdId) return;
      if (nextData.editor_id && typeof createdId === 'string') {
        const created = { id: createdId, ...nextData, editor_id: '', hasLinkedTask: false } as ContentPlanItem;
        if (!await assignEditor(created, nextData.editor_id)) return;
      }
      closeModal();
      showToast({ type: 'success', message: 'Đã tạo task.' });
      return;
    }

    if (!selectedItem) {
      setFormError('Không tìm thấy task cần lưu.');
      return;
    }

    const editorChanged = selectedItem.editor_id !== nextData.editor_id;
    const contentChanged = hasContentFieldChanges(selectedItem, nextData);

    if (contentChanged && !await updateItem(selectedItem, { ...nextData, editor_id: selectedItem.editor_id })) return;
    if (editorChanged && !await assignEditor(selectedItem, nextData.editor_id)) return;

    closeModal();
    if (editorChanged || contentChanged) {
      showToast({
        type: 'success',
        message: link && link !== selectedItem.link ? 'Đã lưu link, task hoàn thành.' : 'Đã lưu task.',
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
      title: 'Xóa task?',
      description: 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa task',
      variant: 'danger',
    });

    if (!confirmed) return;

    const deleted = await deleteItem(item);

    if (deleted) {
      if (selectedItem?.id === item.id) closeModal();
      showToast({ type: 'success', message: 'Đã xóa task.' });
    }
  };

  const renderTableContent = () => {
    if (isMobile) {
      if (isLoading) return <LoadingState variant="block" shape="list" message="Đang tải task..." className="m-loading-list" />;
      return (
        <ContentPlanCardList
          items={filteredItems}
          editorOptions={editorOptions}
          canEdit={canOpenEditor && !isSaving && !isDeleting}
          onEdit={handleOpenEditor}
          highlightedId={highlightedContentPlanId}
        />
      );
    }

    if (isLoading) {
      return (
        <LoadingState
          variant="table"
          message="Đang tải task..."
          colSpan={8}
          minWidthClass="min-w-[1240px]"
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
        highlightedId={highlightedContentPlanId}
      />
    );
  };

  return (
    <div className="space-y-4" data-view="content-plan">
      {isMobile ? (
        <MobileToolbar<ContentPlanCategory | 'all'>
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Tìm task..."
          chips={[{ value: 'all', label: 'Tất cả' }, ...CONTENT_PLAN_CATEGORIES.map((category) => ({ value: category, label: category }))]}
          chipValue={categoryFilter}
          onChipChange={setCategoryFilter}
          chipsLabel="Lọc theo thể loại"
          activeFilterCount={(editorFilter !== 'all' ? 1 : 0) + (orderFilter !== 'all' ? 1 : 0)}
          onResetFilters={() => {
            setEditorFilter('all');
            setOrderFilter('all');
          }}
          resultLabel={`${filteredItems.length} task${filteredItems.length !== monthItems.length ? ` (trên tổng ${monthItems.length})` : ''}`}
          filters={(
            <>
              <FilterGroup
                label="Editor"
                value={editorFilter}
                onChange={setEditorFilter}
                options={[{ value: 'all', label: 'Tất cả editor' }, ...editorOptions.map((editor) => ({ value: editor.id, label: editor.short }))]}
              />
              <FilterGroup
                label="Order"
                value={orderFilter}
                onChange={setOrderFilter}
                options={[{ value: 'all', label: 'Tất cả order' }, ...ORDER_TEAMS.map((team) => ({ value: team, label: team }))]}
              />
            </>
          )}
        />
      ) : (
      <ContentPlanFilters
        search={search}
        editorFilter={editorFilter}
        categoryFilter={categoryFilter}
        orderFilter={orderFilter}
        editorOptions={editorOptions}
        totalCount={monthItems.length}
        filteredCount={filteredItems.length}
        canCreate={canCreate && !isLoading && !isSaving && !isDeleting}
        onSearchChange={setSearch}
        onEditorChange={setEditorFilter}
        onCategoryChange={setCategoryFilter}
        onOrderChange={setOrderFilter}
        onCreate={handleAddRow}
      />
      )}

      {loadError ? (
        <ErrorState title="Không thể tải danh sách task" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {saveError && !draft ? (
        <ErrorState title="Không thể lưu task" message={saveError} />
      ) : null}

      {!isLoading && !loadError && (items.length === 0 || monthItems.length === 0) ? (
        <EmptyState
          title="Chưa có task"
          message="Tạo task video cho tháng đã chọn, editor tự nhận để làm."
          actionLabel={canCreate ? 'Tạo task' : undefined}
          onAction={canCreate ? handleAddRow : undefined}
        />
      ) : null}

      {isMobile ? renderTableContent() : (
        <div className="card p-2 overflow-x-auto">
          {renderTableContent()}
        </div>
      )}

      <ContentPlanModal
        isOpen={draft !== null}
        mode={modalMode}
        draft={draft}
        editorOptions={editorOptions}
        canEditAirDate={canEditAirDate && modalMode !== 'assign'}
        canEditVideoName={canEditVideoName && modalMode !== 'assign'}
        canEditNote={canEditNote && modalMode !== 'assign'}
        canEditCategory={canEditCategory && modalMode !== 'assign'}
        canEditEditor
        canEditLink
        isLinkSynced={false}
        canDelete={Boolean(selectedItem) && !isDeleting}
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
