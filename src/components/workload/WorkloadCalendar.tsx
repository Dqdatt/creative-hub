import type { EditorBadge, WorkloadDay, WorkloadItem } from '../../hooks/useWorkload';
import { toIsoDate } from '../../hooks/useWorkload';

const WEEKDAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const MAX_BADGES = 3;
// Chiều cao tối thiểu của một hàng tuần: phần đầu ô cộng số việc của ngày bận nhất.
const ROW_BASE_HEIGHT = 18;
const ROW_ITEM_HEIGHT = 20;
const MIN_ROW_HEIGHT = 52;
const MAX_ROW_HEIGHT = 150;

// Rút gọn tên phòng ban order cho vừa ô ngày.
const TEAM_SHORT: Record<string, string> = {
  BRAND: 'BR',
  'DIGITAL - ADS': 'DG',
  ECOM: 'EC',
};

function teamLabel(orderTeam?: string) {
  if (!orderTeam) return '';
  return TEAM_SHORT[orderTeam] ?? orderTeam;
}

function stripDiacritics(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

// Cách viết tắt địa điểm do người dùng chỉ định, không tự suy ra chữ cái.
// Thêm dòng mới vào đây khi có quy ước mới.
const PLACE_SHORT: Array<[string, string]> = [
  ['ba hom', 'BH'],
  ['an suong', 'SR AS'],
];

function shortPlace(place?: string) {
  const clean = place?.trim();
  if (!clean) return '';

  const normalized = stripDiacritics(clean);
  const matched = PLACE_SHORT.find(([needle]) => normalized.includes(needle));
  return matched ? matched[1] : clean;
}

interface ChipTag {
  text: string;
  kind: 'team' | 'place';
}

function chipTag(item: WorkloadItem): ChipTag | null {
  if (item.orderTeam) return { text: teamLabel(item.orderTeam), kind: 'team' };
  if (item.place && item.place !== item.title) return { text: shortPlace(item.place), kind: 'place' };
  return null;
}

interface WorkloadCalendarProps {
  currentDate: Date;
  days: Map<string, WorkloadDay>;
  badges: Map<string, EditorBadge>;
  todayIso: string;
  onOpenItem: (item: WorkloadItem) => void;
}

function chipClassName(item: WorkloadItem) {
  const classes = ['wl-chip'];
  if (item.kind === 'shoot') classes.push('wl-chip--shoot');
  if (item.kind === 'plan') classes.push('wl-chip--plan');
  if (item.needsAssign) classes.push('wl-chip--unassigned');
  if (item.status === 'Đã xong') classes.push('wl-chip--done');
  if (item.urgent && item.status !== 'Đã xong') classes.push('wl-chip--urgent');
  return classes.join(' ');
}

export function WorkloadCalendar({
  currentDate,
  days,
  badges,
  todayIso,
  onOpenItem,
}: WorkloadCalendarProps) {
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const prevDays = new Date(year, month, 0).getDate();

  const cells: { label: number; out: boolean }[] = [];
  for (let index = 0; index < startDow; index += 1) {
    cells.push({ label: prevDays - startDow + 1 + index, out: true });
  }
  for (let day = 1; day <= daysInMonth; day += 1) {
    cells.push({ label: day, out: false });
  }
  while (cells.length % 7 !== 0) {
    cells.push({ label: cells.length - (startDow + daysInMonth) + 1, out: true });
  }

  const rowCount = Math.max(1, cells.length / 7);

  // Mỗi hàng tuần được cấp đủ chỗ cho ngày bận nhất của nó, phần dư còn lại chia theo tỉ lệ
  // để không hàng nào bị cắt sát. Ngày nào vượt cả mức trần thì ô đó tự cuộn như cũ.
  const rowTemplate = Array.from({ length: rowCount }, (_, week) => {
    let busiestDay = 0;

    for (let column = 0; column < 7; column += 1) {
      const cell = cells[week * 7 + column];
      if (!cell || cell.out) continue;
      const cellDate = new Date(year, month, 1 - startDow + week * 7 + column);
      const count = days.get(toIsoDate(cellDate))?.items.length ?? 0;
      if (count > busiestDay) busiestDay = count;
    }

    const needed = Math.min(
      Math.max(ROW_BASE_HEIGHT + busiestDay * ROW_ITEM_HEIGHT, MIN_ROW_HEIGHT),
      MAX_ROW_HEIGHT,
    );

    return `minmax(${needed}px, ${needed}fr)`;
  }).join(' ');

  return (
    <div className="calendar-card card">
      <div
        className="calendar-grid-shell"
        style={{ gridTemplateRows: `var(--cal-wd-h) ${rowTemplate}` }}
      >
        {WEEKDAYS.map((weekday, index) => (
          <div key={weekday} className={`cal-wd ${index >= 5 ? 'wknd' : ''}`}>{weekday}</div>
        ))}

        {cells.map((cell, index) => {
          const cellDate = new Date(year, month, 1 - startDow + index);
          const iso = toIsoDate(cellDate);
          const weekend = index % 7 >= 5;
          const items = cell.out ? [] : days.get(iso)?.items ?? [];

          return (
            <div
              key={iso}
              className={[
                'cal-cell wl-cell',
                cell.out ? 'out' : '',
                weekend ? 'wknd' : '',
                iso === todayIso ? 'wl-cell--today' : '',
              ].filter(Boolean).join(' ')}
              data-calendar-date={iso}
            >
              <div className="cal-day-head wl-day-head">
                <span className="cal-daynum">{cell.label}</span>
              </div>

              <div className="cal-event-list wl-list">
                {items.map((item) => {
                  const owners = item.editorIds
                    .map((editorId) => badges.get(editorId))
                    .filter((badge): badge is EditorBadge => Boolean(badge));
                  const tag = chipTag(item);

                  return (
                    <button
                      key={item.id}
                      type="button"
                      className={chipClassName(item)}
                      style={{ ['--wl-kind' as string]: item.accent || 'var(--border-strong)' }}
                      title={[item.title, item.subtitle, item.detail].filter(Boolean).join(' · ')}
                      onClick={() => onOpenItem(item)}
                    >
                      <span className="wl-chip-who">
                        {owners.length ? (
                          owners.slice(0, MAX_BADGES).map((owner, ownerIndex) => (
                            <span
                              key={`${item.id}-${owner.initial}-${ownerIndex}`}
                              className="wl-ava"
                              style={{ background: owner.color }}
                            >
                              {owner.initial}
                            </span>
                          ))
                        ) : (
                          <span className="wl-ava wl-ava--none">?</span>
                        )}
                      </span>
                      {tag && tag.kind === 'team' ? (
                        <span className="wl-chip-team">{tag.text}</span>
                      ) : null}
                      <span className="wl-chip-text">{item.title}</span>
                      {tag && tag.kind === 'place' ? (
                        <span className="wl-chip-at">{tag.text}</span>
                      ) : null}
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
