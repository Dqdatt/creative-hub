import { useState, useMemo } from 'react';
import { Clapperboard, CheckCircle2, PlayCircle, AlertCircle, Clock, Search, X } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { MOCK_TASKS, EDITORS } from '../../data/tasks';

interface Props { state: IOSStateReturn }

const STATUS_FILTERS = [
  { id: 'all', label: 'Tất cả' },
  { id: 'doing', label: 'Đang làm' },
  { id: 'done', label: 'Đã xong' },
  { id: 'pending', label: 'Chờ' },
] as const;
type FilterId = typeof STATUS_FILTERS[number]['id'];

function getTaskCardClass(status: string, priority?: string): string {
  if (priority === 'Gấp') return 'ios-task-card urgent';
  if (status === 'Đã xong') return 'ios-task-card todo';
  if (status === 'Đang làm') return 'ios-task-card reminder';
  return 'ios-task-card event';
}

function getStatusColor(status: string) {
  if (status === 'Đã xong') return '#22C55E';
  if (status === 'Đang làm') return '#3B82F6';
  return '#F59E0B';
}

function getTypeLabel(status: string) {
  if (status === 'Đã xong') return 'Hoàn thành';
  if (status === 'Đang làm') return 'Đang thực hiện';
  return 'Chờ xử lý';
}

export function IOSTasksScreen({ state }: Props) {
  const { prototypeMode, openSheet } = state;
  const [filter, setFilter] = useState<FilterId>('all');
  const [query, setQuery] = useState('');

  const filteredTasks = useMemo(() => {
    if (prototypeMode === 'empty') return [];
    return MOCK_TASKS.filter((task) => {
      if (filter === 'doing' && task.status !== 'Đang làm') return false;
      if (filter === 'done' && task.status !== 'Đã xong') return false;
      if (filter === 'pending' && task.status !== 'Chờ') return false;
      if (query.trim()) {
        const q = query.toLowerCase();
        return task.name.toLowerCase().includes(q) || task.category.toLowerCase().includes(q) || task.orderTeam.toLowerCase().includes(q);
      }
      return true;
    });
  }, [prototypeMode, filter, query]);

  if (prototypeMode === 'loading') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 0', gap: 12 }}>
        <div style={{ width: 32, height: 32, border: '3px solid #7C5CFF', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <p style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>Đang tải video task...</p>
      </div>
    );
  }

  if (prototypeMode === 'error') {
    return (
      <div style={{ margin: '16px 18px', padding: '24px 16px', background: '#FFF0F0', borderRadius: 20, textAlign: 'center' }}>
        <AlertCircle width={36} height={36} color="#EF4444" style={{ margin: '0 auto 10px' }} />
        <p style={{ fontSize: 13, fontWeight: 700, color: '#EF4444', marginBottom: 4 }}>Không thể tải dữ liệu</p>
        <p style={{ fontSize: 11.5, color: '#9AA0B2', marginBottom: 12 }}>Vui lòng thử lại sau.</p>
        <button onClick={() => state.setPrototypeMode('default')} className="ios-primary-btn" style={{ width: 'auto', padding: '10px 20px', borderRadius: 12, fontSize: 13 }}>
          Thử lại
        </button>
      </div>
    );
  }

  return (
    <div className="ios-screen-enter">
      {/* Search */}
      <div style={{ padding: '10px 18px 0' }}>
        <div style={{ position: 'relative' }}>
          <Search width={15} height={15} color="#9AA0B2" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Tìm video task, phòng ban..."
            className="ios-search-input"
            style={{ paddingLeft: 36 }}
          />
          {query && (
            <button onClick={() => setQuery('')} style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', padding: 2 }}>
              <X width={14} height={14} color="#9AA0B2" />
            </button>
          )}
        </div>
      </div>

      {/* Segmented filter */}
      <div style={{ padding: '10px 18px 0' }}>
        <div className="ios-segment-wrap">
          {STATUS_FILTERS.map((f) => {
            const count = f.id === 'all' ? MOCK_TASKS.length
              : MOCK_TASKS.filter(t => f.id === 'doing' ? t.status === 'Đang làm' : f.id === 'done' ? t.status === 'Đã xong' : t.status === 'Chờ').length;
            return (
              <button
                key={f.id}
                onClick={() => setFilter(f.id)}
                className={`ios-segment-btn ${filter === f.id ? 'active' : ''}`}
              >
                {f.label}
                {count > 0 && (
                  <span style={{ marginLeft: 4, fontSize: 10, fontWeight: 800, padding: '1px 5px', borderRadius: 999, background: filter === f.id ? '#7C5CFF' : 'rgba(0,0,0,0.08)', color: filter === f.id ? '#fff' : '#666' }}>
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Count */}
      <div style={{ padding: '10px 18px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>{filteredTasks.length} video task</span>
        <button onClick={() => openSheet('task_create')} style={{ fontSize: 12, fontWeight: 700, color: '#7C5CFF', background: 'none', border: 'none', cursor: 'pointer' }}>
          + Thêm mới
        </button>
      </div>

      {/* Task List */}
      <div style={{ padding: '4px 18px 8px' }}>
        {filteredTasks.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 0', gap: 8, textAlign: 'center' }}>
            <Clapperboard width={40} height={40} strokeWidth={1} color="#CCC" />
            <p style={{ fontSize: 14, fontWeight: 700, color: '#111', margin: 0, transition: 'color 0.3s' }}>Không tìm thấy task</p>
            <p style={{ fontSize: 12, color: '#9AA0B2', margin: 0 }}>Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.</p>
          </div>
        ) : (
          filteredTasks.map((task) => {
            const editor = EDITORS.find((e) => e.id === task.editorId);
            const statusColor = getStatusColor(task.status);

            return (
              <div
                key={task.id}
                onClick={() => openSheet('task_detail', task.id)}
                className={getTaskCardClass(task.status, task.priority)}
              >
                {/* Type label + priority */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
                  <span className="ios-task-type-label">{getTypeLabel(task.status)}</span>
                  {task.priority === 'Gấp' && (
                    <span className="ios-badge red">GẤP</span>
                  )}
                </div>

                {/* Task name */}
                <h4 className="ios-task-name">{task.name}</h4>

                {/* Meta row */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    {editor && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                        <div className="ios-editor-avatar" style={{ backgroundColor: editor.color, width: 22, height: 22, fontSize: 9 }}>
                          {editor.initial}
                        </div>
                        <span style={{ fontSize: 11.5, fontWeight: 600, color: '#555', transition: 'color 0.3s' }}>{editor.shortName}</span>
                      </div>
                    )}
                    <span className="ios-badge blue">{task.orderTeam}</span>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                    {task.status === 'Đã xong' ? (
                      <CheckCircle2 width={14} height={14} color={statusColor} />
                    ) : task.status === 'Đang làm' ? (
                      <PlayCircle width={14} height={14} color={statusColor} />
                    ) : (
                      <Clock width={14} height={14} color={statusColor} />
                    )}
                    <span className="ios-task-time">{task.airDate || task.category}</span>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
