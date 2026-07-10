import type { ContentPlanCategory, ContentPlanEditorOption, ContentPlanItem } from '../../types/contentPlan';
import { Avatar } from '../common/Avatar';

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

export function ContentPlanTable({
  items,
  editorOptions,
  canEdit,
  onEdit,
}: ContentPlanTableProps) {
  if (items.length === 0) {
    return (
      <table className="ctable min-w-[860px]">
        <tbody>
          <tr>
            <td colSpan={4} className="px-3 py-12 text-center text-sub">
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
    <table className="ctable min-w-[860px]">
      <thead>
        <tr>
          <th style={{ width: '118px' }}>Ngày Air</th>
          <th>Tên video</th>
          <th style={{ width: '150px' }}>Thể loại</th>
          <th style={{ width: '180px' }}>Editor</th>
        </tr>
      </thead>
      <tbody>
        {items.map((item) => {
          const editor = getEditor(item.editor_id, editorOptions);

          return (
            <tr
              key={item.id}
              className={canEdit ? 'cursor-pointer' : ''}
              onClick={() => { if (canEdit) onEdit(item); }}
            >
              <td className="text-sub tabular-nums font-bold">
                {formatDate(item.air_date)}
              </td>

              <td className="font-semibold whitespace-normal" style={{ minWidth: '320px' }}>
                {item.video_name}
              </td>

              <td>
                <span className={`tag ${getCategoryClass(item.category)}`}>{item.category}</span>
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
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
