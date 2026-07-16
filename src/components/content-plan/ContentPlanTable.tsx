import { Link2 } from 'lucide-react';
import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanItem } from '../../types/contentPlan';
import { Avatar } from '../common/Avatar';
import { isSafeHttpUrl } from '../../utils/url';

interface ContentPlanTableProps {
  items: ContentPlanItem[];
  editorOptions: ContentPlanEditorOption[];
  canEdit: boolean;
  onEdit: (item: ContentPlanItem) => void;
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
    Ads: 'tag--ads',
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
}: ContentPlanTableProps) {
  if (items.length === 0) {
    return (
      <table className="ctable min-w-[1000px]">
        <tbody>
          <tr>
            <td colSpan={6} className="px-3 py-12 text-center text-sub">
              <div className="table-empty-state">
                <strong>Không có lịch air phù hợp</strong>
                <span>Thử đổi tháng, editor hoặc thể loại.</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    );
  }

  return (
    <table className="ctable min-w-[1000px]">
      <colgroup>
        <col style={{ width: '108px' }} />
        <col style={{ width: '132px' }} />
        <col />
        <col style={{ width: '220px' }} />
        <col style={{ width: '172px' }} />
        <col style={{ width: '64px' }} />
      </colgroup>
      <thead>
        <tr>
          <th>Ngày Air</th>
          <th>Thể loại</th>
          <th>Tên video</th>
          <th>Ghi chú</th>
          <th>Editor</th>
          <th className="text-center">Link</th>
        </tr>
      </thead>
      <tbody>
        {items.map((item) => {
          const editor = getEditor(item.editor_id, editorOptions);
          const hasLink = hasValidContentPlanLink(item.link);
          const rowClassName = [
            canEdit ? 'cursor-pointer' : '',
            hasLink ? 'vrow-done' : '',
          ].filter(Boolean).join(' ');

          return (
            <tr
              key={item.id}
              className={rowClassName}
              onClick={() => { if (canEdit) onEdit(item); }}
            >
              <td className="text-sub tabular-nums font-bold">
                {formatDate(item.air_date)}
              </td>

              <td>
                <span className={`tag ${getCategoryClass(item.category)}`}>{item.category}</span>
              </td>

              <td className="font-semibold whitespace-normal" style={{ minWidth: '300px' }}>
                {item.video_name}
              </td>

              <td className="text-sub">
                <span className="content-note-cell" title={item.note || undefined}>
                  {item.note || '—'}
                </span>
              </td>

              <td>
                <div className="flex items-center gap-2">
                  <Avatar
                    src={editor?.avatarUrl}
                    name={editor?.short ?? 'Chưa phân công'}
                    color={editor?.color}
                    size="xs"
                  />
                  <span className="font-semibold truncate">{editor?.short ?? 'Chưa phân công'}</span>
                </div>
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
