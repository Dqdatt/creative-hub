import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, X, Clapperboard, CircleCheck, Trash2 } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import type { Editor, VideoTask, TaskFormData, TaskStatus, TaskCategory, TaskPriority, LinkedVideoTaskExecutionData } from '../../types/task';
import { ORDER_TEAMS, TASK_CATEGORIES, TASK_STATUSES } from '../../data/tasks';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import { isSafeHttpUrl } from '../../utils/url';
import { useIsMobile } from '../../hooks/useIsMobile';

interface TaskModalProps {
  isOpen: boolean;
  task: VideoTask | null;
  editors: Editor[];
  selectedMonth: string;
  defaultAirDate?: string;
  onClose: () => void;
  onSave: (data: TaskFormData) => void | Promise<void>;
  onSaveExecution?: (data: LinkedVideoTaskExecutionData) => void | Promise<void>;
  onAccept?: (data: { receiveDate: string; returnDate: string }) => void | Promise<void>;
  onComplete?: (data: LinkedVideoTaskExecutionData) => void | Promise<void>;
  onDelete?: () => void | Promise<void>;
  canDelete?: boolean;
  canEditLinkedTask?: boolean;
  canAcceptLinkedTask?: boolean;
  canCompleteLinkedTask?: boolean;
  readOnly?: boolean;
  isSaving?: boolean;
  errorMessage?: string | null;
}

type TaskModalFieldState = {
  isLinkedTask: boolean;
  canEditTitle: boolean;
  canEditEditor: boolean;
  canEditStatus: boolean;
  canEditOrderTeam: boolean;
  canEditCategory: boolean;
  canEditPriority: boolean;
  canEditResize: boolean;
  canEditReceiveDate: boolean;
  canEditReturnDate: boolean;
  canEditAirDate: boolean;
  canEditResultLink: boolean;
  canAccept: boolean;
  canSaveExecution: boolean;
  canComplete: boolean;
  canUseGenericSave: boolean;
};

function resolveTaskModalFieldState(
  task: VideoTask | null,
  canAcceptLinkedTask: boolean,
  canCompleteLinkedTask: boolean,
  readOnly: boolean,
  canEditLinkedTask: boolean,
): TaskModalFieldState {
  const isLinkedTask = Boolean(task?.contentPlanId);

  if (readOnly) {
    return {
      isLinkedTask,
      canEditTitle: false,
      canEditEditor: false,
      canEditStatus: false,
      canEditOrderTeam: false,
      canEditCategory: false,
      canEditPriority: false,
      canEditResize: false,
      canEditReceiveDate: false,
      canEditReturnDate: false,
      canEditAirDate: false,
      canEditResultLink: false,
      canAccept: false,
      canSaveExecution: false,
      canComplete: false,
      canUseGenericSave: false,
    };
  }

  if (!isLinkedTask) {
    return {
      isLinkedTask: false,
      canEditTitle: true,
      canEditEditor: true,
      canEditStatus: true,
      canEditOrderTeam: true,
      canEditCategory: true,
      canEditPriority: true,
      canEditResize: true,
      canEditReceiveDate: true,
      canEditReturnDate: true,
      canEditAirDate: true,
      canEditResultLink: true,
      canAccept: false,
      canSaveExecution: false,
      canComplete: false,
      canUseGenericSave: true,
    };
  }

  if (canEditLinkedTask) {
    return {
      isLinkedTask: true,
      canEditTitle: false,
      // Đổi editor được, phần đồng bộ ngược sang Content Plan do RPC phân công lo.
      canEditEditor: true,
      canEditStatus: true,
      canEditOrderTeam: true,
      canEditCategory: false,
      canEditPriority: true,
      canEditResize: true,
      canEditReceiveDate: true,
      canEditReturnDate: true,
      canEditAirDate: false,
      canEditResultLink: true,
      canAccept: false,
      canSaveExecution: false,
      canComplete: false,
      canUseGenericSave: true,
    };
  }

  const canAccept = task?.status === 'Chờ' && canAcceptLinkedTask;
  const canComplete = task?.status === 'Đang làm' && canCompleteLinkedTask;
  const canSaveExecution = canComplete;

  return {
    isLinkedTask: true,
    canEditTitle: false,
    canEditEditor: false,
    canEditStatus: false,
    canEditOrderTeam: canSaveExecution,
    canEditCategory: false,
    canEditPriority: canSaveExecution,
    canEditResize: canSaveExecution,
    canEditReceiveDate: canAccept || canSaveExecution,
    canEditReturnDate: canAccept || canSaveExecution,
    canEditAirDate: false,
    canEditResultLink: canComplete,
    canAccept,
    canSaveExecution,
    canComplete,
    canUseGenericSave: false,
  };
}

function toDateInputValue(value: string, selectedMonth: string) {
  const cleanValue = value.trim();
  if (!cleanValue) return '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(cleanValue)) return cleanValue;

  const match = cleanValue.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
  if (!match) return '';

  const [, day, month, rawYear] = match;
  const fallbackYear = Number(selectedMonth.split('-')[0]) || new Date().getFullYear();
  const parsedYear = rawYear ? Number(rawYear) : fallbackYear;
  const year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;

  return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
}

function getTodayLocalDate() {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const day = String(today.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function TaskModal({
  isOpen,
  task,
  editors,
  selectedMonth,
  defaultAirDate = '',
  onClose,
  onSave,
  onSaveExecution,
  onAccept,
  onComplete,
  onDelete,
  canDelete = false,
  canEditLinkedTask = false,
  canAcceptLinkedTask = false,
  canCompleteLinkedTask = false,
  readOnly = false,
  isSaving = false,
  errorMessage = null,
}: TaskModalProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const nameRef = useRef<HTMLInputElement>(null);
  const isEditMode = task !== null;
  const fieldState = resolveTaskModalFieldState(task, canAcceptLinkedTask, canCompleteLinkedTask, readOnly, canEditLinkedTask);
  const isAcceptMode = fieldState.canAccept;
  const isCompleteMode = fieldState.canComplete;
  const [acceptReceiveDate, setAcceptReceiveDate] = useState('');
  const [acceptReturnDate, setAcceptReturnDate] = useState('');
  const [completeLink, setCompleteLink] = useState('');
  const isMobile = useIsMobile();

  useDocumentScrollLock(isOpen);

  useEffect(() => {
    if (!isOpen || isMobile || fieldState.isLinkedTask) return undefined;
    const focusTimer = window.setTimeout(() => nameRef.current?.focus(), 80);
    return () => window.clearTimeout(focusTimer);
  }, [fieldState.isLinkedTask, isMobile, isOpen]);

  useEffect(() => {
    if (!isOpen || !task) return;

    if (isAcceptMode) {
      setAcceptReceiveDate(toDateInputValue(task.receiveDate, selectedMonth) || getTodayLocalDate());
      setAcceptReturnDate(toDateInputValue(task.returnDate, selectedMonth));
    } else {
      setAcceptReceiveDate('');
      setAcceptReturnDate('');
    }
  }, [isAcceptMode, isOpen, selectedMonth, task]);

  useEffect(() => {
    if (!isOpen || !task) return;

    if (isCompleteMode) {
      setCompleteLink(task.link);
    } else {
      setCompleteLink('');
    }
  }, [isCompleteMode, isOpen, task]);

  // Escape to close
  useEffect(() => {
    if (!isOpen) return undefined;
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [isOpen, onClose]);

  const getFormValue = (name: string) =>
    (formRef.current?.elements.namedItem(name) as HTMLInputElement | HTMLSelectElement | null)?.value ?? '';

  const getExecutionData = (): LinkedVideoTaskExecutionData => ({
    orderTeam: getFormValue('orderTeam'),
    priority: getFormValue('priority') as TaskPriority,
    resize: getFormValue('resize').trim(),
    receiveDate: getFormValue('receiveDate').trim(),
    returnDate: getFormValue('returnDate').trim(),
    link: getFormValue('resultLink').trim(),
  });

  const handleSaveExecution = () => {
    if (isSaving || !fieldState.canSaveExecution) return;
    const data = getExecutionData();

    // Có link thành phẩm hợp lệ thì lưu là hoàn thành luôn, không cần bấm thêm nút Hoàn thành.
    if (data.link && isSafeHttpUrl(data.link)) {
      onComplete?.(data);
      return;
    }

    onSaveExecution?.(data);
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (isSaving) return;

    if (isAcceptMode) {
      if (acceptValidationError) return;
      onAccept?.({
        receiveDate: acceptReceiveDate,
        returnDate: acceptReturnDate,
      });
      return;
    }

    if (isCompleteMode) {
      if (completeValidationError) return;
      onComplete?.(getExecutionData());
      return;
    }

    if (!fieldState.canUseGenericSave) return;

    const form = e.currentTarget;
    const get = (name: string) =>
      (form.elements.namedItem(name) as HTMLInputElement | HTMLSelectElement)?.value ?? '';

    const data: TaskFormData = {
      name:        get('name').trim(),
      status:      get('status') as TaskStatus,
      editorId:    get('editorId'),
      orderTeam:   get('orderTeam'),
      category:    get('category') as TaskCategory,
      priority:    get('priority') as TaskPriority,
      resize:      get('resize').trim(),
      receiveDate: get('receiveDate').trim(),
      returnDate:  get('returnDate').trim(),
      airDate:     get('airDate').trim(),
      link:  get('resultLink').trim(),
      note:  get('note').trim(),
    };

    if (!data.name) return; // Simple validation
    onSave(data);
  };

  const dv: TaskFormData = task
    ? { ...task, note: task.note ?? '' }
    : {
        name: '', status: 'Chờ', editorId: editors[0]?.id ?? '',
        orderTeam: ORDER_TEAMS[0], category: 'Video dài',
        priority: '', resize: '', receiveDate: '', returnDate: '', airDate: defaultAirDate, link: '', note: '',
      };
  const acceptValidationError = !isAcceptMode
    ? null
    : !acceptReceiveDate || !acceptReturnDate
      ? 'Vui lòng chọn Ngày nhận và Ngày trả.'
      : acceptReturnDate < acceptReceiveDate
        ? 'Ngày trả phải sau hoặc bằng Ngày nhận.'
        : null;
  const completeValidationError = !isCompleteMode
    ? null
    : !completeLink.trim()
      ? 'Vui lòng nhập Link thành phẩm.'
      : !isSafeHttpUrl(completeLink)
        ? 'Link thành phẩm chưa hợp lệ.'
        : null;
  const submitDisabled = isSaving
    || (isAcceptMode && Boolean(acceptValidationError))
    || (isCompleteMode && Boolean(completeValidationError));
  const showSubmitButton = fieldState.canUseGenericSave || isAcceptMode || isCompleteMode;

  if (!isOpen) return null;

  return createPortal(
    <div 
      className={`modal-overlay native-form-overlay fixed inset-0 z-50 flex ${!isEditMode ? 'native-create-overlay' : ''}`}
      onClick={(e) => { if (isEditMode && e.target === e.currentTarget) onClose(); }}
    >
      <form ref={formRef} className={`modal-card native-form-modal task-form-modal ${!isEditMode ? 'native-create-screen' : ''}`} onSubmit={handleSubmit} role="dialog" aria-modal="true" aria-labelledby="taskModalTitle">
        <span className="native-sheet-grabber" aria-hidden="true" />
        <header className="native-modal-head">
          <div className="native-modal-title-wrap">
            <span className="native-modal-icon">
              <Clapperboard />
            </span>
            <div className="min-w-0">
              <h3 id="taskModalTitle" className="native-modal-title">
                {isAcceptMode ? 'Nhận Task' : isCompleteMode ? 'Hoàn thành Task' : isEditMode ? 'Chỉnh sửa Task' : 'Thêm Task mới'}
              </h3>
              <p className="native-modal-subtitle">Video tháng</p>
            </div>
          </div>
          <button type="button" onClick={onClose} className="icon-btn native-modal-close" disabled={isSaving} aria-label={isMobile && !isEditMode ? 'Quay lại' : 'Đóng'}>
            {isMobile && !isEditMode ? <ChevronLeft /> : <X />}
          </button>
          {isMobile && !isEditMode && showSubmitButton ? (
            <button type="submit" className="native-create-save" disabled={submitDisabled}>
              {isSaving ? 'Đang lưu' : 'Lưu'}
            </button>
          ) : null}
        </header>

        <div className="native-modal-body">

          {acceptValidationError || completeValidationError ? (
            <div className="native-modal-error">{acceptValidationError ?? completeValidationError}</div>
          ) : null}

          {errorMessage ? (
            <div className="native-modal-error">{errorMessage}</div>
          ) : null}

          <div className="native-form-stack">
            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Thông tin chính</h4>
                <p>Tên video, người thực hiện và phân loại công việc.</p>
              </div>
              <div className="native-field-block">
              <label className="flabel">Tên video <span style={{ color: 'var(--danger)' }}>*</span></label>
              <input
                ref={nameRef}
                name="name"
                defaultValue={dv.name}
                required
                className="field"
                readOnly={!fieldState.canEditTitle}
                disabled={isSaving && fieldState.canEditTitle}
                aria-readonly={!fieldState.canEditTitle}
                placeholder="Nhập tên video..."
              />
              </div>

              <div className="native-form-grid grid grid-cols-1 sm:grid-cols-2">
              <div>
                <label className="flabel">Người làm (Editor)</label>
                <StyledSelect name="editorId" defaultValue={dv.editorId} disabled={isSaving || !fieldState.canEditEditor}>
                  <option value="">Chưa phân công</option>
                  {editors.map((e) => (
                    <option key={e.id} value={e.id}>{e.short}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Trạng thái</label>
                <StyledSelect name="status" defaultValue={dv.status} disabled={isSaving || !fieldState.canEditStatus}>
                  {TASK_STATUSES.map((status) => (
                    <option key={status} value={status}>{status}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Team Order</label>
                <StyledSelect name="orderTeam" defaultValue={dv.orderTeam} disabled={isSaving || !fieldState.canEditOrderTeam}>
                  {ORDER_TEAMS.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Thể loại</label>
                <StyledSelect name="category" defaultValue={dv.category} disabled={isSaving || !fieldState.canEditCategory}>
                  {TASK_CATEGORIES.map((category) => (
                    <option key={category} value={category}>{category}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Độ ưu tiên</label>
                <StyledSelect name="priority" defaultValue={dv.priority} disabled={isSaving || !fieldState.canEditPriority}>
                  <option value="">Bình thường</option>
                  <option value="Gấp">Gấp</option>
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Resize</label>
                <input
                  name="resize"
                  defaultValue={dv.resize}
                  className="field"
                  readOnly={!fieldState.canEditResize}
                  disabled={isSaving && fieldState.canEditResize}
                  aria-readonly={!fieldState.canEditResize}
                  placeholder="VD: 9x16 & 1x1"
                />
              </div>
              </div>
            </section>

            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Tiến độ & thời gian</h4>
                <p>Các mốc ngày dùng để theo dõi và lên lịch air.</p>
              </div>
              <div className="native-form-grid native-date-grid grid grid-cols-1 sm:grid-cols-3">
              <div>
                <label className="flabel">Ngày nhận</label>
                <input
                  name="receiveDate"
                  type="date"
                  defaultValue={isAcceptMode ? undefined : toDateInputValue(dv.receiveDate, selectedMonth)}
                  value={isAcceptMode ? acceptReceiveDate : undefined}
                  disabled={isSaving || !fieldState.canEditReceiveDate}
                  onChange={isAcceptMode ? (event) => setAcceptReceiveDate(event.target.value) : undefined}
                  className="field task-date-field"
                />
              </div>
              <div>
                <label className="flabel">Ngày trả</label>
                <input
                  name="returnDate"
                  type="date"
                  defaultValue={isAcceptMode ? undefined : toDateInputValue(dv.returnDate, selectedMonth)}
                  value={isAcceptMode ? acceptReturnDate : undefined}
                  disabled={isSaving || !fieldState.canEditReturnDate}
                  onChange={isAcceptMode ? (event) => setAcceptReturnDate(event.target.value) : undefined}
                  className="field task-date-field"
                />
              </div>
              <div>
                <label className="flabel">Ngày Air</label>
                <input
                  name="airDate"
                  type="date"
                  defaultValue={toDateInputValue(dv.airDate, selectedMonth)}
                  disabled={isSaving || !fieldState.canEditAirDate}
                  className="field task-date-field"
                />
              </div>
              </div>
            </section>

            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Bàn giao</h4>
                <p>Đính kèm thành phẩm và ghi chú cần thiết.</p>
              </div>
              <div className="native-field-block">
              <label className="flabel">Link thành phẩm</label>
              <input
                name="resultLink"
                defaultValue={isCompleteMode ? undefined : dv.link}
                value={isCompleteMode ? completeLink : undefined}
                className="field"
                readOnly={!fieldState.canEditResultLink}
                disabled={isSaving && fieldState.canEditResultLink}
                aria-readonly={!fieldState.canEditResultLink}
                onChange={isCompleteMode ? (event) => setCompleteLink(event.target.value) : undefined}
                placeholder="Nhập link (Drive, Youtube, etc.)..."
              />
              </div>

              <div className="native-field-block">
              <label className="flabel">Ghi chú</label>
              <textarea
                name="note"
                defaultValue={dv.note}
                className="field content-note-input"
                readOnly={readOnly || (fieldState.isLinkedTask && !fieldState.canUseGenericSave)}
                disabled={isSaving && !readOnly && (!fieldState.isLinkedTask || fieldState.canUseGenericSave)}
                aria-readonly={readOnly || (fieldState.isLinkedTask && !fieldState.canUseGenericSave)}
                placeholder="Ghi chú thêm cho task..."
              />
              </div>
            </section>
          </div>
        </div>

        <footer className="native-modal-footer">
          <div className="native-modal-destructive">
            {isEditMode && canDelete && onDelete ? (
              <button type="button" className="btn-ghost native-danger-button" onClick={onDelete} disabled={isSaving}>
                <Trash2 />
                Xóa Task
              </button>
            ) : null}
          </div>
          <div className="native-modal-actions">
            <button type="button" onClick={onClose} className="btn-ghost" disabled={isSaving}>Đóng</button>
            {fieldState.canSaveExecution ? (
              <button type="button" className="btn-ghost" onClick={handleSaveExecution} disabled={isSaving}>
                <CircleCheck />
                {isSaving ? 'Đang lưu...' : 'Lưu thay đổi'}
              </button>
            ) : null}
            {showSubmitButton ? (
              <button type="submit" className="btn" disabled={submitDisabled}>
                <CircleCheck />
                {isSaving ? 'Đang lưu...' : isAcceptMode ? 'Nhận Task' : isCompleteMode ? 'Hoàn thành' : isEditMode ? 'Lưu thay đổi' : 'Thêm Task'}
              </button>
            ) : null}
          </div>
        </footer>
      </form>
    </div>,
    document.body
  );
}
