import { Printer, X } from 'lucide-react';
import { createPortal } from 'react-dom';
import { StyledSelect } from '../common/StyledSelect';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import type { Editor, VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';
import { formatVietnameseMonth } from '../../utils/month';

interface ReportModalProps {
  isOpen: boolean;
  monthValue: string;
  editorFilter: string;
  editors: Editor[];
  tasks: VideoTask[];
  shoots: ShootSchedule[];
  onMonthChange: (value: string) => void;
  onEditorChange: (value: string) => void;
  onClose: () => void;
}

function resizeCount(value: string) {
  if (!value) return 0;
  return value.split('&').filter((item) => item.trim()).length;
}

function getEditorName(editorId: string, editors: Editor[]) {
  return editors.find((editor) => editor.id === editorId)?.short ?? (editorId || 'Chưa phân công');
}

function buildFilename(monthValue: string, editorFilter: string) {
  const suffix = editorFilter === 'all' ? '' : `_${editorFilter.replace(/[^a-z0-9-]+/gi, '-')}`;
  return `CreativeHub_Report_${monthValue}${suffix}.pdf`;
}

export function ReportModal({
  isOpen,
  monthValue,
  editorFilter,
  editors,
  tasks,
  shoots,
  onMonthChange,
  onEditorChange,
  onClose,
}: ReportModalProps) {
  useDocumentScrollLock(isOpen);

  if (!isOpen) return null;

  const scopedTasks = editorFilter === 'all' ? tasks : tasks.filter((task) => task.editorId === editorFilter);
  const totalResize = scopedTasks.reduce((sum, task) => sum + resizeCount(task.resize), 0);
  const done = scopedTasks.filter((task) => task.status === 'Đã xong').length;
  const pending = scopedTasks.filter((task) => task.status === 'Chờ').length;
  const doing = scopedTasks.filter((task) => task.status === 'Đang làm').length;
  const missingLinks = scopedTasks.filter((task) => task.status === 'Đã xong' && !task.link).length;
  const title = `Báo cáo CreativeHub ${formatVietnameseMonth(monthValue)}`;
  const subtitle = editorFilter === 'all' ? 'Tất cả editor' : getEditorName(editorFilter, editors);

  const handlePrint = () => {
    const previousTitle = document.title;
    document.title = buildFilename(monthValue, editorFilter);
    window.print();
    window.setTimeout(() => {
      document.title = previousTitle;
    }, 500);
  };

  return createPortal(
    <div
      className="modal-overlay fixed inset-0 z-50 flex items-center justify-center overflow-y-auto py-10 px-4"
      onClick={(event) => { if (event.target === event.currentTarget) onClose(); }}
    >
      <section className="modal-card report-modal-card w-[94%] max-w-5xl p-5 my-auto">
        <div className="no-print mb-5 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-[18px] font-extrabold leading-tight">Tạo báo cáo</h2>
            <p className="text-[12.5px] text-sub mt-1">Thiết lập, xem trước và xuất PDF.</p>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Đóng">
            <X />
          </button>
        </div>

        <div className="no-print report-toolbar mb-5">
          <input
            type="month"
            className="field"
            value={monthValue}
            onChange={(event) => onMonthChange(event.target.value)}
            aria-label="Chọn tháng báo cáo"
          />
          <StyledSelect value={editorFilter} onChange={(event) => onEditorChange(event.target.value)}>
            <option value="all">Tất cả editor</option>
            {editors.map((editor) => (
              <option key={editor.id} value={editor.id}>{editor.short}</option>
            ))}
          </StyledSelect>
          <button type="button" className="btn ml-auto" onClick={handlePrint}>
            <Printer /> Xuất PDF
          </button>
        </div>

        <article className="report-print-root">
          <header className="report-header">
            <div>
              <p>CreativeHub</p>
              <h1>{title}</h1>
              <span>{subtitle}</span>
            </div>
            <div className="report-month">{monthValue}</div>
          </header>

          <section className="report-metrics">
            <div><strong>{scopedTasks.length}</strong><span>Tổng video</span></div>
            <div><strong>{done}</strong><span>Đã xong</span></div>
            <div><strong>{doing}</strong><span>Đang làm</span></div>
            <div><strong>{pending}</strong><span>Chờ</span></div>
            <div><strong>{totalResize}</strong><span>Resize</span></div>
            <div><strong>{shoots.length}</strong><span>Buổi quay</span></div>
          </section>

          <section className="report-section">
            <h2>Tổng quan chất lượng dữ liệu</h2>
            <p>{missingLinks} video đã xong nhưng chưa có Link thành phẩm.</p>
          </section>

          <section className="report-section">
            <h2>Chi tiết Video Task</h2>
            <table className="report-table">
              <thead>
                <tr>
                  <th>Air</th>
                  <th>Tên video</th>
                  <th>Editor</th>
                  <th>Loại</th>
                  <th>Trạng thái</th>
                  <th>Link</th>
                </tr>
              </thead>
              <tbody>
                {scopedTasks.map((task) => (
                  <tr key={task.dbId ?? task.id}>
                    <td>{task.airDate || '-'}</td>
                    <td>{task.name}</td>
                    <td>{getEditorName(task.editorId, editors)}</td>
                    <td>{task.category}</td>
                    <td>{task.status}</td>
                    <td>{task.link ? 'Có' : 'Thiếu'}</td>
                  </tr>
                ))}
                {scopedTasks.length === 0 ? (
                  <tr><td colSpan={6}>Không có Video Task trong phạm vi báo cáo.</td></tr>
                ) : null}
              </tbody>
            </table>
          </section>
        </article>
      </section>
    </div>,
    document.body
  );
}
