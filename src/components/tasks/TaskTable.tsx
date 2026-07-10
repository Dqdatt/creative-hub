import { Link2 } from 'lucide-react';
import type { Editor, VideoTask } from '../../types/task';
import { StatusBadge, CategoryBadge, EditorChip } from './TaskBadges';

interface TaskTableProps {
  tasks: VideoTask[];
  editors: Editor[];
  onRowClick: (task: VideoTask) => void;
  canEditTask?: boolean;
}

export function TaskTable({ tasks, editors, onRowClick, canEditTask = true }: TaskTableProps) {
  if (tasks.length === 0) {
    return (
      <table className="ctable min-w-[1200px]">
        <tbody>
          <tr>
            <td colSpan={12} className="px-3 py-12 text-center text-sub">
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
    <table className="ctable min-w-[1200px]">
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
          <th style={{ width: '128px' }}>Trạng thái</th>
          <th style={{ width: '80px' }}>Ưu tiên</th>
          <th className="text-center" style={{ width: '64px' }}>Link</th>
        </tr>
      </thead>
      <tbody>
        {tasks.map((v) => {
          const cursorClass = canEditTask ? 'cursor-pointer' : '';
          let rowBg = cursorClass;
          if (v.status === 'Đã xong') rowBg = `${cursorClass} vrow-done`;
          else if (v.priority === 'Gấp') rowBg = `${cursorClass} vrow-gap`;

          return (
            <tr key={v.id} className={rowBg} onClick={() => { if (canEditTask) onRowClick(v); }}>
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
              <td>
                <StatusBadge status={v.status} />
              </td>
              <td>
                {v.priority === 'Gấp' ? (
                  <span className="urgent">{v.priority}</span>
                ) : (
                  <span className="text-sub/40">-</span>
                )}
              </td>
              <td className="text-center" onClick={(e) => e.stopPropagation()}>
                {v.link && v.link !== '#' ? (
                  <a
                    href={v.link}
                    target="_blank"
                    rel="noreferrer"
                    className="link-btn"
                    title="Mở link"
                  >
                    <Link2 style={{ width: '16px', height: '16px' }} />
                  </a>
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
