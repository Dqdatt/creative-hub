import { CalendarDays, Clapperboard, FileText } from 'lucide-react';
import { StyledSelect } from '../common/StyledSelect';
import { CONTENT_PLAN_CATEGORIES } from '../../data/contentPlan';
import { TASK_CATEGORIES, TASK_STATUSES } from '../../data/tasks';
import { SHOOT_TYPES_META } from '../../data/shoots';
import type { ShootType } from '../../types/shoot';
import type { TaskCategory, TaskStatus } from '../../types/task';
import type { ContentPlanCategory } from '../../types/contentPlan';

export type UnifiedCalendarFilter = 'all' | 'task' | 'content' | ShootType;
export type UnifiedCalendarEventSource = 'shoot' | 'task' | 'content';

export interface UnifiedCalendarEvent {
  id: string;
  date: string;
  source: UnifiedCalendarEventSource;
  title: string;
  subtitle: string;
  content: string;
  time: string;
  note: string;
  category?: TaskCategory | ContentPlanCategory;
  status?: TaskStatus;
  shootType?: ShootType;
  color: string;
}

interface UnifiedCalendarProps {
  currentDate: Date;
  events: UnifiedCalendarEvent[];
  filter: UnifiedCalendarFilter;
  categoryFilter: TaskCategory | 'all';
  contentCategoryFilter: ContentPlanCategory | 'all';
  statusFilter: TaskStatus | 'all';
  canCreateShoot: boolean;
  canCreateTask: boolean;
  canCreateContent: boolean;
  selectedDate: string;
  onToday: () => void;
  onFilterChange: (filter: UnifiedCalendarFilter) => void;
  onCategoryFilterChange: (category: TaskCategory | 'all') => void;
  onContentCategoryFilterChange: (category: ContentPlanCategory | 'all') => void;
  onStatusFilterChange: (status: TaskStatus | 'all') => void;
  onDayClick: (date: string) => void;
  onDateSelect: (date: string) => void;
  onEventClick: (event: UnifiedCalendarEvent) => void;
  onCreateTask: (date: string) => void;
  onCreateContent: (date: string) => void;
}

const WEEKDAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

function toIsoDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function getSourceLabel(source: UnifiedCalendarEventSource) {
  if (source === 'shoot') return 'Lịch quay';
  if (source === 'task') return 'Video tháng';
  return 'Content Plan';
}

function SourceIcon({ source }: { source: UnifiedCalendarEventSource }) {
  if (source === 'shoot') return <CalendarDays />;
  if (source === 'task') return <Clapperboard />;
  return <FileText />;
}

function UnifiedCalendarEventButton({
  event,
  onClick,
}: {
  event: UnifiedCalendarEvent;
  onClick: (event: UnifiedCalendarEvent) => void;
}) {
  const detail = event.source === 'shoot'
    ? [event.subtitle, event.time].filter(Boolean).join(' | ')
    : event.source === 'task'
      ? [event.content, event.time].filter(Boolean).join(' | ')
      : [event.subtitle, event.content, event.time].filter(Boolean).join(' | ');

  return (
    <button
      type="button"
      key={event.id}
      className={`cal-ev cal-ev--${event.source}`}
      data-calendar-event-id={event.id}
      onClick={(clickEvent) => {
        clickEvent.stopPropagation();
        onClick(event);
      }}
      style={{
        background: `color-mix(in srgb, ${event.color} 15%, transparent)`,
        borderColor: `color-mix(in srgb, ${event.color} 40%, transparent)`,
      }}
    >
      <span className="cal-ev-top">
        <span className="cal-ev-source" style={{ color: event.color }}>
          <SourceIcon source={event.source} />
          {getSourceLabel(event.source)}
        </span>
        {event.status ? <span className="cal-ev-status">{event.status}</span> : null}
      </span>
      <span className="cal-ev-title" style={{ color: 'var(--text)' }}>{event.title}</span>
      {detail ? <span className="cal-ev-detail">{detail}</span> : null}
    </button>
  );
}

export function UnifiedCalendar({
  currentDate,
  events,
  filter,
  categoryFilter,
  contentCategoryFilter,
  statusFilter,
  canCreateShoot,
  canCreateTask,
  canCreateContent,
  selectedDate,
  onToday,
  onFilterChange,
  onCategoryFilterChange,
  onContentCategoryFilterChange,
  onStatusFilterChange,
  onDayClick,
  onDateSelect,
  onEventClick,
  onCreateTask,
  onCreateContent,
}: UnifiedCalendarProps) {
  const legendItems: Array<[UnifiedCalendarFilter, string, string]> = [
    ['all', 'Tất cả', '#6B7280'],
    ['task', 'Video tháng', 'var(--accent-2)'],
    ['content', 'Content Plan', 'var(--accent)'],
    ...Object.entries(SHOOT_TYPES_META).map(([type, meta]) => [type as ShootType, meta.label, meta.dot] as [UnifiedCalendarFilter, string, string]),
  ];

  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const prevDays = new Date(year, month, 0).getDate();

  const cells: { d: number; out: boolean }[] = [];
  for (let i = 0; i < startDow; i += 1) cells.push({ d: prevDays - startDow + 1 + i, out: true });
  for (let d = 1; d <= daysInMonth; d += 1) cells.push({ d, out: false });
  while (cells.length % 7 !== 0) cells.push({ d: cells.length - (startDow + daysInMonth) + 1, out: true });

  const rowCount = Math.max(1, cells.length / 7);
  const eventsByDate = events.reduce<Record<string, UnifiedCalendarEvent[]>>((acc, event) => {
    acc[event.date] = [...(acc[event.date] ?? []), event];
    return acc;
  }, {});

  return (
    <>
      <div className="cal-toolbar flex flex-wrap items-center gap-3">
        <button onClick={onToday} className="btn-ghost">Tháng này</button>

        <div className="admin-calendar-actions">
          {canCreateTask ? (
            <button type="button" className="btn-ghost" onClick={() => onCreateTask(selectedDate)}>
              <Clapperboard /> Thêm Task
            </button>
          ) : null}
          {canCreateContent ? (
            <button type="button" className="btn-ghost" onClick={() => onCreateContent(selectedDate)}>
              <FileText /> Thêm Content
            </button>
          ) : null}
        </div>

        {filter === 'task' ? (
          <div className="admin-calendar-task-filters">
            <StyledSelect value={categoryFilter} onChange={(event) => onCategoryFilterChange(event.target.value as TaskCategory | 'all')}>
              <option value="all">Tất cả video</option>
              {TASK_CATEGORIES.map((category) => (
                <option key={category} value={category}>{category}</option>
              ))}
            </StyledSelect>

            <StyledSelect value={statusFilter} onChange={(event) => onStatusFilterChange(event.target.value as TaskStatus | 'all')}>
              <option value="all">Tất cả trạng thái</option>
              {TASK_STATUSES.map((status) => (
                <option key={status} value={status}>{status}</option>
              ))}
            </StyledSelect>
          </div>
        ) : null}

        {filter === 'content' ? (
          <div className="admin-calendar-task-filters">
            <StyledSelect value={contentCategoryFilter} onChange={(event) => onContentCategoryFilterChange(event.target.value as ContentPlanCategory | 'all')}>
              <option value="all">Tất cả Content Plan</option>
              {CONTENT_PLAN_CATEGORIES.map((category) => (
                <option key={category} value={category}>{category}</option>
              ))}
            </StyledSelect>
          </div>
        ) : null}

        <div id="calLegend" className="cal-legend ml-auto flex flex-wrap items-center gap-2">
          {legendItems.map(([key, label, color]) => {
            const on = key === filter;
            return (
              <button
                key={key}
                onClick={() => onFilterChange(key)}
                className={`cal-legend-btn inline-flex items-center gap-1.5 h-8 px-2.5 rounded-full text-[12px] font-medium border transition ${
                  on ? 'bg-ink text-white border-ink shadow-btn' : 'bg-white border-line text-sub'
                }`}
              >
                <span className="w-2.5 h-2.5 rounded-full" style={{ background: color }} />
                {label}
              </button>
            );
          })}
        </div>
      </div>

      <div className="calendar-card card">
        <div
          className="calendar-grid-shell"
          style={{ gridTemplateRows: `var(--cal-wd-h) repeat(${rowCount}, minmax(0, 1fr))` }}
        >
          {WEEKDAYS.map((weekday, index) => (
            <div key={weekday} className={`cal-wd ${index >= 5 ? 'wknd' : ''}`}>{weekday}</div>
          ))}
          {cells.map((cell, index) => {
            const cellDate = new Date(year, month, 1 - startDow + index);
            const iso = toIsoDate(cellDate);
            const wknd = index % 7 >= 5;
            const isSun = index % 7 === 6;
            const dayEvents = index < startDow ? [] : eventsByDate[iso] ?? [];
            const cellHighlighted = selectedDate === iso;
            const clickAttr = cell.out || !canCreateShoot ? {} : { onClick: () => onDayClick(iso), style: { cursor: 'pointer' } };
            const borderFix = isSun ? { borderRight: 'none' } : {};

            return (
              <div
                key={iso}
                className={`cal-cell ${cell.out ? 'out' : ''} ${wknd ? 'wknd' : ''} ${cellHighlighted ? 'route-highlight route-highlight--day' : ''}`}
                data-calendar-date={iso}
                aria-current={cellHighlighted ? 'true' : undefined}
                {...clickAttr}
                style={{ ...clickAttr.style, ...borderFix }}
              >
                <div className="cal-day-head">
                  <button
                    type="button"
                    className="cal-daynum"
                    onClick={(event) => {
                      event.stopPropagation();
                      onDateSelect(iso);
                    }}
                  >
                    {cell.d}
                  </button>
                  {dayEvents.length > 0 ? <span className="cal-day-count">{dayEvents.length} mục</span> : null}
                </div>
                <div className="cal-event-list">
                  {dayEvents.map((event) => (
                    <UnifiedCalendarEventButton key={event.id} event={event} onClick={onEventClick} />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </>
  );
}
