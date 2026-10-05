import { useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, Plus, Zap } from 'lucide-react';
import { SHOOT_TYPES_META } from '../../data/shoots';
import type { EditorBadge, WorkloadDay, WorkloadItem } from '../../hooks/useWorkload';
import { toIsoDate } from '../../hooks/useWorkload';
import { StatusBadge } from '../tasks/TaskBadges';

const WEEKDAY = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const WEEKDAY_LONG = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
const MAX_DOTS = 3;

function kindLabel(item: WorkloadItem) {
  if (item.kind === 'task') return { label: 'Task', tone: 'task' };
  if (item.kind === 'plan') return { label: 'Content', tone: 'plan' };
  const type = item.shootType ?? 'other';
  return { label: SHOOT_TYPES_META[type]?.label ?? 'Lịch quay', tone: type };
}

function mondayOf(date: Date) {
  const copy = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  copy.setDate(copy.getDate() - ((copy.getDay() + 6) % 7));
  return copy;
}

interface WorkloadAgendaProps {
  currentDate: Date;
  days: Map<string, WorkloadDay>;
  badges: Map<string, EditorBadge>;
  todayIso: string;
  onOpenItem: (item: WorkloadItem) => void;
  canCreateShoot?: boolean;
  onDayClick?: (date: string) => void;
}

// Workload dạng tuần cho mobile: dải 7 ngày + danh sách việc của ngày đang chọn.
export function WorkloadAgenda({
  currentDate,
  days,
  badges,
  todayIso,
  onOpenItem,
  canCreateShoot = false,
  onDayClick,
}: WorkloadAgendaProps) {
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const firstOfMonth = new Date(year, month, 1);
  const lastOfMonth = new Date(year, month + 1, 0);
  const todayInMonth = todayIso.startsWith(`${year}-${String(month + 1).padStart(2, '0')}`);
  const [picked, setPicked] = useState<{ month: string; iso: string } | null>(null);
  const monthKey = `${year}-${month}`;
  const selectedIso = picked?.month === monthKey ? picked.iso : todayInMonth ? todayIso : toIsoDate(firstOfMonth);
  const [y, m, d] = selectedIso.split('-').map(Number);
  const selectedDate = new Date(y, m - 1, d);
  const weekStart = mondayOf(selectedDate);

  const week = useMemo(() => Array.from({ length: 7 }, (_, index) => {
    const date = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + index);
    const iso = toIsoDate(date);
    return { date, iso, inMonth: date.getMonth() === month, count: days.get(iso)?.items.length ?? 0 };
  }), [days, month, weekStart]);

  const pick = (iso: string) => setPicked({ month: monthKey, iso });
  const shiftWeek = (delta: number) => {
    const next = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + delta * 7);
    const clamped = next < firstOfMonth ? firstOfMonth : next > lastOfMonth ? lastOfMonth : next;
    pick(toIsoDate(clamped));
  };

  const items = days.get(selectedIso)?.items ?? [];
  const weekLabel = `${String(week[0].date.getDate()).padStart(2, '0')}/${String(week[0].date.getMonth() + 1).padStart(2, '0')} – ${String(week[6].date.getDate()).padStart(2, '0')}/${String(week[6].date.getMonth() + 1).padStart(2, '0')}`;

  return (
    <div className="m-stack">
      <div className="m-week-nav">
        <button type="button" className="m-circle m-circle--sm" aria-label="Tuần trước" onClick={() => shiftWeek(-1)} disabled={weekStart <= firstOfMonth}>
          <ChevronLeft />
        </button>
        <b>Tuần {weekLabel}</b>
        <button type="button" className="m-circle m-circle--sm" aria-label="Tuần sau" onClick={() => shiftWeek(1)} disabled={week[6].date >= lastOfMonth}>
          <ChevronRight />
        </button>
      </div>

      <div className="m-week" role="group" aria-label="Chọn ngày">
        {week.map((day, index) => (
          <button
            key={day.iso}
            type="button"
            className={[
              'm-week-day',
              day.iso === selectedIso ? 'is-active' : '',
              day.iso === todayIso ? 'is-today' : '',
              index >= 5 ? 'is-weekend' : '',
            ].filter(Boolean).join(' ')}
            aria-pressed={day.iso === selectedIso}
            aria-label={`${WEEKDAY[index]} ${day.date.getDate()}/${day.date.getMonth() + 1}, ${day.count} việc`}
            disabled={!day.inMonth}
            onClick={() => pick(day.iso)}
          >
            <span className="m-week-wd">{WEEKDAY[index]}</span>
            <span className="m-week-num">{day.date.getDate()}</span>
            <span className="m-dots">
              {Array.from({ length: Math.min(day.count, MAX_DOTS) }, (_, dot) => <i key={dot} />)}
            </span>
          </button>
        ))}
      </div>

      <div className="m-day-head">
        <h2>{WEEKDAY_LONG[selectedDate.getDay()]}, {String(selectedDate.getDate()).padStart(2, '0')}/{String(selectedDate.getMonth() + 1).padStart(2, '0')}</h2>
        <span className="m-muted">{items.length} việc</span>
        {canCreateShoot && onDayClick ? (
          <button type="button" className="m-chip" onClick={() => onDayClick(selectedIso)}>
            <Plus aria-hidden="true" /> Lịch quay
          </button>
        ) : null}
      </div>

      {items.length === 0 ? (
        <div className="m-card m-empty"><b>Không có việc trong ngày</b><span>Chọn ngày khác hoặc bấm + để thêm.</span></div>
      ) : (
        <div className="m-cards">
          {items.map((item) => {
            const kind = kindLabel(item);
            const owners = item.editorIds
              .map((editorId) => badges.get(editorId))
              .filter((badge): badge is EditorBadge => Boolean(badge));
            return (
              <button key={item.id} type="button" className={`m-card m-wl-item ${item.status === 'Đã xong' ? 'is-done' : ''}`} onClick={() => onOpenItem(item)}>
                <span className="m-wl-top">
                  <span className={`m-kind m-kind--${kind.tone}`}>{kind.label}</span>
                  {item.status ? <StatusBadge status={item.status} /> : null}
                  {item.urgent && item.status !== 'Đã xong' ? <span className="m-urgent"><Zap aria-hidden="true" />Gấp</span> : null}
                  <span className="m-flex" />
                  {owners.length ? (
                    <span className="m-owners">
                      {owners.slice(0, 3).map((owner, index) => (
                        <span key={`${item.id}-${index}`} className="m-owner" style={{ background: owner.color }} title={owner.label}>{owner.initial}</span>
                      ))}
                    </span>
                  ) : item.needsAssign ? <span className="m-pill-warn">Cần phân công</span> : null}
                </span>
                <span className="m-wl-title">{item.title}</span>
                {item.subtitle ? <span className="m-wl-sub">{item.subtitle}</span> : null}
                {item.detail ? <span className="m-wl-sub">{item.detail}</span> : null}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
