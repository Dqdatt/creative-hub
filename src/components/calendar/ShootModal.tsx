import { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X, CalendarDays, CircleCheck, Trash2 } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { Avatar } from '../common/Avatar';
import type { ShootSchedule, ShootType, ShootFormData } from '../../types/shoot';
import type { ContentPlanEditorOption } from '../../types/contentPlan';
import { SHOOT_TYPES_META } from '../../data/shoots';

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

  useEffect(() => {
    if (isOpen && canEdit) setTimeout(() => crewRef.current?.focus(), 80);
  }, [canEdit, isOpen]);

  useEffect(() => {
    if (!isOpen) return undefined;

    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !isBusy) onClose();
    };

    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [isBusy, isOpen, onClose]);

  useEffect(() => {
    if (!isOpen) return undefined;

    const previousBodyOverflow = document.body.style.overflow;
    const previousHtmlOverflow = document.documentElement.style.overflow;
    document.body.style.overflow = 'hidden';
    document.documentElement.style.overflow = 'hidden';

    return () => {
      document.body.style.overflow = previousBodyOverflow;
      document.documentElement.style.overflow = previousHtmlOverflow;
    };
  }, [isOpen]);

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
      time:  get('time').trim(),
      note:  get('note').trim(),
    };

    if (!data.date || !data.place) return; // Basic validation
    onSave(data);
  };

  if (!isOpen) return null;

  const dv: ShootFormData = shoot
    ? {
        date: shoot.date, type: shoot.type, crew: shoot.crew,
        editorIds: shoot.editorIds,
        place: shoot.place, time: shoot.time, note: shoot.note,
      }
    : {
        date: defaultDate, type: 'lichquay', crew: '',
        editorIds: [],
        place: '', time: 'ALL MORNING', note: '',
      };

  return createPortal(
    <div
      className="shoot-modal-overlay modal-overlay fixed inset-0 z-50 flex items-center justify-center"
      onClick={(e) => { if (e.target === e.currentTarget && !isBusy) onClose(); }}
    >
      <form className="modal-card shoot-modal-card" onSubmit={handleSubmit} role="dialog" aria-modal="true" aria-labelledby="shootModalTitle">
        <div className="shoot-modal-head">
          <div className="shoot-modal-title-wrap">
            <span className="shoot-modal-icon" style={{ background: 'var(--grad)', color: '#fff' }}>
              <CalendarDays />
            </span>
            <h3 id="shootModalTitle" className="shoot-modal-title">
              {!canEdit && isEditMode ? 'Chi tiết lịch quay' : isEditMode ? 'Chỉnh sửa lịch quay' : 'Thêm lịch quay'}
            </h3>
          </div>
          <button type="button" onClick={onClose} className="icon-btn" disabled={isBusy} aria-label="Đóng modal">
            <X />
          </button>
        </div>

        <div className="shoot-modal-body modal-scroll-body">
          <div className="shoot-modal-stack">
            <div>
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
            
            <div className="shoot-form-grid grid grid-cols-1 sm:grid-cols-2">
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

            <div>
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

            <div>
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

            <div>
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

            <div>
              <label className="flabel">Ghi chú</label>
              <input
                name="note"
                defaultValue={dv.note}
                placeholder="Ghi chú thêm..."
                className="field"
                disabled={isBusy || !canEdit}
              />
            </div>
          </div>
        </div>

        <div className="shoot-modal-footer">
          {errorMessage ? (
            <div className="profile-inline-error shoot-modal-error">
              {errorMessage}
            </div>
          ) : null}

          <div className="shoot-modal-actions">
            {canEdit && isEditMode && onDelete && shoot ? (
              <button
                type="button"
                onClick={() => onDelete(shoot.id)}
                className="btn-ghost"
                style={{ color: 'var(--danger)' }}
                disabled={isBusy}
              >
                <Trash2 style={{ width: '16px', height: '16px' }} />
                {isDeleting ? 'Đang xóa...' : 'Xóa'}
              </button>
            ) : <div />}
            
            <div className="shoot-modal-action-group">
              <button type="button" onClick={onClose} className="btn-ghost" disabled={isBusy}>Đóng</button>
              {canEdit ? (
                <button type="submit" className="btn" disabled={isBusy}>
                  <CircleCheck style={{ width: '17px', height: '17px' }} />
                  {isSaving ? 'Đang lưu...' : isEditMode ? 'Lưu thay đổi' : 'Lưu lịch quay'}
                </button>
              ) : null}
            </div>
          </div>
        </div>
      </form>
    </div>,
    document.body
  );
}
