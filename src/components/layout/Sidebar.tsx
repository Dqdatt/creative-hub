import { useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import {
  Clapperboard,
  ClipboardList,
  LayoutDashboard,
  CalendarDays,
  UsersRound,
  LogOut,
  ChevronRight,
  PanelLeftClose,
  PanelLeftOpen,
} from 'lucide-react';
import { getDefaultAuthenticatedRoute, getVisibleNavigationForPermissions } from '../../config/permissions';
import { useAuth } from '../../context/authContext';
import logoSymbol from '../../assets/logo.png';
import logoWordmark from '../../assets/text.png';

const NAV_ICONS = {
  dashboard: LayoutDashboard,
  calendar: CalendarDays,
  tasks: Clapperboard,
  content_plan: ClipboardList,
  users: UsersRound,
};

interface SidebarProps {
  mobileOpen?: boolean;
  onClose?: () => void;
}

export default function Sidebar({ mobileOpen = false, onClose }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const { role, permissions, signOut } = useAuth();
  const navigation = getVisibleNavigationForPermissions(role, permissions);
  const defaultRoute = getDefaultAuthenticatedRoute(role, permissions);
  const isCollapsed = !mobileOpen && collapsed;
  const ToggleIcon = isCollapsed ? PanelLeftOpen : PanelLeftClose;
  const toggleLabel = isCollapsed ? 'Mở rộng thanh điều hướng' : 'Thu gọn thanh điều hướng';

  const logout = async () => {
    onClose?.();
    await signOut();
    navigate('/login', { replace: true });
  };

  return (
    <aside
      id="sidebar"
      className={`${mobileOpen ? 'flex fixed inset-y-0 left-0 z-40 shadow-2xl' : 'hidden'} xl:flex xl:sticky xl:inset-auto xl:z-auto xl:shadow-none shrink-0 flex-col ${isCollapsed ? 'is-collapsed' : ''}`}
    >
      <div className="sb-shell">
        <div className="sb-brand">
          {mobileOpen ? (
            <Link
              to={defaultRoute}
              className="sb-mobile-brand-link"
              aria-label="CreativeHub - Trang chính"
              onClick={onClose}
            >
              <img className="sb-brand-symbol" src={logoSymbol} alt="" draggable={false} />
              <span className="sb-brand-wordmark-wrap" aria-hidden="true">
                <img className="sb-brand-wordmark" src={logoWordmark} alt="" draggable={false} />
                <span className="sb-brand-wordmark-creative" aria-hidden="true"></span>
              </span>
            </Link>
          ) : (
            <>
              <button
                type="button"
                onClick={() => setCollapsed((value) => !value)}
                className="sb-logo-toggle"
                aria-label={toggleLabel}
                title={toggleLabel}
              >
                <span className="sb-logo-layer" aria-hidden="true">
                  <img className="sb-brand-symbol" src={logoSymbol} alt="" draggable={false} />
                </span>
                <span className="sb-toggle-layer" aria-hidden="true">
                  <ToggleIcon />
                </span>
              </button>
              {!isCollapsed ? (
                <Link
                  to={defaultRoute}
                  className="sb-wordmark-link"
                  aria-label="CreativeHub - Trang chính"
                >
                  <span className="sb-brand-wordmark-wrap" aria-hidden="true">
                    <img className="sb-brand-wordmark" src={logoWordmark} alt="" draggable={false} />
                    <span className="sb-brand-wordmark-creative" aria-hidden="true"></span>
                  </span>
                </Link>
              ) : null}
            </>
          )}
        </div>

        <div className="sb-scroll">
          <nav id="nav" className="space-y-1.5 w-full">
            {navigation.map((n) => {
              const Icon = NAV_ICONS[n.id];

              return (
                <NavLink
                  key={n.id}
                  to={n.to}
                  className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
                  title={n.label}
                  onClick={onClose}
                >
                  <span className="nav-ic"><Icon /></span>
                  <span className="nav-txt">{n.label}</span>
                  <span className="nav-tail">
                    <span className="nav-chevron"><ChevronRight /></span>
                    <span className="nav-dot"></span>
                  </span>
                </NavLink>
              );
            })}
          </nav>
        </div>

        <div className="sb-foot">
          <button className="nav-item nav-logout" onClick={logout}>
            <span className="nav-ic"><LogOut /></span>
            <span className="nav-txt">Đăng xuất</span>
          </button>
        </div>
      </div>
    </aside>
  );
}
