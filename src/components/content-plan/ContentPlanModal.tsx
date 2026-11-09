import { CalendarDays, ChevronLeft, ExternalLink, Link2, PencilLine, Trash2, UserRound, X } from 'lucide-react';
import { createPortal } from 'react-dom';
import { StyledSelect } from '../common/StyledSelect';
import { Avatar } from '../common/Avatar';
import { isSafeHttpUrl } from '../../utils/url';
import { ORDER_TEAMS } from '../../data/tasks';
import { CONTENT_PLAN_CATEGORIES } from '../../data/contentPlan';
import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanFormData } from '../../types/contentPlan';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import { useIsMobile } from '../../hooks/useIsMobile';

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
    title: 'Tạo task',
    action: 'Tạo task',
  },
  edit: {
    title: 'Chi tiết task',
    action: 'Lưu thay đổi',
  },
  assign: {
    title: 'Task',
    action: 'Lưu',
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
  const isMobile = useIsMobile();

  if (!isOpen || !draft) return null;

  const copy = MODAL_COPY[mode];
  const hasLink = isSafeHttpUrl(draft.link.trim());
  // Dữ liệu cũ có thể mang thể loại khác: vẫn hiển thị để không mất giá trị.
  const categoryOptions = CONTENT_PLAN_CATEGORIES.includes(draft.category)
    ? CONTENT_PLAN_CATEGORIES
    : [...CONTENT_PLAN_CATEGORIES, draft.category];
  const selectedEditor = editorOptions.find((editor) => editor.id === draft.editor_id) ?? null;
  const status = hasLink
    ? { tone: 'done', label: 'Đã xong' }
    : draft.editor_id
      ? { tone: 'doing', label: 'Đang làm' }
      : { tone: 'open', label: 'Chưa có người nhận' };

  return createPortal(
    <div
      className={`modal-overlay native-form-overlay fixed inset-0 z-50 flex ${mode === 'create' ? 'native-create-overlay' : ''}`}
      onClick={(event) => { if (mode !== 'create' && event.target === event.currentTarget && !isSaving) onClose(); }}
    >
      <section className={`modal-card native-form-modal content-form-modal ${mode === 'create' ? 'native-create-screen' : ''}`} role="dialog" aria-modal="true" aria-labelledby="contentPlanModalTitle">
        <span className="native-sheet-grabber" aria-hidden="true" />
        <header className="native-modal-head">
          <div className="native-modal-title-wrap">
            <span className="native-modal-icon">
              {mode === 'assign' ? <UserRound /> : <CalendarDays />}
            </span>
            <div className="min-w-0">
              <h2 id="contentPlanModalTitle" className="native-modal-title">{copy.title}</h2>
              <p className="native-modal-subtitle">
                <span className={`cpm-status cpm-status--${status.tone}`}>{status.label}</span>
              </p>
            </div>
          </div>
          <button type="button" className="icon-btn native-modal-close" onClick={onClose} disabled={isSaving} aria-label={isMobile && mode === 'create' ? 'Quay lại' : 'Đóng'}>
            {isMobile && mode === 'create' ? <ChevronLeft /> : <X />}
          </button>
          {isMobile && mode === 'create' && canSave ? (
            <button type="button" className="native-create-save" onClick={onSave} disabled={isSaving}>
              {isSaving ? 'Đang lưu' : 'Lưu'}
            </button>
          ) : null}
        </header>

        <div className="native-modal-body">
          {errorMessage ? (
            <div className="native-modal-error">{errorMessage}</div>
          ) : null}

          <div className="cpm-stack">
            <div className="cpm-field">
              <label className="flabel" htmlFor="contentPlanVideoName">Tên video</label>
              <textarea
                id="contentPlanVideoName"
                className="field cpm-title-input"
                rows={2}
                value={draft.video_name}
                disabled={isSaving || !canEditVideoName}
                onChange={(event) => onChange({ video_name: event.target.value.replace(/\n/g, ' ') })}
                placeholder="Nhập tên video..."
              />
            </div>

            <div className="cpm-props">
              <div className="cpm-field">
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
              <div className="cpm-field">
                <label className="flabel" htmlFor="contentPlanOrderTeam">Order</label>
                <StyledSelect
                  id="contentPlanOrderTeam"
                  value={draft.order_team}
                  disabled={isSaving || !canEditCategory}
                  onChange={(event) => onChange({ order_team: event.target.value })}
                >
                  {ORDER_TEAMS.map((team) => (
                    <option key={team} value={team}>{team}</option>
                  ))}
                </StyledSelect>
              </div>
              <div className="cpm-field">
                <label className="flabel" htmlFor="contentPlanCategory">Thể loại</label>
                <StyledSelect
                  id="contentPlanCategory"
                  value={draft.category}
                  disabled={isSaving || !canEditCategory}
                  onChange={(event) => onChange({ category: event.target.value as ContentPlanCategory })}
                >
                  {categoryOptions.map((category) => (
                    <option key={category} value={category}>{category}</option>
                  ))}
                </StyledSelect>
              </div>
              <div className="cpm-field">
                <label className="flabel" htmlFor="contentPlanEditor">Editor</label>
                <div className={`cpm-editor ${selectedEditor ? 'has-avatar' : ''}`}>
                  {selectedEditor ? (
                    <Avatar src={selectedEditor.avatarUrl} name={selectedEditor.short} color={selectedEditor.color} size="xs" />
                  ) : null}
                  <StyledSelect
                    id="contentPlanEditor"
                    value={draft.editor_id}
                    disabled={isSaving || !canEditEditor}
                    onChange={(event) => onChange({ editor_id: event.target.value })}
                  >
                    <option value="">Chưa có người nhận</option>
                    {editorOptions.map((editor) => (
                      <option key={editor.id} value={editor.id}>{editor.short}</option>
                    ))}
                  </StyledSelect>
                </div>
              </div>
            </div>

            <div className={`cpm-field cpm-link ${hasLink ? 'is-done' : ''}`}>
              <div className="cpm-link-head">
                <label className="flabel" htmlFor="contentPlanLink">Link thành phẩm</label>
                <span className="cpm-link-hint">{hasLink ? 'Task đã hoàn thành' : 'Có link = task hoàn thành'}</span>
              </div>
              <div className="cpm-link-row">
                <div className="relative flex-1 min-w-0">
                  <Link2 className="cpm-link-icon" />
                  <input
                    id="contentPlanLink"
                    className="field"
                    style={{ paddingLeft: '38px' }}
                    value={draft.link}
                    disabled={isSaving || !canEditLink}
                    onChange={(event) => onChange({ link: event.target.value })}
                    placeholder="Dán link Drive, YouTube..."
                  />
                </div>
                {hasLink ? (
                  <a className="btn-ghost cpm-link-open" href={draft.link.trim()} target="_blank" rel="noopener noreferrer" aria-label="Mở link thành phẩm">
                    <ExternalLink />
                  </a>
                ) : null}
              </div>
            </div>

            <div className="cpm-field">
              <label className="flabel" htmlFor="contentPlanNote">Ghi chú</label>
              <textarea
                id="contentPlanNote"
                className="field cpm-note-input"
                rows={3}
                value={draft.note}
                maxLength={2000}
                disabled={isSaving || !canEditNote}
                onChange={(event) => onChange({ note: event.target.value })}
                placeholder="Brief, source, yêu cầu thêm..."
              />
            </div>
          </div>
        </div>

        <footer className="native-modal-footer">
          <div className="native-modal-destructive">
            {mode === 'edit' && canDelete && onDelete ? (
              <button type="button" className="btn-ghost native-danger-button" onClick={onDelete} disabled={isSaving}>
                <Trash2 /> Xóa
              </button>
            ) : null}
          </div>
          <div className="native-modal-actions">
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
        </footer>
      </section>
    </div>,
    document.body
  );
}
