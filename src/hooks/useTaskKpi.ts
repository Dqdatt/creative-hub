import { useMemo } from 'react';
import { ORDER_TEAMS } from '../data/tasks';
import { CONTENT_PLAN_CATEGORIES } from '../data/contentPlan';
import type { ContentPlanEditorOption, ContentPlanItem } from '../types/contentPlan';
import type { Editor } from '../types/task';
import type { BrandKpi, BrandKpiRow } from './useDashboard';
import { getTodayIso } from '../utils/month';
import { isSafeHttpUrl } from '../utils/url';

// v2.0.0 - Luật KPI:
// - Task thuộc tháng theo ngày Air: từ ngày 1 đến ngày cuối tháng (30/31).
// - Task chỉ được tính hoàn thành khi có link thành phẩm hợp lệ.
// - Có editor mà chưa có link = đang làm; chưa có editor = chưa có người nhận.
// - Quá hạn = ngày Air đã qua mà chưa có link.

export interface KpiCount {
  total: number;
  done: number;
  doing: number;
  open: number;
  overdue: number;
  longVideos: number;
  motion: number;
  rate: number;
}

export interface KpiRow extends KpiCount {
  key: string;
  label: string;
  editor?: ContentPlanEditorOption | null;
  share: number;
}

export interface TaskKpi {
  summary: KpiCount;
  byCategory: KpiRow[];
  byOrder: KpiRow[];
  byEditor: KpiRow[];
  brandKpi: BrandKpi;
}

const NO_EDITOR_KEY = '__none__';

export function isTaskDone(item: ContentPlanItem) {
  return isSafeHttpUrl(item.link.trim());
}

function rate(part: number, total: number) {
  return total ? Math.round((part / total) * 100) : 0;
}

function count(items: ContentPlanItem[], todayIso: string): KpiCount {
  const done = items.filter(isTaskDone);
  const notDone = items.filter((item) => !isTaskDone(item));
  return {
    total: items.length,
    done: done.length,
    doing: notDone.filter((item) => item.editor_id).length,
    open: notDone.filter((item) => !item.editor_id).length,
    overdue: notDone.filter((item) => item.air_date < todayIso).length,
    longVideos: items.filter((item) => item.category === 'Video dài').length,
    motion: items.filter((item) => item.category === 'Motion').length,
    rate: rate(done.length, items.length),
  };
}

function toEditor(option: ContentPlanEditorOption): Editor {
  return {
    id: option.id,
    profileId: option.profile_id,
    name: option.name,
    short: option.short,
    role: option.role,
    color: option.color,
    bgColor: option.bgColor,
    initial: option.initial,
    avatarUrl: option.avatarUrl,
    crewKey: option.id,
  };
}

export function useTaskKpi(
  items: ContentPlanItem[],
  editorOptions: ContentPlanEditorOption[],
  monthValue: string
): TaskKpi {
  return useMemo(() => {
    const todayIso = getTodayIso();
    const monthItems = items.filter((item) => item.air_date.startsWith(monthValue));
    const summary = count(monthItems, todayIso);

    const row = (key: string, label: string, rowItems: ContentPlanItem[], editor?: ContentPlanEditorOption | null): KpiRow => ({
      key,
      label,
      editor,
      share: rate(rowItems.length, monthItems.length),
      ...count(rowItems, todayIso),
    });

    const extraCategories = Array.from(new Set(monthItems.map((item) => item.category)))
      .filter((category) => !CONTENT_PLAN_CATEGORIES.includes(category));
    const byCategory = [...CONTENT_PLAN_CATEGORIES, ...extraCategories]
      .map((category) => row(category, category, monthItems.filter((item) => item.category === category)))
      .filter((entry) => entry.total > 0 || CONTENT_PLAN_CATEGORIES.includes(entry.key as never));

    const byOrder = ORDER_TEAMS
      .map((team) => row(team, team, monthItems.filter((item) => item.order_team === team)))
      .filter((entry) => entry.total > 0)
      .sort((a, b) => b.total - a.total);

    const byEditor = editorOptions
      .map((editor) => row(editor.id, editor.short, monthItems.filter((item) => item.editor_id === editor.id), editor))
      .filter((entry) => entry.total > 0)
      .sort((a, b) => b.done - a.done || b.total - a.total);
    const unassigned = monthItems.filter((item) => !item.editor_id || !editorOptions.some((editor) => editor.id === item.editor_id));
    if (unassigned.length) byEditor.push(row(NO_EDITOR_KEY, 'Chưa có người nhận', unassigned, null));

    // KPI BRAND: chỉ đếm task BRAND đã có link thành phẩm.
    const brandDone = monthItems.filter((item) => item.order_team === 'BRAND' && isTaskDone(item));
    const brandRow = (key: string, label: string, editor: Editor | null, rowItems: ContentPlanItem[]): BrandKpiRow => ({
      key,
      label,
      editor,
      longVideos: rowItems.filter((item) => item.category === 'Video dài').length,
      motion: rowItems.filter((item) => item.category === 'Motion').length,
      total: rowItems.length,
      share: rate(rowItems.length, brandDone.length),
    });
    const brandRows = editorOptions.map((editor) =>
      brandRow(editor.id, editor.short, toEditor(editor), brandDone.filter((item) => item.editor_id === editor.id))
    );
    const brandUnassigned = brandDone.filter((item) => !editorOptions.some((editor) => editor.id === item.editor_id));
    if (brandUnassigned.length) brandRows.push(brandRow(NO_EDITOR_KEY, 'Chưa có editor', null, brandUnassigned));

    return {
      summary,
      byCategory,
      byOrder,
      byEditor,
      brandKpi: {
        team: 'BRAND',
        rows: brandRows,
        longVideos: brandDone.filter((item) => item.category === 'Video dài').length,
        motion: brandDone.filter((item) => item.category === 'Motion').length,
        total: brandDone.length,
      },
    };
  }, [editorOptions, items, monthValue]);
}
