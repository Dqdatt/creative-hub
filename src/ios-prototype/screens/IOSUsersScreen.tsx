import { CheckCircle, Mail, ChevronRight, UserPlus, Search } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { useState } from 'react';

interface Props { state: IOSStateReturn }

const usersList = [
  { id: 'dat',   name: 'Đoàn Quốc Đạt',      email: 'dat.dq@company.com',     role: 'Admin',            roleClr: '#7C5CFF', avatarClr: '#6366F1', initial: 'Đ' },
  { id: 'hai',   name: 'Nguyễn Thanh Hải',     email: 'hai.nt@company.com',     role: 'Video Editor',     roleClr: '#3B82F6', avatarClr: '#22C55E', initial: 'H' },
  { id: 'minh',  name: 'Hoàng Hữu Lê Minh',   email: 'minh.hhl@company.com',   role: 'Video Editor',     roleClr: '#3B82F6', avatarClr: '#F59E0B', initial: 'M' },
  { id: 'khang', name: 'Bùi Gia Khang',        email: 'khang.bg@company.com',   role: 'Creative Manager', roleClr: '#22C55E', avatarClr: '#A855F7', initial: 'K' },
  { id: 'bumi',  name: 'Nguyễn Vũ Bumi',       email: 'bumi.nv@company.com',    role: 'Content Creator',  roleClr: '#F59E0B', avatarClr: '#EC4899', initial: 'B' },
];

export function IOSUsersScreen({ state }: Props) {
  const { openSheet } = state;
  const [query, setQuery] = useState('');

  const filtered = usersList.filter(u =>
    !query.trim() || u.name.toLowerCase().includes(query.toLowerCase()) || u.role.toLowerCase().includes(query.toLowerCase())
  );

  return (
    <div className="ios-screen-enter">
      {/* Search */}
      <div style={{ padding: '10px 18px 0' }}>
        <div style={{ position: 'relative' }}>
          <Search width={15} height={15} color="#9AA0B2" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Tìm nhân sự..."
            className="ios-search-input"
            style={{ paddingLeft: 36 }}
          />
        </div>
      </div>

      {/* Header info */}
      <div style={{ padding: '10px 18px 4px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 12, color: '#9AA0B2', fontWeight: 600 }}>{filtered.length} thành viên</span>
        <button
          onClick={() => openSheet('user_detail', 'dat')}
          style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 700, color: '#fff', background: '#7C5CFF', border: 'none', borderRadius: 10, padding: '6px 12px', cursor: 'pointer', boxShadow: '0 3px 10px rgba(124,92,255,0.28)' }}
        >
          <UserPlus width={13} height={13} />
          Thêm
        </button>
      </div>

      {/* User List */}
      <div style={{ padding: '4px 18px 8px' }}>
        {/* Group card */}
        <div style={{ background: '#fff', borderRadius: 20, overflow: 'hidden', boxShadow: '0 2px 14px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.04)' }}>
          {filtered.map((u, idx) => (
            <div key={u.id}>
              <div
                onClick={() => openSheet('user_detail', u.id)}
                style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '13px 16px', cursor: 'pointer', transition: 'background 0.15s' }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  {/* Avatar */}
                  <div style={{
                    width: 44, height: 44, borderRadius: '50%',
                    background: u.avatarClr,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 16, fontWeight: 800, color: '#fff',
                    flexShrink: 0,
                    boxShadow: `0 3px 10px ${u.avatarClr}55`,
                  }}>
                    {u.initial}
                  </div>

                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 3 }}>
                      <span style={{ fontSize: 14, fontWeight: 700, color: '#111', transition: 'color 0.3s' }}>{u.name}</span>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 6, background: `${u.roleClr}18`, color: u.roleClr }}>
                        {u.role}
                      </span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11.5, color: '#9AA0B2' }}>
                      <Mail width={11} height={11} />
                      {u.email}
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 3, fontSize: 10.5, fontWeight: 700, color: '#22C55E' }}>
                    <CheckCircle width={12} height={12} />
                  </div>
                  <ChevronRight width={16} height={16} color="#CCC" />
                </div>
              </div>
              {idx < filtered.length - 1 && (
                <div style={{ height: 1, background: 'rgba(0,0,0,0.05)', margin: '0 16px' }} />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Dept stats card */}
      <div style={{ margin: '6px 18px 8px', background: '#fff', borderRadius: 18, padding: '14px 16px', boxShadow: '0 2px 12px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.04)' }}>
        <p style={{ fontSize: 12, fontWeight: 700, color: '#9AA0B2', marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.4 }}>Phòng ban</p>
        <div style={{ display: 'flex', justifyContent: 'space-around' }}>
          {[
            { label: 'Admin', count: 1, color: '#7C5CFF' },
            { label: 'Editor', count: 2, color: '#3B82F6' },
            { label: 'Manager', count: 1, color: '#22C55E' },
            { label: 'Creator', count: 1, color: '#F59E0B' },
          ].map(dept => (
            <div key={dept.label} style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: dept.color, lineHeight: 1, marginBottom: 4 }}>{dept.count}</div>
              <div style={{ fontSize: 10.5, color: '#9AA0B2', fontWeight: 600 }}>{dept.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
