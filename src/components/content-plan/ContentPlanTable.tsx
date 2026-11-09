import { Link2 } from 'lucide-react';
import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanItem } from '../../types/contentPlan';
import { Avatar } from '../common/Avatar';
import { isSafeHttpUrl } from '../../utils/url';
import { getTodayIso } from '../../utils/month';
import { StatusBadge } from '../tasks/TaskBadges';

interface ContentPlanTableProps {
  items: ContentPlanItem[];
  editorOptions: ContentPlanEditorOption[];
  canEdit: boolean;
  onEdit: (item: ContentPlanItem) => void;
  highlightedId?: string | null;
}

function formatDate(value: string) {
  const [year, month, day] = value.split('-');
  if (!year || !month || !day) return value;
  return `${day}/${month}`;
}

function getEditor(editorId: string, editorOptions: ContentPlanEditorOption[]) {
  return editorOptions.find((editor) => editor.id === editorId) ?? null;
}

function getCategoryClass(category: ContentPlanCategory) {
  const map: Partial<Record<ContentPlanCategory, string>> = {
    'Video dài': 'tag--long',
    Motion: 'tag--motion',
  };

  return map[category] ?? '';
}

function hasValidContentPlanLink(value: string) {
  return isSafeHttpUrl(value);
}

export function ContentPlanTable({
  items,
  editorOptions,
  canEdit,
  onEdit,
  highlightedId = null,
}: ContentPlanTableProps) {
  if (items.length === 0) {
    return (
      <table className="ctable min-w-[1240px]" data-tour="content-plan-table">
        <tbody>
          <tr>
            <td colSpan={8} className="px-3 py-12 text-center text-sub">
              <div className="table-empty-state">
                <strong>Không có task phù hợp</strong>
                <span>Thử đổi tháng, editor hoặc thể loại.</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    );
  }

  const todayIso = getTodayIso();

  return (
    <table className="ctable min-w-[1240px]" data-tour="content-plan-table">
      <colgroup>
        <col style={{ width: '108px' }} />
        <col style={{ width: '96px' }} />
        <col style={{ width: '132px' }} />
        <col />
        <col style={{ width: '220px' }} />
        <col style={{ width: '172px' }} />
        <col style={{ width: '128px' }} />
        <col style={{ width: '64px' }} />
      </colgroup>
      <thead>
        <tr>
          <th>Ngày Air</th>
          <th>Order</th>
          <th>Thể loại</th>
          <th>Tên video</th>
          <th>Ghi chú</th>
          <th data-tour="content-plan-editor">Editor</th>
          <th>Task</th>
          <th className="text-center">Link</th>
        </tr>
      </thead>
      <tbody>
        {items.map((item) => {
          const isToday = item.air_date === todayIso;
          const editor = getEditor(item.editor_id, editorOptions);
          const hasLink = hasValidContentPlanLink(item.link);
          const rowClassName = [
            canEdit ? 'cursor-pointer' : '',
            hasLink ? 'vrow-done' : '',
            isToday ? 'vrow-today' : '',
            highlightedId === item.id ? 'route-highlight route-highlight--row' : '',
          ].filter(Boolean).join(' ');

          return (
            <tr
              key={item.id}
              className={rowClassName}
              data-content-plan-id={item.id}
              aria-current={highlightedId === item.id ? 'true' : undefined}
              onClick={() => { if (canEdit) onEdit(item); }}
            >
              <td className="text-sub tabular-nums font-bold">
                {formatDate(item.air_date)}
              </td>

              <td className="font-semibold text-sub whitespace-nowrap">{item.order_team}</td>

              <td>
                <span className={`tag ${getCategoryClass(item.category)}`}>{item.category}</span>
              </td>

              <td className="font-semibold whitespace-normal" style={{ minWidth: '300px' }}>
                {item.video_name}
              </td>

              <td className="text-sub">
                {item.note ? (
                  <span className="content-note-cell" title="Bấm vào hàng để mở ghi chú đầy đủ">
                    {item.note}
                  </span>
                ) : (
                  <span className="text-sub/40">—</span>
                )}
              </td>

              <td data-tour={editor ? 'content-plan-editor' : undefined}>
                {editor ? (
                  <div className="flex items-center gap-2">
                    <Avatar src={editor.avatarUrl} name={editor.short} color={editor.color} size="xs" />
                    <span className="font-semibold truncate">{editor.short}</span>
                  </div>
                ) : (
                  <span className="text-sub/60">Chưa có người nhận</span>
                )}
              </td>

              <td>
                {hasLink ? (
                  <StatusBadge status="Đã xong" />
                ) : item.linkedTaskStatus ? (
                  <StatusBadge status={item.linkedTaskStatus === 'Chờ' ? 'Đang làm' : item.linkedTaskStatus} />
                ) : (
                  <span className="text-sub/40">Chưa nhận</span>
                )}
              </td>

              <td className="text-center" onClick={(event) => event.stopPropagation()}>
                {hasLink ? (
                  <a
                    href={item.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="link-btn"
                    title="Mở link"
                    aria-label={`Mở link thành phẩm của ${item.video_name}`}
                  >
                    <Link2 />
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
