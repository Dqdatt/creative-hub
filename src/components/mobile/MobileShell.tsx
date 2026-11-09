import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { UIEvent } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import {
  Bell,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clapperboard,
  LayoutDashboard,
  Moon,
  Plus,
  Sun,
  WifiOff,
} from 'lucide-react';
import { useAuth } from '../../context/authContext';
import { useMonth } from '../../context/monthContext';
import { canAccessRoute } from '../../config/permissions';
import { formatVietnameseMonth } from '../../utils/month';
import { Avatar } from '../common/Avatar';
import { useToast } from '../common/toastContext';
import { usePwa } from '../../hooks/usePwa';
import { useTheme } from '../../context/themeContext';
import { wasInstallDismissedRecently } from '../../pwa/pwa';
import type { useNotifications } from '../../hooks/useNotifications';
import { MobileChromeContext } from './mobileChrome';
import type { CreateKind } from './mobileChrome';
import { QuickAddSheet } from './QuickAddSheet';
import { InstallSheet } from './InstallSheet';
import type { AppOutletContext } from './outletContext';
import './mobile.css';

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Tổng quan',
  '/calendar': 'Lịch',
  '/workload': 'Lịch',
  '/content-plan': 'Task',
  '/users': 'Thành viên',
  '/profile': 'Hồ sơ cá nhân',
  '/notifications': 'Thông báo',
  '/account': 'Tài khoản',
};

// Trang con: hiện nút quay lại thay vì là một tab.
const BACK_TARGETS: Record<string, string> = {
  '/profile': '/account',
  '/users': '/account',
  '/account': '/dashboard',
};

const MONTH_ROUTES = new Set(['/dashboard', '/calendar', '/workload', '/tasks', '/content-plan']);
const CALENDAR_ROUTES = new Set(['/workload', '/calendar']);

// Nút + làm gì ở từng trang. Trang không có trong bảng thì mở bảng Thêm nhanh.
const ROUTE_CREATE_KINDS: Record<string, CreateKind[]> = {
  '/calendar': ['shoot'],
  '/content-plan': ['content'],
  '/users': ['user'],
  '/workload': ['content', 'shoot'],
};
const CREATE_TARGET: Record<CreateKind, string> = {
  task: '/tasks',
  shoot: '/calendar',
  content: '/content-plan',
  user: '/users',
};
const CREATE_PERMISSION = {
  task: 'video_tasks:create',
  shoot: 'shoots:create',
  content: 'content_plan:create',
  user: 'user_management:create',
} as const;

const INSTALL_PROMPT_DELAY_MS = 4000;

interface MobileShellProps {
  notifications: ReturnType<typeof useNotifications>;
}

export function MobileShell({ notifications }: MobileShellProps) {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { user, profile, role, permissions, can } = useAuth();
  const { selectedMonth, setSelectedMonth, goToPreviousMonth, goToNextMonth } = useMonth();
  const { showToast } = useToast();
  const pwa = usePwa();
  const { theme, toggle: toggleTheme } = useTheme();
  const contentRef = useRef<HTMLElement>(null);
  const lastScrollRef = useRef(0);
  const [toolbarHidden, setToolbarHidden] = useState(false);
  const [quickAddKinds, setQuickAddKinds] = useState<CreateKind[] | null>(null);
  const [installOpen, setInstallOpen] = useState(false);

  const access = useCallback((route: string) => canAccessRoute(role, route, permissions), [permissions, role]);
  const name = profile?.displayName || profile?.fullName || user?.email?.split('@')[0] || 'Thành viên';
  const title = PAGE_TITLES[pathname] ?? 'CreativeHub';
  const backTo = BACK_TARGETS[pathname];
  const isPrimaryRoute = ['/dashboard', '/tasks', '/calendar', '/workload', '/content-plan'].includes(pathname);

  // Đổi trang thì về đầu trang và hiện lại thanh tìm kiếm.
  useEffect(() => {
    contentRef.current?.scrollTo({ top: 0 });
    lastScrollRef.current = 0;
    setToolbarHidden(false);
  }, [pathname]);

  // Gợi ý cài app khi mở bằng trình duyệt điện thoại, tối đa một lần mỗi 7 ngày.
  useEffect(() => {
    if (pwa.isStandalone || pwa.platform === 'unsupported' || wasInstallDismissedRecently()) return undefined;
    const timer = window.setTimeout(() => setInstallOpen(true), INSTALL_PROMPT_DELAY_MS);
    return () => window.clearTimeout(timer);
  }, [pwa.isStandalone, pwa.platform]);

  useEffect(() => {
    if (!pwa.justInstalled) return;
    setInstallOpen(false);
    showToast({
      type: 'success',
      title: 'Đã cài CreativeHub',
      message: 'Mở từ màn hình chính để dùng toàn màn hình và nhận cập nhật nhanh hơn.',
    });
  }, [pwa.justInstalled, showToast]);

  const handleScroll = (event: UIEvent<HTMLElement>) => {
    const y = event.currentTarget.scrollTop;
    const delta = y - lastScrollRef.current;
    lastScrollRef.current = y;
    if (y < 24) {
      setToolbarHidden(false);
      return;
    }
    if (delta > 6) setToolbarHidden(true);
    else if (delta < -6) setToolbarHidden(false);
  };

  const tabs = useMemo(() => {
    const calendarTarget = access('/workload') ? '/workload' : '/calendar';
    return [
      { to: '/dashboard', label: 'Tổng quan', shortLabel: 'Tổng quan', icon: LayoutDashboard, visible: access('/dashboard') },
      { to: calendarTarget, label: 'Lịch', shortLabel: 'Lịch', icon: CalendarDays, visible: access('/workload') || access('/calendar'), group: CALENDAR_ROUTES },
      { to: '/content-plan', label: 'Task', shortLabel: 'Task', icon: Clapperboard, visible: access('/content-plan') },
    ].filter((tab) => tab.visible);
  }, [access]);

  const allowedKinds = (kinds: CreateKind[]) => kinds.filter((kind) => can(CREATE_PERMISSION[kind]));
  const plusKinds = allowedKinds(ROUTE_CREATE_KINDS[pathname] ?? ['content', 'shoot']);

  const startCreate = (kind: CreateKind) => {
    setQuickAddKinds(null);
    const target = pathname === '/workload' && kind !== 'user' ? '/workload' : CREATE_TARGET[kind];
    navigate(`${target}?create=${kind}`);
  };

  const handlePlus = () => {
    if (plusKinds.length === 1) startCreate(plusKinds[0]);
    else setQuickAddKinds(plusKinds);
  };

  const calendarTabs = [
    { to: '/workload', label: 'Workload', visible: access('/workload') },
    { to: '/calendar', label: 'Lịch quay', visible: access('/calendar') },
  ].filter((tab) => tab.visible);

  const outletContext: AppOutletContext = {
    notifications,
    openInstall: () => setInstallOpen(true),
  };

  return (
    <MobileChromeContext.Provider value={{ toolbarHidden }}>
      <div className="m-shell">
        {!pwa.isOnline ? (
          <div className="m-offline" role="status">
            <WifiOff aria-hidden="true" />
            <span><b>Bạn đang ngoại tuyến.</b> Dữ liệu có thể chưa cập nhật, thao tác lưu sẽ lỗi cho tới khi có mạng.</span>
          </div>
        ) : null}

        <header className={`m-topbar ${isPrimaryRoute ? 'is-primary' : ''}`}>
          {isPrimaryRoute ? (
            <Link to="/account" className="m-avatar-btn m-glass-control" aria-label="Tài khoản">
              <Avatar src={profile?.avatarUrl} name={name} size="md" />
            </Link>
          ) : (
            <button type="button" className="m-circle m-glass-control" aria-label="Quay lại" onClick={() => navigate(backTo ?? '/dashboard')}>
              <ChevronLeft />
            </button>
          )}
          {!isPrimaryRoute ? <h1 className="m-title">{title}</h1> : <span className="m-topbar-space" aria-hidden="true" />}
          <div className="m-topbar-actions">
            <button
              type="button"
              className="m-circle m-glass-control"
              aria-label={theme === 'dark' ? 'Dùng giao diện sáng' : 'Dùng giao diện tối'}
              onClick={toggleTheme}
            >
              {theme === 'dark' ? <Sun /> : <Moon />}
            </button>
            <Link
              to="/notifications"
              className={`m-circle m-glass-control m-notification-button ${pathname === '/notifications' ? 'is-active' : ''}`}
              aria-label={notifications.unreadCount ? `Thông báo, ${notifications.unreadCount} chưa đọc` : 'Thông báo'}
            >
              <Bell aria-hidden="true" />
              {notifications.unreadCount ? <span className="m-topbar-badge">{notifications.unreadCount > 99 ? '99+' : notifications.unreadCount}</span> : null}
            </Link>
          </div>
        </header>

        {MONTH_ROUTES.has(pathname) ? (
          <div className="m-subbar">
            {CALENDAR_ROUTES.has(pathname) && calendarTabs.length > 1 ? (
              <nav className="m-segment" aria-label="Chế độ lịch">
                {calendarTabs.map((tab) => (
                  <NavLink key={tab.to} to={tab.to} className={({ isActive }) => `m-segment-item ${isActive ? 'is-active' : ''}`}>
                    {tab.label}
                  </NavLink>
                ))}
              </nav>
            ) : null}
            <div className="m-month">
              <button type="button" aria-label="Tháng trước" onClick={goToPreviousMonth}><ChevronLeft /></button>
              <label className="m-month-label">
                <span>{formatVietnameseMonth(selectedMonth)}</span>
                <input
                  type="month"
                  value={selectedMonth}
                  aria-label="Chọn tháng"
                  onChange={(event) => { if (event.target.value) setSelectedMonth(event.target.value); }}
                />
              </label>
              <button type="button" aria-label="Tháng sau" onClick={goToNextMonth}><ChevronRight /></button>
            </div>
          </div>
        ) : null}

        <main ref={contentRef} id="view" className="m-content" onScroll={handleScroll}>
          <div key={pathname} className="m-page">
            <Outlet context={outletContext} />
          </div>
        </main>

        <div className="m-dock">
          <nav className="m-nav" aria-label="Điều hướng chính">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              const active = tab.group ? tab.group.has(pathname) : pathname === tab.to;
              return (
                <Link
                  key={tab.label}
                  to={tab.to}
                  className={`m-nav-item ${active ? 'is-active' : ''}`}
                  aria-label={tab.label}
                  aria-current={active ? 'page' : undefined}
                >
                  <Icon aria-hidden="true" />
                  <span className="m-nav-label">{tab.shortLabel}</span>
                </Link>
              );
            })}
          </nav>
          {plusKinds.length ? (
            <button type="button" className="m-plus" aria-label="Thêm mới" onClick={handlePlus}>
              <Plus aria-hidden="true" />
            </button>
          ) : null}
        </div>

        <QuickAddSheet kinds={quickAddKinds} onPick={startCreate} onClose={() => setQuickAddKinds(null)} />
        <InstallSheet open={installOpen} platform={pwa.platform} onClose={() => setInstallOpen(false)} />
      </div>
    </MobileChromeContext.Provider>
  );
}
