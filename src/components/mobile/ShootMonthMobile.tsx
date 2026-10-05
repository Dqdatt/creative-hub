import { useState } from 'react';
import type { MouseEvent } from 'react';
import { Clock3, MapPin, Plus } from 'lucide-react';
import { SHOOT_TYPES_META } from '../../data/shoots';
import type { ShootSchedule, ShootType } from '../../types/shoot';
import { toIsoDate } from '../../hooks/useWorkload';

const WEEKDAY = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const WEEKDAY_LONG = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

interface ShootMonthMobileProps {
  currentDate: Date;
  shoots: ShootSchedule[];
  filter: ShootType | 'all';
  onDayClick: (dateStr: string) => void;
  onShootClick: (shoot: ShootSchedule, event: MouseEvent) => void;
  canCreateShoot?: boolean;
  highlightedShootId?: string | null;
  highlightedDate?: string | null;
}

// Lịch quay dạng tháng gọn cho mobile: lưới ngày có chấm màu + danh sách lịch của ngày chọn.
export function ShootMonthMobile({
  currentDate,
  shoots,
  filter,
  onDayClick,
  onShootClick,
  canCreateShoot = false,
  highlightedShootId = null,
  highlightedDate = null,
}: ShootMonthMobileProps) {
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const monthKey = `${year}-${month}`;
  const todayIso = toIsoDate(new Date());
  const monthPrefix = `${year}-${String(month + 1).padStart(2, '0')}`;
  const [picked, setPicked] = useState<{ month: string; iso: string } | null>(null);
  const highlightedShootDate = highlightedShootId ? shoots.find((shoot) => shoot.id === highlightedShootId)?.date : undefined;
  const focusDate = highlightedShootDate ?? highlightedDate;
  const fallbackIso = focusDate?.startsWith(monthPrefix)
    ? focusDate
    : todayIso.startsWith(monthPrefix) ? todayIso : `${monthPrefix}-01`;
  const selectedIso = picked?.month === monthKey ? picked.iso : fallbackIso;

  const visible = shoots.filter((shoot) => filter === 'all' || shoot.type === filter);
  const byDate = new Map<string, ShootSchedule[]>();
  visible.forEach((shoot) => byDate.set(shoot.date, [...(byDate.get(shoot.date) ?? []), shoot]));

  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells: Array<{ iso: string; day: number } | null> = [];
  for (let index = 0; index < startDow; index += 1) cells.push(null);
  for (let day = 1; day <= daysInMonth; day += 1) cells.push({ iso: toIsoDate(new Date(year, month, day)), day });
  while (cells.length % 7 !== 0) cells.push(null);

  const [sy, sm, sd] = selectedIso.split('-').map(Number);
  const selectedDate = new Date(sy, sm - 1, sd);
  const dayShoots = byDate.get(selectedIso) ?? [];

  return (
    <div className="m-stack">
      <div className="m-card m-month-grid">
        {WEEKDAY.map((label, index) => (
          <span key={label} className={`m-month-wd ${index >= 5 ? 'is-weekend' : ''}`}>{label}</span>
        ))}
        {cells.map((cell, index) => {
          if (!cell) return <span key={`empty-${index}`} aria-hidden="true" />;
          const events = byDate.get(cell.iso) ?? [];
          return (
            <button
              key={cell.iso}
              type="button"
              className={[
                'm-month-day',
                cell.iso === selectedIso ? 'is-active' : '',
                cell.iso === todayIso ? 'is-today' : '',
                index % 7 >= 5 ? 'is-weekend' : '',
              ].filter(Boolean).join(' ')}
              aria-pressed={cell.iso === selectedIso}
              aria-label={`Ngày ${cell.day}, ${events.length} lịch`}
              data-calendar-date={cell.iso}
              onClick={() => setPicked({ month: monthKey, iso: cell.iso })}
            >
              <span>{cell.day}</span>
              <span className="m-dots">
                {events.slice(0, 3).map((shoot) => (
                  <i key={shoot.id} style={{ background: SHOOT_TYPES_META[shoot.type]?.dot }} />
                ))}
              </span>
            </button>
          );
        })}
      </div>

      <div className="m-day-head">
        <h2>{WEEKDAY_LONG[selectedDate.getDay()]}, {String(sd).padStart(2, '0')}/{String(sm).padStart(2, '0')}</h2>
        <span className="m-muted">{dayShoots.length} lịch</span>
        {canCreateShoot ? (
          <button type="button" className="m-chip" onClick={() => onDayClick(selectedIso)}>
            <Plus aria-hidden="true" /> Thêm
          </button>
        ) : null}
      </div>

      {dayShoots.length === 0 ? (
        <div className="m-card m-empty"><b>Không có lịch quay trong ngày này</b></div>
      ) : (
        <div className="m-cards">
          {dayShoots.map((shoot) => {
            const meta = SHOOT_TYPES_META[shoot.type];
            const crew = shoot.displayCrew || shoot.crew;
            return (
              <button
                key={shoot.id}
                type="button"
                className={`m-card m-wl-item ${highlightedShootId === shoot.id ? 'route-highlight' : ''}`}
                data-shoot-id={shoot.id}
                onClick={(event) => onShootClick(shoot, event)}
              >
                <span className="m-wl-top">
                  <span className={`m-kind m-kind--${shoot.type}`}>{meta?.label ?? 'Lịch quay'}</span>
                  <span className="m-wl-sub m-inline-icon"><Clock3 aria-hidden="true" />{shoot.time || 'Cả ngày'}</span>
                </span>
                <span className="m-wl-title m-inline-icon"><MapPin aria-hidden="true" />{shoot.place || meta?.label}</span>
                {shoot.content ? <span className="m-wl-sub">{shoot.content}</span> : null}
                <span className="m-wl-sub">{crew || 'Chưa có crew'}</span>
                {shoot.note ? <span className="m-wl-sub">{shoot.note}</span> : null}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
