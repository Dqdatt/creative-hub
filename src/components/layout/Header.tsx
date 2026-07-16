import { useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { ChevronLeft, ChevronRight, Menu, Calendar, Mail, Moon, Sun, Sparkles, UserRound } from 'lucide-react';
import { useTheme } from '../../context/themeContext';
import { useAuth } from '../../context/authContext';
import { useMonth } from '../../context/monthContext';
import { Avatar } from '../common/Avatar';
import { ProfileModal } from '../profile/ProfileModal';
import { formatVietnameseMonth } from '../../utils/month';
import { NotificationCenter } from './NotificationCenter';
import type { useNotifications } from '../../hooks/useNotifications';

const PAGE_META: Record<string, { title: string; sub: string }> = {
  '/dashboard': { title: 'Tổng quan', sub: 'Báo cáo công việc theo tháng' },
  '/calendar': { title: 'Lịch quay', sub: 'Lịch buổi quay theo tháng' },
  '/tasks': { title: 'Video tháng', sub: 'Tổng hợp video theo tháng' },
  '/content-plan': { title: 'Content Plan', sub: 'Lịch air nội dung theo tháng' },
  '/users': { title: 'Thành viên', sub: 'Quản lý tài khoản và vai trò nội bộ' },
  '/profile': { title: 'Hồ sơ', sub: 'Thông tin cá nhân và cài đặt' },
};

const MONTH_ROUTES = new Set(['/dashboard', '/calendar', '/tasks', '/content-plan']);

interface HeaderProps {
  onOpenSidebar?: () => void;
  onOpenWhatsNew?: () => void;
  notifications: ReturnType<typeof useNotifications>;
}

export default function Header({ onOpenSidebar, onOpenWhatsNew, notifications }: HeaderProps) {
  const [profileOpen, setProfileOpen] = useState(false);
  const [monthOpen, setMonthOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const monthControlRef = useRef<HTMLDivElement>(null);
  const accountMenuRef = useRef<HTMLDivElement>(null);
  const { theme, toggle } = useTheme();
  const { user, profile, role, roleLabel, permissions } = useAuth();
  const { selectedMonth, setSelectedMonth, goToPreviousMonth, goToNextMonth, goToCurrentMonth } = useMonth();
  const { pathname, search } = useLocation();
  const meta = PAGE_META[pathname] ?? { title: 'Không tìm thấy', sub: 'Đường dẫn không tồn tại' };
  const showMonthControl = MONTH_ROUTES.has(pathname);
  const metaName = profile?.displayName || (typeof user?.user_metadata?.full_name === 'string'
    ? user.user_metadata.full_name
    : typeof user?.user_metadata?.name === 'string'
      ? user.user_metadata.name
      : user?.email?.split('@')[0] ?? 'Nhân sự');
  const metaRole = roleLabel;
  const avatarUrl = profile?.avatarUrl || (typeof user?.user_metadata?.avatar_url === 'string'
    ? user.user_metadata.avatar_url
    : '');
  const monthLabel = formatVietnameseMonth(selectedMonth);

  useEffect(() => {
    setMonthOpen(false);
    setAccountOpen(false);
    setNotificationsOpen(false);
  }, [pathname, search, selectedMonth]);

  useEffect(() => {
    setNotificationsOpen(false);
    setAccountOpen(false);
  }, [profile?.id, user?.id]);

  useEffect(() => {
    if (!monthOpen) return;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (monthControlRef.current?.contains(target)) return;
      setMonthOpen(false);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setMonthOpen(false);
    };

    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [monthOpen]);

  useEffect(() => {
    if (!accountOpen) return;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (accountMenuRef.current?.contains(target)) return;
      setAccountOpen(false);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setAccountOpen(false);
    };

    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [accountOpen]);

  const openProfile = () => {
    setAccountOpen(false);
    setProfileOpen(true);
  };

  const openWhatsNew = () => {
    setAccountOpen(false);
    onOpenWhatsNew?.();
  };

  return (
    <>
      <header className="topbar">
        <button className="xl:hidden icon-btn shrink-0" onClick={onOpenSidebar} aria-label="Mở sidebar">
          <Menu />
        </button>
        <div className="min-w-0">
          <h1 id="pageTitle" className="page-title">{meta.title}</h1>
          <p id="pageSub" className="page-sub">{meta.sub}</p>
        </div>
        <div className="header-actions ml-auto flex items-center gap-2.5">
          {showMonthControl ? (
            <div ref={monthControlRef} className="topbar-month-control">
              <button type="button" className="icon-btn month-step-btn" onClick={goToPreviousMonth} aria-label="Tháng trước">
                <ChevronLeft />
              </button>
              <button
                type="button"
                className="date-chip month-chip"
                onClick={() => {
                  setAccountOpen(false);
                  setNotificationsOpen(false);
                  setMonthOpen((value) => !value);
                }}
                aria-expanded={monthOpen}
                aria-haspopup="dialog"
              >
                <Calendar />
                <span>{monthLabel}</span>
              </button>
              <button type="button" className="icon-btn month-step-btn" onClick={goToNextMonth} aria-label="Tháng sau">
                <ChevronRight />
              </button>

              {monthOpen ? (
                <div className="month-popover card">
                  <input
                    type="month"
                    className="field"
                    value={selectedMonth}
                    onChange={(event) => setSelectedMonth(event.target.value)}
                    aria-label="Chọn tháng"
                  />
                  <button type="button" className="btn-ghost w-full" onClick={goToCurrentMonth}>
                    Tháng này
                  </button>
                </div>
              ) : null}
            </div>
          ) : null}
          <button className="icon-btn hidden sm:grid" aria-label="Hộp thư"><Mail /></button>
          <NotificationCenter
            notifications={notifications.notifications}
            unreadCount={notifications.unreadCount}
            isLoading={notifications.isLoading}
            loadError={notifications.loadError}
            mutationError={notifications.mutationError}
            isOpen={notificationsOpen}
            role={role}
            permissions={permissions}
            onOpenChange={(open) => {
              if (open) {
                setAccountOpen(false);
                setMonthOpen(false);
              }
              setNotificationsOpen(open);
            }}
            onMarkOneRead={notifications.markOneRead}
            onMarkAllRead={notifications.markAllRead}
            onDeleteOne={notifications.deleteOne}
            onDeleteOlderThan={notifications.deleteOlderThan}
            onRetry={notifications.refetch}
            deletingIds={notifications.deletingIds}
            isDeletingOlder={notifications.isDeletingOlder}
          />
          <button className="icon-btn" title="Đổi giao diện" onClick={toggle}>
            {theme === 'light' ? <Moon /> : <Sun />}
          </button>
          <div ref={accountMenuRef} className="header-account">
            <button
              type="button"
              className="header-user-button"
              onClick={() => {
                setNotificationsOpen(false);
                setMonthOpen(false);
                setAccountOpen((value) => !value);
              }}
              aria-label="Mở menu tài khoản"
              aria-haspopup="menu"
              aria-expanded={accountOpen}
            >
              <Avatar src={avatarUrl} name={metaName} size="sm" className="header-avatar" />
              <span className="hidden sm:block leading-tight text-left">
                <span className="header-user-name">{metaName}</span>
                <span className="header-user-role">{metaRole}</span>
              </span>
            </button>

            {accountOpen ? (
              <div className="header-account-menu card" role="menu">
                <button type="button" className="header-account-item" role="menuitem" onClick={openProfile}>
                  <UserRound />
                  <span>Hồ sơ cá nhân</span>
                </button>
                <button type="button" className="header-account-item" role="menuitem" onClick={openWhatsNew}>
                  <Sparkles />
                  <span>Có gì mới?</span>
                </button>
              </div>
            ) : null}
          </div>
        </div>
      </header>

      {profileOpen ? <ProfileModal isOpen={profileOpen} onClose={() => setProfileOpen(false)} /> : null}
    </>
  );
}
