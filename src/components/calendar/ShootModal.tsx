import { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, X, CalendarDays, CircleCheck, Trash2 } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { Avatar } from '../common/Avatar';
import type { ShootSchedule, ShootType, ShootFormData } from '../../types/shoot';
import type { ContentPlanEditorOption } from '../../types/contentPlan';
import { SHOOT_TYPES_META } from '../../data/shoots';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import { useIsMobile } from '../../hooks/useIsMobile';

interface ShootModalProps {
  isOpen: boolean;
  shoot: ShootSchedule | null;
  editorOptions: ContentPlanEditorOption[];
  defaultDate: string; // Used when creating a new shoot by clicking a day
  canEdit: boolean;
  onClose: () => void;
  onSave: (data: ShootFormData) => void | Promise<void>;
  onDelete?: (id: string) => void | Promise<void>;
  isSaving?: boolean;
  isDeleting?: boolean;
  errorMessage?: string | null;
}

export function ShootModal({
  isOpen,
  shoot,
  editorOptions,
  defaultDate,
  canEdit,
  onClose,
  onSave,
  onDelete,
  isSaving = false,
  isDeleting = false,
  errorMessage = null,
}: ShootModalProps) {
  const crewRef = useRef<HTMLInputElement>(null);
  const isEditMode = shoot !== null;
  const isBusy = isSaving || isDeleting;
  const isMobile = useIsMobile();

  useDocumentScrollLock(isOpen);

  useEffect(() => {
    if (!isOpen || !canEdit || isMobile) return undefined;
    const focusTimer = window.setTimeout(() => crewRef.current?.focus(), 80);
    return () => window.clearTimeout(focusTimer);
  }, [canEdit, isMobile, isOpen]);

  useEffect(() => {
    if (!isOpen) return undefined;

    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !isBusy) onClose();
    };

    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [isBusy, isOpen, onClose]);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (isBusy || !canEdit) return;
    const form = e.currentTarget;
    const get = (id: string) =>
      (form.elements.namedItem(id) as HTMLInputElement | HTMLSelectElement)?.value ?? '';

    const data: ShootFormData = {
      date:  get('date').trim(),
      type:  get('type') as ShootType,
      crew:  get('crew').trim(),
      editorIds: Array.from(form.querySelectorAll<HTMLInputElement>('input[name="editorIds"]:checked')).map((input) => input.value),
      place: get('place').trim(),
      content: get('content').trim(),
      time:  get('time').trim(),
      note:  get('note').trim(),
    };

    if (!data.date || !data.place || !data.content) return; // Basic validation
    onSave(data);
  };

  if (!isOpen) return null;

  const dv: ShootFormData = shoot
    ? {
        date: shoot.date, type: shoot.type, crew: shoot.crew,
        editorIds: shoot.editorIds,
        place: shoot.place, content: shoot.content, time: shoot.time, note: shoot.note,
      }
    : {
        date: defaultDate, type: 'lichquay', crew: '',
        editorIds: [],
        place: '', content: '', time: 'ALL MORNING', note: '',
      };

  return createPortal(
    <div
      className={`shoot-modal-overlay modal-overlay native-form-overlay fixed inset-0 z-50 flex ${!isEditMode ? 'native-create-overlay' : ''}`}
      onClick={(e) => { if (isEditMode && e.target === e.currentTarget && !isBusy) onClose(); }}
    >
      <form className={`modal-card shoot-modal-card native-form-modal shoot-form-modal ${!isEditMode ? 'native-create-screen' : ''}`} onSubmit={handleSubmit} role="dialog" aria-modal="true" aria-labelledby="shootModalTitle">
        <span className="native-sheet-grabber" aria-hidden="true" />
        <header className="native-modal-head">
          <div className="native-modal-title-wrap">
            <span className="native-modal-icon">
              <CalendarDays />
            </span>
            <div className="min-w-0">
              <h3 id="shootModalTitle" className="native-modal-title">
                {!canEdit && isEditMode ? 'Chi tiết lịch quay' : isEditMode ? 'Chỉnh sửa lịch quay' : 'Thêm lịch quay'}
              </h3>
              <p className="native-modal-subtitle">Lịch sản xuất</p>
            </div>
          </div>
          <button type="button" onClick={onClose} className="icon-btn native-modal-close" disabled={isBusy} aria-label={isMobile && !isEditMode ? 'Quay lại' : 'Đóng modal'}>
            {isMobile && !isEditMode ? <ChevronLeft /> : <X />}
          </button>
          {isMobile && !isEditMode && canEdit ? (
            <button type="submit" className="native-create-save" disabled={isBusy}>
              {isSaving ? 'Đang lưu' : 'Lưu'}
            </button>
          ) : null}
        </header>

        <div className="native-modal-body shoot-modal-body modal-scroll-body">
          {errorMessage ? (
            <div className="native-modal-error">{errorMessage}</div>
          ) : null}

          <div className="native-form-stack shoot-modal-stack">
            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Thời gian & địa điểm</h4>
                <p>Thiết lập lịch và nơi diễn ra buổi quay.</p>
              </div>
              <div className="native-field-block">
              <label className="flabel">Ngày quay <span style={{ color: 'var(--danger)' }}>*</span></label>
              <input
                name="date"
                type="date"
                defaultValue={dv.date}
                required
                className="field"
                disabled={isBusy || !canEdit}
              />
              </div>
            
              <div className="native-form-grid shoot-form-grid grid grid-cols-1 sm:grid-cols-2">
              <div>
                <label className="flabel">Loại lịch</label>
                <StyledSelect name="type" defaultValue={dv.type} disabled={isBusy || !canEdit}>
                  {Object.entries(SHOOT_TYPES_META).map(([k, meta]) => (
                    <option key={k} value={k}>{meta.label}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Thời gian</label>
                <input
                  name="time"
                  defaultValue={dv.time}
                  placeholder="VD: BUỔI TỐI / ALL MORNING"
                  className="field"
                  disabled={isBusy || !canEdit}
                />
              </div>
              </div>

              <div className="native-field-block">
              <label className="flabel">Địa điểm <span style={{ color: 'var(--danger)' }}>*</span></label>
              <input
                name="place"
                defaultValue={dv.place}
                placeholder="VD: SHOWROOM HÒA BÌNH"
                required
                className="field"
                disabled={isBusy || !canEdit}
              />
              </div>
            </section>

            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Nhân sự</h4>
                <p>Phân công editor và ghi nhận ekip tham gia.</p>
              </div>
              <div className="native-field-block">
              <label className="flabel">Editor</label>
              <div
                className="shoot-editor-list grid gap-2 rounded-[14px] border p-2"
                style={{ borderColor: 'var(--border)', background: canEdit ? 'var(--bg2)' : 'var(--chip)', opacity: canEdit ? 1 : .72 }}
              >
                {editorOptions.length > 0 ? editorOptions.map((editor) => (
                  <label
                    key={editor.id}
                    className="shoot-editor-row flex min-h-9 items-center gap-2 rounded-[10px] px-2 text-[13px] font-bold"
                    style={{ cursor: canEdit ? 'pointer' : 'not-allowed' }}
                  >
                    <input
                      type="checkbox"
                      name="editorIds"
                      value={editor.id}
                      defaultChecked={dv.editorIds.includes(editor.id)}
                      disabled={isBusy || !canEdit}
                    />
                    <Avatar src={editor.avatarUrl} name={editor.short} color={editor.color} size="xs" />
                    <span className="truncate">{editor.short}</span>
                  </label>
                )) : (
                  <div className="px-2 py-1 text-[12.5px] font-semibold text-sub">
                    Chưa có editor để phân công.
                  </div>
                )}
              </div>
              </div>

              <div className="native-field-block">
              <label className="flabel">Crew</label>
              <input
                ref={crewRef}
                name="crew"
                defaultValue={dv.crew}
                placeholder="VD: BUMI - LINH"
                className="field"
                disabled={isBusy || !canEdit}
              />
              </div>
            </section>

            <section className="native-form-section">
              <div className="native-section-heading">
                <h4>Nội dung quay</h4>
                <p>Mô tả đầu việc và các lưu ý cho buổi sản xuất.</p>
              </div>
              <div className="native-field-block">
              <label className="flabel">Nội dung <span style={{ color: 'var(--danger)' }}>*</span></label>
              <textarea
                name="content"
                defaultValue={dv.content}
                placeholder="VD: DRAP MỚI / KỊCH BẢN CONTENT THÁNG..."
                required
                className="field shoot-textarea-field"
                disabled={isBusy || !canEdit}
              />
              </div>

              <div className="native-field-block">
              <label className="flabel">Ghi chú</label>
              <textarea
                name="note"
                defaultValue={dv.note}
                placeholder="Ghi chú thêm..."
                className="field shoot-textarea-field shoot-note-field"
                disabled={isBusy || !canEdit}
              />
              </div>
            </section>
          </div>
        </div>

        <footer className="native-modal-footer shoot-modal-footer">
          <div className="native-modal-destructive">
            {canEdit && isEditMode && onDelete && shoot ? (
              <button
                type="button"
                onClick={() => onDelete(shoot.id)}
                className="btn-ghost native-danger-button"
                disabled={isBusy}
              >
                <Trash2 />
                {isDeleting ? 'Đang xóa...' : 'Xóa'}
              </button>
            ) : null}
          </div>
          <div className="native-modal-actions">
            <button type="button" onClick={onClose} className="btn-ghost" disabled={isBusy}>Đóng</button>
            {canEdit ? (
              <button type="submit" className="btn" disabled={isBusy}>
                <CircleCheck />
                {isSaving ? 'Đang lưu...' : isEditMode ? 'Lưu thay đổi' : 'Lưu lịch quay'}
              </button>
            ) : null}
          </div>
        </footer>
      </form>
    </div>,
    document.body
  );
}
