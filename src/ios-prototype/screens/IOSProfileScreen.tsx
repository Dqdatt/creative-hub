import { UserRound, Lock, Moon, Sun, LogOut, ShieldCheck, Mail, Camera, ChevronRight, Bell, Globe } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { useAuth } from '../../context/authContext';

interface Props { state: IOSStateReturn }

export function IOSProfileScreen({ state }: Props) {
  const { isDarkMode, toggleDarkMode, openSheet, setCurrentTab } = state;
  const { user, profile, roleLabel, signOut } = useAuth();

  const name = profile?.displayName || 'Đoàn Quốc Đạt';
  const email = user?.email || 'dat.dq@company.com';
  const initial = name.split(' ').pop()?.[0]?.toUpperCase() || 'Đ';

  const handleLogout = async () => {
    try { await signOut(); } catch { /* ignore */ }
    setCurrentTab('login');
  };

  return (
    <div className="ios-screen-enter" style={{ padding: '8px 0' }}>
      {/* Avatar + Name Header */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '18px 18px 24px', textAlign: 'center' }}>
        <div style={{ position: 'relative', marginBottom: 14 }}>
          <div style={{
            width: 88, height: 88, borderRadius: '50%',
            background: 'linear-gradient(135deg, #7C5CFF, #A78BFA)',
            color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 30, fontWeight: 800,
            boxShadow: '0 8px 24px rgba(124,92,255,0.35)',
          }}>
            {initial}
          </div>
          <button
            onClick={() => openSheet('profile_edit')}
            style={{
              position: 'absolute', bottom: 0, right: 0,
              width: 28, height: 28, borderRadius: '50%',
              background: '#111', color: '#fff',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              border: '2px solid #F8F9FB', cursor: 'pointer',
            }}
            aria-label="Đổi Avatar"
          >
            <Camera width={12} height={12} />
          </button>
        </div>

        <h2 style={{ fontSize: 22, fontWeight: 800, color: '#111', margin: '0 0 4px', letterSpacing: -0.4, transition: 'color 0.3s' }}>
          {name}
        </h2>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 13, color: '#9AA0B2', fontWeight: 500, marginBottom: 12 }}>
          <Mail width={13} height={13} />
          {email}
        </div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 12px', background: 'rgba(124,92,255,0.1)', borderRadius: 999, fontSize: 12, fontWeight: 700, color: '#7C5CFF' }}>
          <ShieldCheck width={13} height={13} />
          {roleLabel || 'Admin / Video Editor'}
        </div>
      </div>

      {/* Account Settings Group */}
      <div style={{ padding: '0 18px' }}>
        <p style={{ fontSize: 12, fontWeight: 700, color: '#9AA0B2', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 8, paddingLeft: 4 }}>Tài khoản</p>
        <div className="ios-settings-group">
          <div className="ios-settings-row" onClick={() => openSheet('profile_edit')}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="ios-settings-icon" style={{ background: 'rgba(59,130,246,0.1)' }}>
                <UserRound width={16} height={16} color="#3B82F6" />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Cập nhật hồ sơ</div>
                <div style={{ fontSize: 11.5, color: '#9AA0B2', marginTop: 1 }}>Tên hiển thị, thông tin liên hệ</div>
              </div>
            </div>
            <ChevronRight width={16} height={16} color="#CCC" />
          </div>

          <div className="ios-settings-divider" />

          <div className="ios-settings-row" onClick={() => openSheet('password_edit')}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="ios-settings-icon" style={{ background: 'rgba(124,92,255,0.1)' }}>
                <Lock width={16} height={16} color="#7C5CFF" />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Đổi mật khẩu</div>
                <div style={{ fontSize: 11.5, color: '#9AA0B2', marginTop: 1 }}>Bảo mật tài khoản</div>
              </div>
            </div>
            <ChevronRight width={16} height={16} color="#CCC" />
          </div>
        </div>
      </div>

      {/* Preferences Group */}
      <div style={{ padding: '14px 18px 0' }}>
        <p style={{ fontSize: 12, fontWeight: 700, color: '#9AA0B2', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 8, paddingLeft: 4 }}>Tuỳ chọn</p>
        <div className="ios-settings-group">
          {/* Dark Mode Toggle */}
          <div className="ios-settings-row" onClick={toggleDarkMode} style={{ cursor: 'pointer' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="ios-settings-icon" style={{ background: isDarkMode ? 'rgba(99,102,241,0.12)' : 'rgba(245,158,11,0.1)' }}>
                {isDarkMode ? <Sun width={16} height={16} color="#6366F1" /> : <Moon width={16} height={16} color="#F59E0B" />}
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Giao diện tối</div>
                <div style={{ fontSize: 11.5, color: '#9AA0B2', marginTop: 1 }}>{isDarkMode ? 'Đang bật' : 'Đang tắt'}</div>
              </div>
            </div>
            {/* iOS Toggle Switch */}
            <div style={{
              width: 42, height: 24, borderRadius: 999,
              background: isDarkMode ? '#7C5CFF' : '#D1D5DB',
              padding: 3,
              display: 'flex', alignItems: 'center',
              transition: 'background 0.2s',
            }}>
              <div style={{
                width: 18, height: 18, borderRadius: '50%',
                background: '#fff',
                transform: isDarkMode ? 'translateX(18px)' : 'translateX(0)',
                transition: 'transform 0.2s',
                boxShadow: '0 1px 4px rgba(0,0,0,0.15)',
              }} />
            </div>
          </div>

          <div className="ios-settings-divider" />

          <div className="ios-settings-row" onClick={() => openSheet('more_menu')}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="ios-settings-icon" style={{ background: 'rgba(34,197,94,0.1)' }}>
                <Bell width={16} height={16} color="#22C55E" />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Thông báo</div>
                <div style={{ fontSize: 11.5, color: '#9AA0B2', marginTop: 1 }}>Quản lý thông báo hệ thống</div>
              </div>
            </div>
            <ChevronRight width={16} height={16} color="#CCC" />
          </div>

          <div className="ios-settings-divider" />

          <div className="ios-settings-row" style={{ cursor: 'default' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div className="ios-settings-icon" style={{ background: 'rgba(59,130,246,0.1)' }}>
                <Globe width={16} height={16} color="#3B82F6" />
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Ngôn ngữ</div>
                <div style={{ fontSize: 11.5, color: '#9AA0B2', marginTop: 1 }}>Tiếng Việt</div>
              </div>
            </div>
            <span style={{ fontSize: 13, color: '#9AA0B2', fontWeight: 600 }}>VI</span>
          </div>
        </div>
      </div>

      {/* App Info */}
      <div style={{ padding: '14px 18px 0' }}>
        <div className="ios-settings-group">
          <div className="ios-settings-row" style={{ cursor: 'default' }}>
            <span style={{ fontSize: 14, fontWeight: 600, color: '#111', transition: 'color 0.3s' }}>Phiên bản ứng dụng</span>
            <span style={{ fontSize: 13, color: '#9AA0B2', fontWeight: 600 }}>v1.0.0</span>
          </div>
        </div>
      </div>

      {/* Logout */}
      <div style={{ padding: '14px 18px 8px' }}>
        <button
          onClick={handleLogout}
          style={{
            width: '100%', padding: '14px',
            background: '#FFF0F0', border: '1px solid rgba(239,68,68,0.15)',
            borderRadius: 16, display: 'flex', alignItems: 'center', justifyContent: 'center',
            gap: 8, cursor: 'pointer', transition: 'all 0.15s',
            fontSize: 14, fontWeight: 700, color: '#EF4444',
            fontFamily: 'inherit',
          }}
        >
          <LogOut width={16} height={16} />
          Đăng xuất
        </button>
      </div>
    </div>
  );
}
