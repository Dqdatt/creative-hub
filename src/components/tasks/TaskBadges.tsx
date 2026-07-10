import type { Editor, TaskStatus, TaskCategory } from '../../types/task';
import { Avatar } from '../common/Avatar';

export function StatusBadge({ status }: { status: TaskStatus }) {
  const map: Record<TaskStatus, string> = {
    'Đã xong':  'badge--done',
    'Đang làm': 'badge--doing',
    'Chờ':      'badge--wait',
  };
  return (
    <span className={`badge ${map[status] ?? 'badge--wait'}`}>
      <span className="dot" />
      {status}
    </span>
  );
}

export function CategoryBadge({ category }: { category: TaskCategory }) {
  const map: Record<TaskCategory, string> = {
    'Video dài': 'tag--long',
    'Motion': 'tag--motion',
    'Ads': 'tag--ads',
  };
  return (
    <span className={`tag ${map[category] ?? 'mini-chip'}`}>
      {category}
    </span>
  );
}

export function EditorChip({ editorId, editors }: { editorId: string; editors: Editor[] }) {
  const e = editors.find((x) => x.id === editorId);
  if (!e) return null;
  return (
    <span className="inline-flex items-center gap-2">
      <Avatar src={e.avatarUrl} name={e.short || e.name} color={e.color} size="xs" />
      <span className="text-[13px] font-semibold">{e.short}</span>
    </span>
  );
}
