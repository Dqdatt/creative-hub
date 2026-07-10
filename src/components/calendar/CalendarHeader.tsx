import type { ShootType } from '../../types/shoot';
import { SHOOT_TYPES_META } from '../../data/shoots';

interface CalendarHeaderProps {
  filter: ShootType | 'all';
  onToday: () => void;
  onFilterChange: (type: ShootType | 'all') => void;
}

export function CalendarHeader({
  filter,
  onToday,
  onFilterChange,
}: CalendarHeaderProps) {
  const legendItems = [['all', 'Tất cả', '#6B7280'], ...Object.entries(SHOOT_TYPES_META).map(([k, v]) => [k, v.label, v.dot])];

  return (
    <div className="cal-toolbar flex flex-wrap items-center gap-3">
      <button onClick={onToday} className="btn-ghost">Tháng này</button>

      <div id="calLegend" className="cal-legend ml-auto flex flex-wrap items-center gap-2">
        {legendItems.map(([k, label, color]) => {
          const on = k === filter;
          return (
            <button
              key={k}
              onClick={() => onFilterChange(k as ShootType | 'all')}
              className={`cal-legend-btn inline-flex items-center gap-1.5 h-8 px-2.5 rounded-full text-[12px] font-medium border transition ${
                on ? 'bg-ink text-white border-ink shadow-btn' : 'bg-white border-line text-sub'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full" style={{ background: color }}></span>
              {label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
