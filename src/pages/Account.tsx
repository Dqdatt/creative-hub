import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle2, ChevronRight, Download, KeyRound, LogOut, Moon, Sparkles, Sun, UsersRound } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { Avatar } from '../components/common/Avatar';
import { useAppOutlet } from '../components/mobile/outletContext';
import { canAccessRoute } from '../config/permissions';
import { useAuth } from '../context/authContext';
import { useTheme } from '../context/themeContext';
import { usePwa } from '../hooks/usePwa';

const APP_VERSION = 'v1.0.12';

function Row({ icon: Icon, label, right, to, onClick, danger = false }: {
  icon: LucideIcon;
  label: string;
  right?: ReactNode;
  to?: string;
  onClick?: () => void;
  danger?: boolean;
}) {
  const content = (
    <>
      <span className={`m-row-icon ${danger ? 'is-danger' : ''}`}><Icon aria-hidden="true" /></span>
      <span className="m-row-label">{label}</span>
      {right}
      {to || onClick ? <ChevronRight className="m-row-chevron" aria-hidden="true" /> : null}
    </>
  );
  const className = `m-row ${danger ? 'is-danger' : ''}`;
  if (to) return <Link to={to} className={className}>{content}</Link>;
  if (onClick) return <button type="button" className={className} onClick={onClick}>{content}</button>;
  return <div className={className}>{content}</div>;
}

// Trang Tài khoản của giao diện mobile, mở từ avatar trên topbar.
export default function Account() {
  const navigate = useNavigate();
  const { user, profile, role, roleLabel, permissions, signOut } = useAuth();
  const { theme, toggle } = useTheme();
  const { openWhatsNew, openInstall } = useAppOutlet();
  const pwa = usePwa();
  const name = profile?.displayName || profile?.fullName || user?.email?.split('@')[0] || 'Thành viên';
  const canManageUsers = canAccessRoute(role, '/users', permissions);

  const handleLogout = async () => {
    await signOut();
    navigate('/login', { replace: true });
  };

  return (
    <div className="m-stack" data-view="account">
      <Link to="/profile" className="m-card m-profile-card">
        <Avatar src={profile?.avatarUrl} name={name} size="lg" />
        <span className="m-profile-copy">
          <b>{profile?.fullName || name}</b>
          <span>{[roleLabel, profile?.department].filter(Boolean).join(' · ')}</span>
        </span>
        <ChevronRight className="m-row-chevron" aria-hidden="true" />
      </Link>

      {canManageUsers ? (
        <section className="m-section">
          <h2 className="m-section-label">Quản lý</h2>
          <div className="m-card m-list">
            <Row icon={UsersRound} label="Thành viên" to="/users" />
          </div>
        </section>
      ) : null}

      <section className="m-section">
        <h2 className="m-section-label">Bảo mật</h2>
        <div className="m-card m-list">
          <Row icon={KeyRound} label="Đổi mật khẩu" onClick={() => navigate('/profile', { state: { openPassword: true } })} />
        </div>
      </section>

      <section className="m-section">
        <h2 className="m-section-label">Ứng dụng</h2>
        <div className="m-card m-list">
          <div className="m-row m-row--stack">
            <span className="m-row-head">
              <span className="m-row-icon">{theme === 'dark' ? <Moon aria-hidden="true" /> : <Sun aria-hidden="true" />}</span>
              <span className="m-row-label">Giao diện</span>
            </span>
            <div className="m-segment m-segment--inline" role="group" aria-label="Giao diện">
              <button type="button" className={`m-segment-item ${theme === 'light' ? 'is-active' : ''}`} aria-pressed={theme === 'light'} onClick={() => { if (theme !== 'light') toggle(); }}>
                <Sun aria-hidden="true" /> Sáng
              </button>
              <button type="button" className={`m-segment-item ${theme === 'dark' ? 'is-active' : ''}`} aria-pressed={theme === 'dark'} onClick={() => { if (theme !== 'dark') toggle(); }}>
                <Moon aria-hidden="true" /> Tối
              </button>
            </div>
          </div>
          <Row icon={Sparkles} label="Có gì mới?" onClick={openWhatsNew} />
          {pwa.isStandalone ? (
            <Row icon={CheckCircle2} label="Đang dùng bản app đã cài" />
          ) : (
            <Row icon={Download} label="Cài CreativeHub lên màn hình chính" onClick={openInstall} />
          )}
        </div>
      </section>

      <div className="m-card m-list">
        <Row icon={LogOut} label="Đăng xuất" onClick={() => void handleLogout()} danger />
      </div>

      <p className="m-version">CreativeHub · {APP_VERSION}</p>
    </div>
  );
}
