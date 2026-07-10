import type { ShootSchedule, ShootType } from '../../types/shoot';
import { SHOOT_TYPES_META } from '../../data/shoots';

interface CalendarGridProps {
  currentDate: Date;
  shoots: ShootSchedule[];
  filter: ShootType | 'all';
  onDayClick: (dateStr: string) => void;
  onShootClick: (shoot: ShootSchedule, e: React.MouseEvent) => void;
  canCreateShoot?: boolean;
}

export function CalendarGrid({
  currentDate,
  shoots,
  filter,
  onDayClick,
  onShootClick,
  canCreateShoot = true,
}: CalendarGridProps) {
  const WD = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  
  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7; 
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const prevDays = new Date(year, month, 0).getDate();

  const cells: { d: number; out: boolean }[] = [];
  for (let i = 0; i < startDow; i++) cells.push({ d: prevDays - startDow + 1 + i, out: true });
  for (let d = 1; d <= daysInMonth; d++) cells.push({ d, out: false });
  while (cells.length % 7 !== 0) cells.push({ d: cells.length - (startDow + daysInMonth) + 1, out: true });
  const rowCount = Math.max(1, cells.length / 7);

  return (
    <div
      className="calendar-grid-shell"
      style={{ gridTemplateRows: `var(--cal-wd-h) repeat(${rowCount}, minmax(0, 1fr))` }}
    >
      {WD.map((w, i) => (
        <div key={w} className={`cal-wd ${i >= 5 ? 'wknd' : ''}`}>{w}</div>
      ))}
      {cells.map((c, idx) => {
        const cellDate = new Date(year, month, 1 - startDow + idx);
        const iso = `${cellDate.getFullYear()}-${String(cellDate.getMonth() + 1).padStart(2, '0')}-${String(cellDate.getDate()).padStart(2, '0')}`;
        const isSun = idx % 7 === 6;
        const wknd = idx % 7 >= 5;
        const events = idx < startDow ? [] : shoots.filter((s) => s.date === iso && (filter === 'all' || s.type === filter));
        const visibleEvents = events.slice(0, 2);
        const hiddenCount = Math.max(0, events.length - visibleEvents.length);

        const clickAttr = c.out || !canCreateShoot ? {} : { onClick: () => onDayClick(iso), style: { cursor: 'pointer' } };
        const borderFix = isSun ? { borderRight: 'none' } : {};
        
        return (
          <div 
            key={idx} 
            className={`cal-cell ${c.out ? 'out' : ''} ${wknd ? 'wknd' : ''}`}
            {...clickAttr}
            style={{ ...clickAttr.style, ...borderFix }}
          >
            <div className="cal-daynum">{c.d}</div>
            <div className="cal-event-list">
              {visibleEvents.map((ev) => {
                const t = SHOOT_TYPES_META[ev.type];
                return (
                  <div 
                    key={ev.id}
                    className="cal-ev"
                    onClick={(e) => onShootClick(ev, e)}
                    style={{ cursor: 'pointer', background: `color-mix(in srgb, ${t.dot} 15%, transparent)`, borderColor: `color-mix(in srgb, ${t.dot} 40%, transparent)` }}
                  >
                    {ev.displayCrew && <div className="font-bold" style={{ color: 'var(--text)' }}>{ev.displayCrew}</div>}
                    <div className="font-semibold" style={{ color: 'var(--text)' }}>{ev.place}</div>
                    {ev.time && <div className="font-medium text-sub">{ev.time}</div>}
                    {ev.note && <div className="font-semibold mt-1" style={{ color: 'var(--danger)' }}>{ev.note}</div>}
                  </div>
                );
              })}
              {hiddenCount > 0 ? (
                <button
                  type="button"
                  className="cal-more"
                  onClick={(e) => {
                    e.stopPropagation();
                    if (events[2]) onShootClick(events[2], e);
                  }}
                >
                  +{hiddenCount} lịch
                </button>
              ) : null}
            </div>
          </div>
        );
      })}
    </div>
  );
}
