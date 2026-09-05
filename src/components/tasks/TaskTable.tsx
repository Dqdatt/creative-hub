import { Link2, Trash2 } from 'lucide-react';
import type { Editor, VideoTask } from '../../types/task';
import { StatusBadge, CategoryBadge, EditorChip } from './TaskBadges';
import { isSafeHttpUrl } from '../../utils/url';

interface TaskTableProps {
  tasks: VideoTask[];
  editors: Editor[];
  onRowClick: (task: VideoTask) => void;
  onDeleteTask?: (task: VideoTask) => void;
  canEditTask?: boolean;
  canDeleteTask?: boolean;
  highlightedId?: string | null;
}

export function TaskTable({
  tasks,
  editors,
  onRowClick,
  onDeleteTask,
  canEditTask = true,
  canDeleteTask = false,
  highlightedId = null,
}: TaskTableProps) {
  if (tasks.length === 0) {
    return (
      <table className="ctable min-w-[1440px]" data-tour="video-task-table">
        <tbody>
          <tr>
            <td colSpan={14} className="px-3 py-12 text-center text-sub">
              <div className="table-empty-state">
                <strong>Không có video phù hợp</strong>
                <span>Thử đổi bộ lọc hoặc từ khóa tìm kiếm.</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    );
  }

  return (
    <table className="ctable min-w-[1440px]" data-tour="video-task-table">
      <thead>
        <tr>
          <th className="text-center" style={{ width: '48px' }}>STT</th>
          <th style={{ width: '260px' }}>Tên video</th>
          <th style={{ width: '112px' }}>Resize</th>
          <th style={{ width: '144px' }}>Editor</th>
          <th style={{ width: '80px' }}>Order</th>
          <th style={{ width: '96px' }}>Thể loại</th>
          <th style={{ width: '80px' }}>Nhận</th>
          <th style={{ width: '80px' }}>Trả</th>
          <th style={{ width: '80px' }}>Air</th>
          <th style={{ width: '128px' }} data-tour="video-task-status-column">Trạng thái</th>
          <th style={{ width: '80px' }}>Ưu tiên</th>
          <th style={{ width: '220px' }}>Ghi chú</th>
          <th className="text-center" style={{ width: '64px' }} data-tour="video-task-link-column">Link</th>
          <th className="text-center" style={{ width: '84px' }}>Thao tác</th>
        </tr>
      </thead>
      <tbody>
        {tasks.map((v) => {
          const cursorClass = canEditTask ? 'cursor-pointer' : '';
          let rowBg = cursorClass;
          if (v.status === 'Đã xong') rowBg = `${cursorClass} vrow-done`;
          else if (v.priority === 'Gấp') rowBg = `${cursorClass} vrow-gap`;
          if (v.dbId && highlightedId === v.dbId) rowBg = `${rowBg} route-highlight route-highlight--row`;

          return (
            <tr
              key={v.dbId ?? v.id}
              className={rowBg}
              data-video-task-id={v.dbId}
              aria-current={v.dbId && highlightedId === v.dbId ? 'true' : undefined}
              data-tour={v.contentPlanId && (v.status === 'Pending' || v.status === 'Chờ') ? 'video-task-waiting-row' : undefined}
              onClick={() => { if (canEditTask) onRowClick(v); }}
            >
              <td className="text-center text-sub font-bold">{v.id}</td>
              <td className="font-semibold whitespace-normal" style={{ maxWidth: '260px' }}>
                {v.name}
              </td>
              <td>
                {v.resize ? (
                  <span className="text-sub">{v.resize}</span>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
              <td>
                <EditorChip editorId={v.editorId} editors={editors} />
              </td>
              <td>
                <span className="mini-chip" style={{ color: 'var(--text)' }}>
                  {v.orderTeam}
                </span>
              </td>
              <td>
                <CategoryBadge category={v.category} />
              </td>
              <td className="text-sub tabular-nums">{v.receiveDate}</td>
              <td className="text-sub tabular-nums">{v.returnDate}</td>
              <td className="font-bold tabular-nums" style={{ color: 'var(--accent)' }}>
                {v.airDate}
              </td>
              <td data-tour={v.contentPlanId && (v.status === 'Pending' || v.status === 'Chờ') ? 'video-task-accept' : v.contentPlanId && v.status === 'Đang làm' ? 'video-task-complete' : undefined}>
                <StatusBadge status={v.status} />
              </td>
              <td>
                {v.priority === 'Gấp' ? (
                  <span className="urgent">{v.priority}</span>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
              <td className="text-sub">
                {v.note ? (
                  <span className="content-note-cell" title="Bấm vào hàng để mở ghi chú đầy đủ">
                    {v.note}
                  </span>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
              <td
                className="text-center"
                data-tour={v.contentPlanId && v.status === 'Đang làm' ? 'video-task-result-link' : undefined}
                onClick={(e) => e.stopPropagation()}
              >
                {isSafeHttpUrl(v.link) ? (
                  <a
                    href={v.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="link-btn"
                    title="Mở link"
                    aria-label={`Mở link thành phẩm của ${v.name}`}
                  >
                    <Link2 style={{ width: '16px', height: '16px' }} />
                  </a>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
              <td className="text-center" onClick={(e) => e.stopPropagation()}>
                {canDeleteTask && onDeleteTask ? (
                  <button
                    type="button"
                    className="icon-btn"
                    style={{ width: '34px', height: '34px', color: 'var(--danger)' }}
                    title="Xóa Task"
                    aria-label={`Xóa task ${v.name}`}
                    onClick={() => onDeleteTask(v)}
                  >
                    <Trash2 style={{ width: '16px', height: '16px' }} />
                  </button>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
