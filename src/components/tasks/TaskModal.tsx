import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { X, Clapperboard, CircleCheck } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import type { Editor, VideoTask, TaskFormData, TaskStatus, TaskCategory, TaskPriority, LinkedVideoTaskExecutionData } from '../../types/task';
import { ORDER_TEAMS } from '../../data/tasks';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import { isSafeHttpUrl } from '../../utils/url';

interface TaskModalProps {
  isOpen: boolean;
  task: VideoTask | null;
  editors: Editor[];
  selectedMonth: string;
  onClose: () => void;
  onSave: (data: TaskFormData) => void | Promise<void>;
  onSaveExecution?: (data: LinkedVideoTaskExecutionData) => void | Promise<void>;
  onAccept?: (data: { receiveDate: string; returnDate: string }) => void | Promise<void>;
  onComplete?: (data: LinkedVideoTaskExecutionData) => void | Promise<void>;
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
  onClose,
  onSave,
  onSaveExecution,
  onAccept,
  onComplete,
  canAcceptLinkedTask = false,
  canCompleteLinkedTask = false,
  readOnly = false,
  isSaving = false,
  errorMessage = null,
}: TaskModalProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const nameRef = useRef<HTMLInputElement>(null);
  const isEditMode = task !== null;
  const fieldState = resolveTaskModalFieldState(task, canAcceptLinkedTask, canCompleteLinkedTask, readOnly);
  const isAcceptMode = fieldState.canAccept;
  const isCompleteMode = fieldState.canComplete;
  const isLinkedDoneTask = fieldState.isLinkedTask && task?.status === 'Đã xong';
  const [acceptReceiveDate, setAcceptReceiveDate] = useState('');
  const [acceptReturnDate, setAcceptReturnDate] = useState('');
  const [completeLink, setCompleteLink] = useState('');

  useDocumentScrollLock(isOpen);

  useEffect(() => {
    if (!isOpen || fieldState.isLinkedTask) return undefined;
    const focusTimer = window.setTimeout(() => nameRef.current?.focus(), 80);
    return () => window.clearTimeout(focusTimer);
  }, [fieldState.isLinkedTask, isOpen]);

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
    onSaveExecution?.(getExecutionData());
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
    };

    if (!data.name) return; // Simple validation
    onSave(data);
  };

  const dv: TaskFormData = task
    ? { ...task }
    : {
        name: '', status: 'Chờ', editorId: editors[0]?.id ?? '',
        orderTeam: ORDER_TEAMS[0], category: 'Video dài',
        priority: '', resize: '', receiveDate: '', returnDate: '', airDate: '', link: '',
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
      className="modal-overlay fixed inset-0 z-50 flex items-center justify-center overflow-y-auto py-10 px-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="modal-card w-[90%] max-w-2xl p-7 my-auto">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <span className="icoc icoc-lg" style={{ background: 'var(--grad)', color: '#fff' }}>
              <Clapperboard style={{ width: '20px', height: '20px' }} />
            </span>
            <h3 className="font-extrabold text-[19px] leading-none tracking-tight">
              {isAcceptMode ? 'Nhận Task' : isCompleteMode ? 'Hoàn thành Task' : isEditMode ? 'Chỉnh sửa Task' : 'Thêm Task mới'}
            </h3>
          </div>
          <button onClick={onClose} className="icon-btn"><X /></button>
        </div>

        <form ref={formRef} onSubmit={handleSubmit}>
          <div className="space-y-5">
            <div>
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

            {fieldState.isLinkedTask ? (
              <p className="text-[12px] font-semibold text-sub">
                Thông tin kế hoạch được đồng bộ từ Content Plan và không thể chỉnh sửa tại Video tháng.
              </p>
            ) : null}

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
                  <option value="Chờ">Chờ</option>
                  <option value="Đang làm">Đang làm</option>
                  <option value="Đã xong">Đã xong</option>
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
                  <option value="Video dài">Video dài</option>
                  <option value="Motion">Motion</option>
                  <option value="Ads">Ads</option>
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

            <div className="grid grid-cols-3 gap-4 pt-5" style={{ borderTop: '1px solid var(--border)' }}>
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

            <div className="pt-5" style={{ borderTop: '1px solid var(--border)' }}>
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
              {isLinkedDoneTask ? (
                <p className="mt-2 text-[12px] font-semibold text-sub">
                  Link đã được đồng bộ về Content Plan.
                </p>
              ) : null}
            </div>
          </div>

          {acceptValidationError || completeValidationError ? (
            <div className="mt-5 text-[13px] font-semibold" style={{ color: 'var(--danger)' }}>
              {acceptValidationError ?? completeValidationError}
            </div>
          ) : null}

          {errorMessage ? (
            <div className="mt-5 text-[13px] font-semibold" style={{ color: 'var(--danger)' }}>
              {errorMessage}
            </div>
          ) : null}

          <div className="mt-7 flex justify-end gap-3">
            <button type="button" onClick={onClose} className="btn-ghost" disabled={isSaving}>Đóng</button>
            {fieldState.canSaveExecution ? (
              <button type="button" className="btn-ghost" onClick={handleSaveExecution} disabled={isSaving}>
                <CircleCheck style={{ width: '17px', height: '17px' }} />
                {isSaving ? 'Đang lưu...' : 'Lưu thay đổi'}
              </button>
            ) : null}
            {showSubmitButton ? (
              <button type="submit" className="btn" disabled={submitDisabled}>
                <CircleCheck style={{ width: '17px', height: '17px' }} />
                {isSaving ? 'Đang lưu...' : isAcceptMode ? 'Nhận Task' : isCompleteMode ? 'Hoàn thành' : 'Lưu thay đổi'}
              </button>
            ) : null}
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
}
