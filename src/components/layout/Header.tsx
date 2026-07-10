import { useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { ChevronLeft, ChevronRight, Menu, Calendar, Mail, Bell, Moon, Sun } from 'lucide-react';
import { useTheme } from '../../context/themeContext';
import { useAuth } from '../../context/authContext';
import { useMonth } from '../../context/monthContext';
import { Avatar } from '../common/Avatar';
import { ProfileModal } from '../profile/ProfileModal';
import { formatVietnameseMonth } from '../../utils/month';

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
}

export default function Header({ onOpenSidebar }: HeaderProps) {
  const [profileOpen, setProfileOpen] = useState(false);
  const [monthOpen, setMonthOpen] = useState(false);
  const monthControlRef = useRef<HTMLDivElement>(null);
  const { theme, toggle } = useTheme();
  const { user, profile, roleLabel } = useAuth();
  const { selectedMonth, setSelectedMonth, goToPreviousMonth, goToNextMonth, goToCurrentMonth } = useMonth();
  const { pathname } = useLocation();
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
  }, [pathname, selectedMonth]);

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
                onClick={() => setMonthOpen((value) => !value)}
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
          <button className="icon-btn relative" aria-label="Thông báo">
            <Bell />
            <span className="absolute top-1.5 right-2 w-2 h-2 rounded-full" style={{ background: 'var(--danger)' }}></span>
          </button>
          <button className="icon-btn" title="Đổi giao diện" onClick={toggle}>
            {theme === 'light' ? <Moon /> : <Sun />}
          </button>
          <button type="button" className="header-user-button" onClick={() => setProfileOpen(true)} aria-label="Mở hồ sơ cá nhân">
            <Avatar src={avatarUrl} name={metaName} size="sm" className="header-avatar" />
            <span className="hidden sm:block leading-tight text-left">
              <span className="header-user-name">{metaName}</span>
              <span className="header-user-role">{metaRole}</span>
            </span>
          </button>
        </div>
      </header>

      {profileOpen ? <ProfileModal isOpen={profileOpen} onClose={() => setProfileOpen(false)} /> : null}
    </>
  );
}
