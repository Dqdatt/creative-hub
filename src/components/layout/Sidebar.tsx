import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Clapperboard, ClipboardList, LayoutDashboard, CalendarDays, UsersRound, LogOut, ChevronRight } from 'lucide-react';
import { getVisibleNavigationForPermissions } from '../../config/permissions';
import { useAuth } from '../../context/authContext';

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

  const logout = async () => {
    onClose?.();
    await signOut();
    navigate('/login', { replace: true });
  };

  return (
    <aside
      id="sidebar"
      className={`${mobileOpen ? 'flex fixed inset-y-0 left-0 z-40 shadow-2xl' : 'hidden'} xl:flex xl:sticky xl:inset-auto xl:z-auto xl:shadow-none shrink-0 flex-col ${collapsed ? 'is-collapsed' : ''}`}
    >
      <div className="sb-shell">
        <div className="sb-brand">
          <div className="sb-logo">
            <button
              onClick={() => setCollapsed(!collapsed)}
              className="sb-mark"
              title="Thu gọn / mở rộng sidebar"
            >
              <Clapperboard style={{ width: '20px', height: '20px' }} />
            </button>
          </div>
          <div className="sb-brand-text">
            <div className="t1">CreativeHub</div>
            <div className="t2">Team Marketing</div>
          </div>
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
