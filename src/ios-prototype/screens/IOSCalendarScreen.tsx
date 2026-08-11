import { useState } from 'react';
import { ChevronLeft, ChevronRight, MapPin, Clock, Users, Plus, AlertCircle } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { MOCK_SHOOTS, SHOOT_TYPES_META } from '../../data/shoots';

interface Props { state: IOSStateReturn }

const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const MONTH_NAMES = ['', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'];

function buildCalendarDays(year: number, month: number) {
  const firstDay = new Date(year, month - 1, 1).getDay(); // 0=Sun
  const daysInMonth = new Date(year, month, 0).getDate();
  const daysInPrevMonth = new Date(year, month - 1, 0).getDate();

  const cells: Array<{ day: number; month: 'current' | 'prev' | 'next' }> = [];

  // prev month fill
  for (let i = firstDay - 1; i >= 0; i--) {
    cells.push({ day: daysInPrevMonth - i, month: 'prev' });
  }
  // current month
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ day: d, month: 'current' });
  }
  // next month fill
  const remaining = 42 - cells.length;
  for (let d = 1; d <= remaining; d++) {
    cells.push({ day: d, month: 'next' });
  }

  return cells;
}

export function IOSCalendarScreen({ state }: Props) {
  const { prototypeMode, openSheet } = state;
  const [viewYear, setViewYear] = useState(2026);
  const [viewMonth, setViewMonth] = useState(7);
  const [selectedDay, setSelectedDay] = useState(7);

  if (prototypeMode === 'loading') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 0', gap: 12 }}>
        <div style={{ width: 32, height: 32, border: '3px solid #7C5CFF', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <p style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>Đang tải lịch quay...</p>
      </div>
    );
  }

  if (prototypeMode === 'error') {
    return (
      <div style={{ margin: '16px 18px', padding: '24px 16px', background: '#FFF0F0', borderRadius: 20, textAlign: 'center' }}>
        <AlertCircle width={36} height={36} color="#EF4444" style={{ margin: '0 auto 10px' }} />
        <p style={{ fontSize: 13, fontWeight: 700, color: '#EF4444' }}>Không thể tải lịch quay</p>
        <button onClick={() => state.setPrototypeMode('default')} className="ios-primary-btn" style={{ width: 'auto', padding: '10px 20px', borderRadius: 12, fontSize: 13, marginTop: 12 }}>
          Thử lại
        </button>
      </div>
    );
  }

  const calCells = buildCalendarDays(viewYear, viewMonth);
  const today = new Date();
  const isCurrentMonth = today.getFullYear() === viewYear && today.getMonth() + 1 === viewMonth;
  const todayDay = today.getDate();

  const daysWithShoots = new Set(
    MOCK_SHOOTS
      .filter(s => {
        const [y, m] = s.date.split('-').map(Number);
        return y === viewYear && m === viewMonth;
      })
      .map(s => parseInt(s.date.split('-')[2], 10))
  );

  const shootsForSelected = MOCK_SHOOTS.filter(s => {
    const [y, m, d] = s.date.split('-').map(Number);
    return y === viewYear && m === viewMonth && d === selectedDay;
  });

  const goToPrev = () => {
    if (viewMonth === 1) { setViewMonth(12); setViewYear(y => y - 1); }
    else setViewMonth(m => m - 1);
    setSelectedDay(1);
  };
  const goToNext = () => {
    if (viewMonth === 12) { setViewMonth(1); setViewYear(y => y + 1); }
    else setViewMonth(m => m + 1);
    setSelectedDay(1);
  };

  return (
    <div className="ios-screen-enter">
      {/* Month Navigation */}
      <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={goToPrev} className="ios-cal-nav-btn">
          <ChevronLeft width={16} height={16} />
        </button>
        <span style={{ fontSize: 19, fontWeight: 800, color: '#111', letterSpacing: -0.3, transition: 'color 0.3s' }}>
          {MONTH_NAMES[viewMonth]}, {viewYear}
        </span>
        <button onClick={goToNext} className="ios-cal-nav-btn">
          <ChevronRight width={16} height={16} />
        </button>
      </div>

      {/* Full Month Grid */}
      <div style={{ background: '#fff', borderRadius: 20, margin: '0 18px', padding: '14px', boxShadow: '0 2px 14px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.04)' }}>
        {/* Weekday headers */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', marginBottom: 6 }}>
          {WEEKDAYS.map(wd => (
            <div key={wd} style={{ textAlign: 'center', fontSize: 11, fontWeight: 700, color: wd === 'CN' ? '#EF4444' : '#9AA0B2', padding: '2px 0' }}>
              {wd}
            </div>
          ))}
        </div>

        {/* Day cells */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '2px 0' }}>
          {calCells.map((cell, idx) => {
            const isOther = cell.month !== 'current';
            const isSel = cell.month === 'current' && cell.day === selectedDay;
            const isToday = isCurrentMonth && cell.month === 'current' && cell.day === todayDay;
            const hasShoot = cell.month === 'current' && daysWithShoots.has(cell.day);

            return (
              <div
                key={idx}
                onClick={() => { if (!isOther) { setSelectedDay(cell.day); } }}
                className={[
                  'ios-cal-day',
                  isOther ? 'other-month' : '',
                  isSel ? 'selected' : '',
                  isToday && !isSel ? 'today' : '',
                  hasShoot && !isSel ? 'has-event' : '',
                  isSel && hasShoot ? 'selected has-event' : '',
                ].filter(Boolean).join(' ')}
                style={{ fontSize: 14 }}
              >
                {cell.day}
              </div>
            );
          })}
        </div>
      </div>

      {/* Legend */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '10px 18px 6px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#F59E0B', display: 'inline-block' }} />
          <span style={{ fontSize: 11, color: '#9AA0B2', fontWeight: 600 }}>Livestream</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#7C5CFF', display: 'inline-block' }} />
          <span style={{ fontSize: 11, color: '#9AA0B2', fontWeight: 600 }}>Lịch quay</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#3B82F6', display: 'inline-block' }} />
          <span style={{ fontSize: 11, color: '#9AA0B2', fontWeight: 600 }}>On Set</span>
        </div>
      </div>

      {/* Agenda Section */}
      <div style={{ padding: '8px 18px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <h3 style={{ fontSize: 16, fontWeight: 800, color: '#111', margin: 0, transition: 'color 0.3s' }}>
            Ngày {selectedDay}/{String(viewMonth).padStart(2, '0')}
          </h3>
          <button
            onClick={() => openSheet('shoot_create')}
            style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12.5, fontWeight: 700, color: '#fff', background: '#7C5CFF', border: 'none', borderRadius: 10, padding: '6px 12px', cursor: 'pointer', boxShadow: '0 3px 10px rgba(124,92,255,0.3)' }}
          >
            <Plus width={13} height={13} />
            Thêm lịch
          </button>
        </div>

        {shootsForSelected.length === 0 ? (
          <div style={{ background: '#fff', borderRadius: 18, padding: '28px 16px', textAlign: 'center', boxShadow: '0 2px 12px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.04)' }}>
            <p style={{ fontSize: 14, fontWeight: 700, color: '#111', margin: '0 0 6px', transition: 'color 0.3s' }}>
              Không có lịch quay ngày {selectedDay}
            </p>
            <p style={{ fontSize: 12, color: '#9AA0B2', margin: '0 0 14px' }}>Nhấn "Thêm lịch" để tạo lịch quay mới.</p>
            <button
              onClick={() => openSheet('shoot_create')}
              style={{ fontSize: 13, fontWeight: 700, color: '#7C5CFF', background: 'rgba(124,92,255,0.08)', border: 'none', borderRadius: 10, padding: '8px 16px', cursor: 'pointer' }}
            >
              + Tạo lịch ngày {selectedDay}/{viewMonth}
            </button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {shootsForSelected.map((shoot) => {
              const meta = SHOOT_TYPES_META[shoot.type] || SHOOT_TYPES_META.other;
              return (
                <div
                  key={shoot.id}
                  onClick={() => openSheet('shoot_detail', shoot.id)}
                  style={{ background: '#fff', borderRadius: 18, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.05)', cursor: 'pointer', transition: 'all 0.15s' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                    <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 10px', borderRadius: 8, color: '#fff', background: meta.dot }}>
                      {meta.label}
                    </span>
                    {shoot.time && (
                      <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>
                        <Clock width={12} height={12} color="#7C5CFF" />
                        {shoot.time}
                      </span>
                    )}
                  </div>

                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8, marginBottom: 8 }}>
                    <MapPin width={14} height={14} color="#EF4444" style={{ flexShrink: 0, marginTop: 1 }} />
                    <span style={{ fontSize: 13, fontWeight: 700, color: '#111', lineHeight: 1.3, transition: 'color 0.3s' }}>{shoot.place}</span>
                  </div>

                  {shoot.crew && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: '#9AA0B2', fontWeight: 500, paddingTop: 8, borderTop: '1px solid rgba(0,0,0,0.05)' }}>
                      <Users width={13} height={13} color="#3B82F6" />
                      <span>Nhân sự:</span>
                      <span style={{ fontWeight: 700, color: '#555', transition: 'color 0.3s' }}>{shoot.crew}</span>
                    </div>
                  )}

                  {shoot.note && (
                    <div style={{ marginTop: 8, padding: '8px 10px', background: '#F8F9FB', borderRadius: 10, fontSize: 11.5, color: '#9AA0B2', fontStyle: 'italic' }}>
                      "{shoot.note}"
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
