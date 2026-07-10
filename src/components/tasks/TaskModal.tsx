import { useEffect, useRef } from 'react';
import { X, Clapperboard, CircleCheck } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import type { Editor, VideoTask, TaskFormData, TaskStatus, TaskCategory, TaskPriority } from '../../types/task';
import { ORDER_TEAMS } from '../../data/tasks';

interface TaskModalProps {
  isOpen: boolean;
  task: VideoTask | null;
  editors: Editor[];
  selectedMonth: string;
  onClose: () => void;
  onSave: (data: TaskFormData) => void | Promise<void>;
  isSaving?: boolean;
  errorMessage?: string | null;
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

export function TaskModal({ isOpen, task, editors, selectedMonth, onClose, onSave, isSaving = false, errorMessage = null }: TaskModalProps) {
  const nameRef = useRef<HTMLInputElement>(null);
  const isEditMode = task !== null;

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => nameRef.current?.focus(), 80);
    }
  }, [isOpen]);

  // Escape to close
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [onClose]);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (isSaving) return;
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

  if (!isOpen) return null;

  const dv: TaskFormData = task
    ? { ...task }
    : {
        name: '', status: 'Chờ', editorId: editors[0]?.id ?? '',
        orderTeam: ORDER_TEAMS[0], category: 'Video dài',
        priority: '', resize: '', receiveDate: '', returnDate: '', airDate: '', link: '',
      };

  return (
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
              {isEditMode ? 'Chỉnh sửa Task' : 'Thêm Task mới'}
            </h3>
          </div>
          <button onClick={onClose} className="icon-btn"><X /></button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="space-y-5">
            <div>
              <label className="flabel">Tên video <span style={{ color: 'var(--danger)' }}>*</span></label>
              <input
                ref={nameRef}
                name="name"
                defaultValue={dv.name}
                required
                className="field"
                placeholder="Nhập tên video..."
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="flabel">Người làm (Editor)</label>
                <StyledSelect name="editorId" defaultValue={dv.editorId}>
                  <option value="">Chưa phân công</option>
                  {editors.map((e) => (
                    <option key={e.id} value={e.id}>{e.short}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Trạng thái</label>
                <StyledSelect name="status" defaultValue={dv.status}>
                  <option value="Chờ">Chờ</option>
                  <option value="Đang làm">Đang làm</option>
                  <option value="Đã xong">Đã xong</option>
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Team Order</label>
                <StyledSelect name="orderTeam" defaultValue={dv.orderTeam}>
                  {ORDER_TEAMS.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Thể loại</label>
                <StyledSelect name="category" defaultValue={dv.category}>
                  <option value="Video dài">Video dài</option>
                  <option value="Motion">Motion</option>
                  <option value="Ads">Ads</option>
                </StyledSelect>
              </div>
              <div>
                <label className="flabel">Độ ưu tiên</label>
                <StyledSelect name="priority" defaultValue={dv.priority}>
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
                  defaultValue={toDateInputValue(dv.receiveDate, selectedMonth)}
                  className="field task-date-field"
                />
              </div>
              <div>
                <label className="flabel">Ngày trả</label>
                <input
                  name="returnDate"
                  type="date"
                  defaultValue={toDateInputValue(dv.returnDate, selectedMonth)}
                  className="field task-date-field"
                />
              </div>
              <div>
                <label className="flabel">Ngày Air</label>
                <input
                  name="airDate"
                  type="date"
                  defaultValue={toDateInputValue(dv.airDate, selectedMonth)}
                  className="field task-date-field"
                />
              </div>
            </div>

            <div className="pt-5" style={{ borderTop: '1px solid var(--border)' }}>
              <label className="flabel">Link thành phẩm</label>
              <input
                name="resultLink"
                defaultValue={dv.link}
                className="field"
                placeholder="Nhập link (Drive, Youtube, etc.)..."
              />
            </div>
          </div>

          {errorMessage ? (
            <div className="mt-5 text-[13px] font-semibold" style={{ color: 'var(--danger)' }}>
              {errorMessage}
            </div>
          ) : null}

          <div className="mt-7 flex justify-end gap-3">
            <button type="button" onClick={onClose} className="btn-ghost" disabled={isSaving}>Đóng</button>
            <button type="submit" className="btn" disabled={isSaving}>
              <CircleCheck style={{ width: '17px', height: '17px' }} />
              {isSaving ? 'Đang lưu...' : 'Lưu thay đổi'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
