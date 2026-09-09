import { useMemo } from 'react';
import { SHOOT_TYPES_META } from '../data/shoots';
import { ORDER_TEAMS } from '../data/tasks';
import type { ContentPlanItem } from '../types/contentPlan';
import type { ShootSchedule, ShootType } from '../types/shoot';
import type { Editor, TaskStatus, VideoTask } from '../types/task';

export type WorkloadKind = 'shoot' | 'task' | 'plan';

export const UNASSIGNED_EDITOR_ID = '__unassigned__';

// Dòng Content Plan chưa sinh task thì chưa có phòng ban order trong database.
// Lấy đúng mặc định mà trigger dưới database sẽ gán khi task được tạo, để bộ lọc order
// không bỏ sót những dòng chưa phân công.
const CONTENT_PLAN_DEFAULT_ORDER_TEAM = 'BRAND';

export interface WorkloadItem {
  id: string;
  sourceId: string;
  kind: WorkloadKind;
  date: string;
  editorIds: string[];
  title: string;
  subtitle: string;
  detail: string;
  accent: string;
  status?: TaskStatus;
  place?: string;
  category?: string;
  orderTeam?: string;
  urgent?: boolean;
  needsAssign?: boolean;
  shootType?: ShootType;
}

export interface WorkloadDay {
  date: string;
  items: WorkloadItem[];
}

export interface WorkloadEditorSummary {
  editorId: string;
  label: string;
  color: string;
  initial: string;
  total: number;
  shoots: number;
}

export interface EditorBadge {
  initial: string;
  label: string;
  color: string;
}

interface UseWorkloadInput {
  monthValue: string;
  tasks: VideoTask[];
  contentItems: ContentPlanItem[];
  shoots: ShootSchedule[];
  editors: Editor[];
}

export interface WorkloadResult {
  days: Map<string, WorkloadDay>;
  summaries: WorkloadEditorSummary[];
  itemCount: number;
  unassignedCount: number;
}

export function toIsoDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

export function displayDateToIso(value: string | undefined, monthValue: string) {
  if (!value) return null;
  const cleanValue = value.trim();
  if (!cleanValue || cleanValue === '#') return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(cleanValue)) return cleanValue;

  const match = cleanValue.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
  if (!match) return null;

  const fallbackYear = Number(monthValue.slice(0, 4)) || new Date().getFullYear();
  const parsedYear = match[3] ? Number(match[3]) : fallbackYear;
  const year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
  const month = Number(match[2]);
  const day = Number(match[1]);
  const date = new Date(year, month - 1, day);

  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return null;
  }

  return toIsoDate(date);
}

function pushItem(map: Map<string, WorkloadItem[]>, item: WorkloadItem) {
  const bucket = map.get(item.date);
  if (bucket) {
    bucket.push(item);
    return;
  }
  map.set(item.date, [item]);
}

// Thứ tự trong ô ngày: lịch quay và live trước, rồi việc chưa phân công,
// rồi task xếp theo phòng ban order (BRAND, DIGITAL - ADS, ...), cuối cùng là task đã xong.
function sortRank(item: WorkloadItem) {
  if (item.kind === 'shoot') return 0;
  if (item.needsAssign) return 1;
  if (item.status === 'Đã xong') return 90;

  const teamIndex = item.orderTeam ? ORDER_TEAMS.indexOf(item.orderTeam) : -1;
  return 10 + (teamIndex >= 0 ? teamIndex : ORDER_TEAMS.length);
}

export function useWorkload({
  monthValue,
  tasks,
  contentItems,
  shoots,
  editors,
}: UseWorkloadInput): WorkloadResult {
  return useMemo(() => {
    const itemsByDate = new Map<string, WorkloadItem[]>();

    shoots.forEach((shoot) => {
      const meta = SHOOT_TYPES_META[shoot.type];
      const crew = shoot.displayCrew || shoot.crew;
      pushItem(itemsByDate, {
        id: `shoot:${shoot.id}`,
        sourceId: shoot.id,
        kind: 'shoot',
        date: shoot.date,
        editorIds: shoot.editorIds,
        // Chỉ lịch quay mới đọc nội dung trước, địa điểm tách riêng. Live và loại khác giữ nguyên như cũ.
        title: shoot.type === 'lichquay'
          ? shoot.content || shoot.place || meta.label
          : shoot.place || meta.label,
        place: shoot.type === 'lichquay' ? shoot.place : '',
        subtitle: [meta.label, shoot.place, shoot.time].filter(Boolean).join(' · '),
        detail: [crew ? `Crew: ${crew}` : '', shoot.note].filter(Boolean).join(' · '),
        accent: meta.dot,
        shootType: shoot.type,
      });
    });

    tasks.forEach((task) => {
      const airDate = displayDateToIso(task.airDate, monthValue);
      const returnDate = displayDateToIso(task.returnDate, monthValue);
      const sourceId = task.dbId ?? String(task.id);
      const editorIds = task.editorId ? [task.editorId] : [];

      if (airDate) {
        pushItem(itemsByDate, {
          id: `task:${sourceId}`,
          sourceId,
          kind: 'task',
          date: airDate,
          editorIds,
          title: task.name,
          subtitle: [task.status, task.category, task.orderTeam].filter(Boolean).join(' · '),
          detail: returnDate ? `Hạn trả ${task.returnDate}` : '',
          accent: '',
          status: task.status,
          category: task.category,
          orderTeam: task.orderTeam,
          urgent: task.priority === 'Gấp',
          needsAssign: editorIds.length === 0,
        });
      }
    });

    contentItems.forEach((item) => {
      if (item.hasLinkedTask) return;
      const editorIds = item.editor_id ? [item.editor_id] : [];
      pushItem(itemsByDate, {
        id: `plan:${item.id}`,
        sourceId: item.id,
        kind: 'plan',
        date: item.air_date,
        editorIds,
        title: item.video_name,
        subtitle: [item.category, editorIds.length ? 'chưa có task' : 'chưa phân công'].filter(Boolean).join(' · '),
        detail: item.note,
        accent: '',
        category: item.category,
        orderTeam: CONTENT_PLAN_DEFAULT_ORDER_TEAM,
        needsAssign: editorIds.length === 0,
      });
    });

    const days = new Map<string, WorkloadDay>();
    itemsByDate.forEach((items, date) => {
      const sorted = [...items].sort((a, b) => {
        const rankDiff = sortRank(a) - sortRank(b);
        if (rankDiff !== 0) return rankDiff;
        return a.title.localeCompare(b.title, 'vi');
      });
      days.set(date, { date, items: sorted });
    });

    const summaries: WorkloadEditorSummary[] = editors.map((editor) => {
      let total = 0;
      let shootCount = 0;
      days.forEach((day) => {
        day.items.forEach((item) => {
          if (!item.editorIds.includes(editor.id)) return;
          total += 1;
          if (item.kind === 'shoot') shootCount += 1;
        });
      });

      return {
        editorId: editor.id,
        label: editor.short || editor.name,
        color: editor.color,
        initial: editor.initial,
        total,
        shoots: shootCount,
      };
    });

    let itemCount = 0;
    let unassignedCount = 0;
    days.forEach((day) => {
      itemCount += day.items.length;
      day.items.forEach((item) => { if (item.needsAssign) unassignedCount += 1; });
    });

    return { days, summaries, itemCount, unassignedCount };
  }, [contentItems, editors, monthValue, shoots, tasks]);
}

export function editorBadgeMap(entries: Array<{ id: string; initial: string; label: string; color: string }>) {
  const map = new Map<string, EditorBadge>();
  entries.forEach((entry) => map.set(entry.id, { initial: entry.initial, label: entry.label, color: entry.color }));
  return map;
}
