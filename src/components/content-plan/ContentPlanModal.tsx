import { CalendarDays, Link2, PencilLine, Trash2, UserRound, X } from 'lucide-react';
import { createPortal } from 'react-dom';
import { StyledSelect } from '../common/StyledSelect';
import { CONTENT_PLAN_CATEGORIES } from '../../data/contentPlan';
import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanFormData } from '../../types/contentPlan';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';

interface ContentPlanModalProps {
  isOpen: boolean;
  mode: 'create' | 'edit' | 'assign';
  draft: ContentPlanFormData | null;
  editorOptions: ContentPlanEditorOption[];
  canEditAirDate: boolean;
  canEditVideoName: boolean;
  canEditNote: boolean;
  canEditCategory: boolean;
  canEditEditor: boolean;
  canEditLink: boolean;
  isLinkSynced: boolean;
  canDelete: boolean;
  canSave?: boolean;
  isSaving: boolean;
  errorMessage?: string | null;
  onClose: () => void;
  onChange: (patch: Partial<ContentPlanFormData>) => void;
  onSave: () => void;
  onDelete?: () => void;
}

const MODAL_COPY = {
  create: {
    title: 'Thêm lịch air',
    action: 'Thêm dòng',
  },
  edit: {
    title: 'Sửa lịch air',
    action: 'Lưu thay đổi',
  },
  assign: {
    title: 'Phân công editor',
    action: 'Lưu phân công',
  },
};

export function ContentPlanModal({
  isOpen,
  mode,
  draft,
  editorOptions,
  canEditAirDate,
  canEditVideoName,
  canEditNote,
  canEditCategory,
  canEditEditor,
  canEditLink,
  isLinkSynced,
  canDelete,
  canSave = true,
  isSaving,
  errorMessage = null,
  onClose,
  onChange,
  onSave,
  onDelete,
}: ContentPlanModalProps) {
  useDocumentScrollLock(isOpen);

  if (!isOpen || !draft) return null;

  const copy = MODAL_COPY[mode];

  return createPortal(
    <div
      className="modal-overlay fixed inset-0 z-50 flex items-center justify-center overflow-y-auto py-10 px-4"
      onClick={(event) => { if (event.target === event.currentTarget && !isSaving) onClose(); }}
    >
      <section className="modal-card w-[90%] max-w-[560px] p-5 my-auto">
        <div className="mb-5 flex items-start justify-between gap-4">
          <div className="flex items-center gap-3">
            <span className="icoc icoc-lg" style={{ background: 'var(--grad)', color: '#fff' }}>
              {mode === 'assign' ? <UserRound style={{ width: '19px', height: '19px' }} /> : <CalendarDays style={{ width: '19px', height: '19px' }} />}
            </span>
            <div>
              <h2 className="text-[18px] font-extrabold leading-tight">{copy.title}</h2>
            </div>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} disabled={isSaving} aria-label="Đóng">
            <X />
          </button>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="flabel" htmlFor="contentPlanAirDate">Ngày Air</label>
            <input
              id="contentPlanAirDate"
              type="date"
              className="field"
              value={draft.air_date}
              disabled={isSaving || !canEditAirDate}
              onChange={(event) => onChange({ air_date: event.target.value })}
            />
          </div>

          <div>
            <label className="flabel" htmlFor="contentPlanCategory">Thể loại</label>
            <StyledSelect
              id="contentPlanCategory"
              value={draft.category}
              disabled={isSaving || !canEditCategory}
              onChange={(event) => onChange({ category: event.target.value as ContentPlanCategory })}
            >
              {CONTENT_PLAN_CATEGORIES.map((category) => (
                <option key={category} value={category}>{category}</option>
              ))}
            </StyledSelect>
          </div>

          <div className="sm:col-span-2">
            <label className="flabel" htmlFor="contentPlanVideoName">Tên video</label>
            <input
              id="contentPlanVideoName"
              className="field"
              value={draft.video_name}
              disabled={isSaving || !canEditVideoName}
              onChange={(event) => onChange({ video_name: event.target.value })}
              placeholder="Nhập tên video..."
            />
          </div>

          <div className="sm:col-span-2">
            <label className="flabel" htmlFor="contentPlanEditor">Editor</label>
            <StyledSelect
              id="contentPlanEditor"
              value={draft.editor_id}
              disabled={isSaving || !canEditEditor}
              onChange={(event) => onChange({ editor_id: event.target.value })}
            >
              <option value="">Chưa phân công</option>
              {editorOptions.map((editor) => (
                <option key={editor.id} value={editor.id}>{editor.short}</option>
              ))}
            </StyledSelect>
          </div>

          <div className="sm:col-span-2">
            <label className="flabel" htmlFor="contentPlanNote">Ghi chú</label>
            <textarea
              id="contentPlanNote"
              className="field content-note-input"
              value={draft.note}
              maxLength={2000}
              disabled={isSaving || !canEditNote}
              onChange={(event) => onChange({ note: event.target.value })}
              placeholder="Ghi chú thêm cho lịch air..."
            />
          </div>

          <div className="sm:col-span-2">
            <label className="flabel" htmlFor="contentPlanLink">Link thành phẩm</label>
            <div className="relative">
              <Link2 className="text-sub absolute left-3 top-1/2 -translate-y-1/2" style={{ width: '16px', height: '16px' }} />
              <input
                id="contentPlanLink"
                className="field"
                style={{ paddingLeft: '38px' }}
                value={draft.link}
                disabled={isSaving || !canEditLink}
                onChange={(event) => onChange({ link: event.target.value })}
                placeholder="Nhập link (Drive, Youtube, etc.)..."
              />
            </div>
            {isLinkSynced ? (
              <p className="mt-2 text-[12px] font-semibold text-sub">
                Link này được đồng bộ từ Video tháng.
              </p>
            ) : null}
          </div>
        </div>

        {errorMessage ? (
          <div className="profile-inline-error mt-4">{errorMessage}</div>
        ) : null}

        <div className="mt-5 flex flex-wrap items-center justify-between gap-2">
          {mode === 'edit' && canDelete && onDelete ? (
            <button type="button" className="btn-ghost" onClick={onDelete} disabled={isSaving} style={{ color: 'var(--danger)' }}>
              <Trash2 /> Xóa
            </button>
          ) : <div />}

          <div className="flex flex-wrap items-center justify-end gap-2">
          <button type="button" className="btn-ghost" onClick={onClose} disabled={isSaving}>
            Hủy
          </button>
          {canSave ? (
            <button type="button" className="btn" onClick={onSave} disabled={isSaving}>
              {mode === 'assign' ? <UserRound /> : <PencilLine />}
              {isSaving ? 'Đang lưu...' : copy.action}
            </button>
          ) : null}
          </div>
        </div>
      </section>
    </div>,
    document.body
  );
}
