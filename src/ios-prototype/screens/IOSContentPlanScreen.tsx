import { useState } from 'react';
import { Calendar, Link2, UserCheck, Search, X, FileText } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { MOCK_CONTENT_PLAN } from '../../data/contentPlan';
import { EDITORS } from '../../data/tasks';

interface Props { state: IOSStateReturn }

function getCategoryColor(category: string) {
  const map: Record<string, { bg: string; color: string }> = {
    'Review': { bg: 'rgba(124,92,255,0.1)', color: '#7C5CFF' },
    'Vlog': { bg: 'rgba(59,130,246,0.1)', color: '#3B82F6' },
    'Tutorial': { bg: 'rgba(245,158,11,0.1)', color: '#F59E0B' },
    'Shorts': { bg: 'rgba(239,68,68,0.1)', color: '#EF4444' },
    'Livestream': { bg: 'rgba(34,197,94,0.1)', color: '#22C55E' },
  };
  return map[category] || { bg: 'rgba(156,163,175,0.12)', color: '#9AA0B2' };
}

export function IOSContentPlanScreen({ state }: Props) {
  const { prototypeMode, openSheet } = state;
  const [query, setQuery] = useState('');

  if (prototypeMode === 'loading') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 0', gap: 12 }}>
        <div style={{ width: 32, height: 32, border: '3px solid #7C5CFF', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <p style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>Đang tải Content Plan...</p>
      </div>
    );
  }

  const filteredItems = MOCK_CONTENT_PLAN.filter((item) => {
    if (!query.trim()) return true;
    const q = query.toLowerCase();
    return item.video_name.toLowerCase().includes(q) || item.category.toLowerCase().includes(q);
  });

  return (
    <div className="ios-screen-enter">
      {/* Search */}
      <div style={{ padding: '10px 18px 0' }}>
        <div style={{ position: 'relative' }}>
          <Search width={15} height={15} color="#9AA0B2" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Tìm nội dung, kịch bản..."
            className="ios-search-input"
            style={{ paddingLeft: 36 }}
          />
          {query && (
            <button onClick={() => setQuery('')} style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer' }}>
              <X width={14} height={14} color="#9AA0B2" />
            </button>
          )}
        </div>
      </div>

      {/* Count bar */}
      <div style={{ padding: '10px 18px 4px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>{filteredItems.length} kế hoạch nội dung</span>
        <span style={{ fontSize: 12, fontWeight: 700, color: '#7C5CFF' }}>Tháng 7/2026</span>
      </div>

      {/* List */}
      <div style={{ padding: '4px 18px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {filteredItems.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 0', gap: 8, textAlign: 'center' }}>
            <FileText width={40} height={40} strokeWidth={1} color="#CCC" />
            <p style={{ fontSize: 14, fontWeight: 700, color: '#111', margin: 0, transition: 'color 0.3s' }}>Không tìm thấy</p>
            <p style={{ fontSize: 12, color: '#9AA0B2', margin: 0 }}>Thử thay đổi từ khóa tìm kiếm.</p>
          </div>
        ) : (
          filteredItems.map((item) => {
            const editor = EDITORS.find((e) => e.id === item.editor_id);
            const catStyle = getCategoryColor(item.category);

            return (
              <div
                key={item.id}
                onClick={() => openSheet('content_plan_detail', item.id)}
                style={{ background: '#fff', borderRadius: 18, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.04)', cursor: 'pointer', transition: 'all 0.15s' }}
              >
                {/* Top row: category + air date */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 8, background: catStyle.bg, color: catStyle.color }}>
                    {item.category}
                  </span>
                  {item.air_date && (
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: '#22C55E', fontWeight: 700 }}>
                      <Calendar width={11} height={11} />
                      Air: {item.air_date}
                    </span>
                  )}
                </div>

                {/* Video name */}
                <h4 style={{ fontSize: 13.5, fontWeight: 700, color: '#111', margin: '0 0 8px', lineHeight: 1.35, transition: 'color 0.3s', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                  {item.video_name}
                </h4>

                {/* Note */}
                {item.note && (
                  <div style={{ fontSize: 11, color: '#9AA0B2', background: '#F8F9FB', padding: '7px 10px', borderRadius: 10, marginBottom: 8, fontStyle: 'italic' }}>
                    "{item.note}"
                  </div>
                )}

                {/* Footer: editor + linked task */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: 9, borderTop: '1px solid rgba(0,0,0,0.05)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <UserCheck width={13} height={13} color="#3B82F6" />
                    <span style={{ fontSize: 11.5, color: '#9AA0B2' }}>Editor: </span>
                    {editor ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                        <div style={{ width: 20, height: 20, borderRadius: '50%', background: editor.color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 9, fontWeight: 700, color: '#fff' }}>
                          {editor.initial}
                        </div>
                        <span style={{ fontSize: 11.5, fontWeight: 700, color: '#555', transition: 'color 0.3s' }}>{editor.shortName}</span>
                      </div>
                    ) : (
                      <span style={{ fontSize: 11.5, fontWeight: 700, color: '#F59E0B' }}>Chưa phân công</span>
                    )}
                  </div>

                  {item.hasLinkedTask ? (
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 10.5, fontWeight: 700, color: '#22C55E', background: 'rgba(34,197,94,0.1)', padding: '3px 8px', borderRadius: 8 }}>
                      <Link2 width={11} height={11} /> Đã có Task
                    </span>
                  ) : (
                    <span style={{ fontSize: 10.5, color: '#9AA0B2' }}>Chưa tạo task</span>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
