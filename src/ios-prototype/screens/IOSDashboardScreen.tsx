import { CheckCircle2, Clock, PlayCircle, Video, Calendar, TrendingUp, ChevronRight, AlertTriangle } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { EDITORS, MOCK_TASKS } from '../../data/tasks';
import { MOCK_SHOOTS } from '../../data/shoots';

interface Props { state: IOSStateReturn }

function LoadingState() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 0', gap: 12 }}>
      <div style={{ width: 32, height: 32, border: '3px solid #7C5CFF', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
      <p style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>Đang tải dữ liệu...</p>
    </div>
  );
}

export function IOSDashboardScreen({ state }: Props) {
  const { prototypeMode, openSheet, setCurrentTab } = state;

  if (prototypeMode === 'loading') return <LoadingState />;

  if (prototypeMode === 'error') {
    return (
      <div style={{ margin: '16px 18px', padding: '24px 16px', background: '#FFF0F0', borderRadius: 20, border: '1px solid rgba(239,68,68,0.15)', textAlign: 'center' }}>
        <AlertTriangle width={36} height={36} color="#EF4444" style={{ margin: '0 auto 10px' }} />
        <p style={{ fontSize: 13, fontWeight: 700, color: '#EF4444', marginBottom: 4 }}>Không thể tải dữ liệu</p>
        <p style={{ fontSize: 11.5, color: '#9AA0B2', marginBottom: 12 }}>Lỗi kết nối máy chủ. Vui lòng thử lại.</p>
        <button onClick={() => state.setPrototypeMode('default')} className="ios-primary-btn" style={{ width: 'auto', padding: '10px 20px', borderRadius: 12, fontSize: 13 }}>
          Thử lại
        </button>
      </div>
    );
  }

  if (prototypeMode === 'empty') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 24px', textAlign: 'center', gap: 8 }}>
        <Video width={48} height={48} strokeWidth={1} color="#CCC" />
        <p style={{ fontSize: 14, fontWeight: 700, color: '#111' }}>Chưa có dữ liệu tháng này</p>
        <p style={{ fontSize: 12, color: '#9AA0B2' }}>Không có video hoặc lịch quay nào được ghi nhận.</p>
      </div>
    );
  }

  const totalTasks = MOCK_TASKS.length;
  const completedTasks = MOCK_TASKS.filter((t) => t.status === 'Đã xong').length;
  const inProgressTasks = MOCK_TASKS.filter((t) => t.status === 'Đang làm').length;
  const pendingTasks = MOCK_TASKS.filter((t) => t.status === 'Chờ').length;
  const completePct = totalTasks ? Math.round((completedTasks / totalTasks) * 100) : 0;

  return (
    <div className="ios-screen-enter" style={{ paddingBottom: 4 }}>
      {/* Greeting + Date Banner */}
      <div style={{ padding: '14px 18px 10px' }}>
        <p style={{ fontSize: 13, color: '#9AA0B2', fontWeight: 600, marginBottom: 2 }}>Tháng 7, 2026</p>
        <h2 style={{ fontSize: 26, fontWeight: 800, color: '#111', letterSpacing: -0.6, margin: 0, lineHeight: 1.1, transition: 'color 0.3s' }}>
          Xin chào, Đạt! 👋
        </h2>
        <p style={{ fontSize: 12.5, color: '#9AA0B2', marginTop: 4, fontWeight: 500 }}>
          Báo cáo cập nhật lúc 09:41 hôm nay
        </p>
      </div>

      {/* KPI Cards 2×2 grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, padding: '4px 18px 0' }}>
        {/* Total */}
        <div className="ios-kpi-card" onClick={() => setCurrentTab('tasks')} style={{ cursor: 'pointer' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(124,92,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Video width={16} height={16} color="#7C5CFF" />
            </div>
            <TrendingUp width={14} height={14} color="#22C55E" />
          </div>
          <div className="ios-kpi-value">{totalTasks}</div>
          <div className="ios-kpi-label">Tổng video task</div>
        </div>

        {/* Completed */}
        <div className="ios-kpi-card" style={{ cursor: 'default' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(34,197,94,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <CheckCircle2 width={16} height={16} color="#22C55E" />
            </div>
            <span style={{ fontSize: 11, fontWeight: 700, color: '#22C55E' }}>{completePct}%</span>
          </div>
          <div className="ios-kpi-value" style={{ color: '#22C55E' }}>{completedTasks}</div>
          <div className="ios-kpi-label">Đã hoàn thành</div>
        </div>

        {/* In Progress */}
        <div className="ios-kpi-card" style={{ cursor: 'default' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(245,158,11,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <PlayCircle width={16} height={16} color="#F59E0B" />
            </div>
          </div>
          <div className="ios-kpi-value" style={{ color: '#F59E0B' }}>{inProgressTasks}</div>
          <div className="ios-kpi-label">Đang thực hiện</div>
        </div>

        {/* Pending */}
        <div className="ios-kpi-card" style={{ cursor: 'default' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(124,92,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Clock width={16} height={16} color="#7C5CFF" />
            </div>
          </div>
          <div className="ios-kpi-value" style={{ color: '#7C5CFF' }}>{pendingTasks}</div>
          <div className="ios-kpi-label">Chờ nghiệm thu</div>
        </div>
      </div>

      {/* Overall Progress Bar */}
      <div className="ios-surface-card" style={{ marginTop: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <span style={{ fontSize: 13, fontWeight: 700, color: '#111', transition: 'color 0.3s' }}>Tiến độ tháng 7</span>
          <span style={{ fontSize: 13, fontWeight: 800, color: '#7C5CFF' }}>{completePct}%</span>
        </div>
        <div className="ios-progress-track">
          <div className="ios-progress-fill" style={{ width: `${completePct}%`, background: '#7C5CFF' }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <span style={{ fontSize: 11, color: '#9AA0B2', fontWeight: 500 }}>{completedTasks} video đã xong</span>
          <span style={{ fontSize: 11, color: '#9AA0B2', fontWeight: 500 }}>Mục tiêu: {totalTasks}</span>
        </div>
      </div>

      {/* Editor Workload */}
      <div className="ios-surface-card" style={{ marginTop: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <h3 style={{ fontSize: 14, fontWeight: 800, color: '#111', margin: 0, transition: 'color 0.3s' }}>Editor</h3>
          <span style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>{EDITORS.length} người</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {EDITORS.map((editor) => {
            const editorTasks = MOCK_TASKS.filter((t) => t.editorId === editor.id);
            const doneCount = editorTasks.filter((t) => t.status === 'Đã xong').length;
            const pct = editorTasks.length ? Math.round((doneCount / editorTasks.length) * 100) : 0;

            return (
              <div key={editor.id}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 7 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div className="ios-editor-avatar" style={{ backgroundColor: editor.color }}>
                      {editor.initial}
                    </div>
                    <span style={{ fontSize: 13, fontWeight: 700, color: '#111', transition: 'color 0.3s' }}>{editor.shortName}</span>
                  </div>
                  <span style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>
                    <span style={{ color: '#111', fontWeight: 800 }}>{doneCount}</span>/{editorTasks.length}
                  </span>
                </div>
                <div className="ios-progress-track">
                  <div className="ios-progress-fill" style={{ width: `${pct}%`, background: editor.color }} />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Upcoming Shoots */}
      <div className="ios-surface-card" style={{ marginTop: 10, marginBottom: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <h3 style={{ fontSize: 14, fontWeight: 800, color: '#111', margin: 0, transition: 'color 0.3s' }}>Lịch quay sắp tới</h3>
          <button
            onClick={() => setCurrentTab('calendar')}
            style={{ fontSize: 13, fontWeight: 700, color: '#7C5CFF', background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 2 }}
          >
            Xem tất cả <ChevronRight width={14} height={14} />
          </button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {MOCK_SHOOTS.slice(0, 3).map((shoot) => (
            <div
              key={shoot.id}
              onClick={() => openSheet('shoot_detail', shoot.id)}
              style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer', padding: '10px 12px', background: '#F8F9FB', borderRadius: 14, border: '1px solid rgba(0,0,0,0.04)', transition: 'all 0.15s' }}
            >
              {/* Date badge */}
              <div style={{ width: 40, height: 44, borderRadius: 12, background: 'rgba(124,92,255,0.1)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span style={{ fontSize: 17, fontWeight: 800, color: '#7C5CFF', lineHeight: 1 }}>
                  {shoot.date.split('-')[2]}
                </span>
                <span style={{ fontSize: 9, fontWeight: 700, color: '#7C5CFF', opacity: 0.7, textTransform: 'uppercase' }}>Thg7</span>
              </div>

              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontSize: 13, fontWeight: 700, color: '#111', margin: '0 0 2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', transition: 'color 0.3s' }}>
                  {shoot.place || 'Địa điểm quay'}
                </p>
                <p style={{ fontSize: 11.5, color: '#9AA0B2', margin: 0, fontWeight: 500 }}>
                  {shoot.time || 'Cả ngày'}{shoot.crew ? ` • ${shoot.crew}` : ''}
                </p>
              </div>

              <span style={{
                fontSize: 10.5,
                fontWeight: 700,
                padding: '3px 8px',
                borderRadius: 8,
                background: shoot.type === 'livestream' ? 'rgba(245,158,11,0.12)' : shoot.type === 'onset' ? 'rgba(59,130,246,0.12)' : 'rgba(124,92,255,0.12)',
                color: shoot.type === 'livestream' ? '#F59E0B' : shoot.type === 'onset' ? '#3B82F6' : '#7C5CFF',
              }}>
                {shoot.type === 'livestream' ? 'Live' : shoot.type === 'onset' ? 'On Set' : 'Quay'}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Upcoming calendar shortcut */}
      <div style={{ padding: '4px 18px 8px' }}>
        <button
          onClick={() => setCurrentTab('calendar')}
          style={{ width: '100%', padding: '13px 16px', background: '#fff', border: '1px solid rgba(0,0,0,0.06)', borderRadius: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(59,130,246,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Calendar width={16} height={16} color="#3B82F6" />
            </div>
            <div style={{ textAlign: 'left' }}>
              <p style={{ fontSize: 13, fontWeight: 700, color: '#111', margin: 0, transition: 'color 0.3s' }}>Xem toàn bộ lịch quay</p>
              <p style={{ fontSize: 11, color: '#9AA0B2', margin: 0, fontWeight: 500 }}>Tháng 7/2026 • {MOCK_SHOOTS.length} lịch</p>
            </div>
          </div>
          <ChevronRight width={18} height={18} color="#CCC" />
        </button>
      </div>
    </div>
  );
}
