import {
  Bell,
  Calendar,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clapperboard,
  ClipboardList,
  LayoutDashboard,
  Link2,
  LogOut,
  Mail,
  Menu,
  Moon,
  Plus,
  Search,
  Trash2,
  UsersRound,
} from 'lucide-react';
import logoSymbol from '../../assets/logo.png';
import logoWordmark from '../../assets/text.png';

const NAVIGATION = [
  { id: 'dashboard', label: 'Tổng quan', icon: LayoutDashboard },
  { id: 'calendar', label: 'Lịch quay', icon: CalendarDays },
  { id: 'tasks', label: 'Video tháng', icon: Clapperboard },
  { id: 'content-plan', label: 'Content Plan', icon: ClipboardList },
  { id: 'users', label: 'Thành viên', icon: UsersRound },
] as const;

const TABLE_COLUMNS: Array<{ label: string; width: string; className?: string }> = [
  { label: 'STT', width: '48px', className: 'text-center' },
  { label: 'Tên video', width: '260px' },
  { label: 'Resize', width: '112px' },
  { label: 'Editor', width: '144px' },
  { label: 'Order', width: '80px' },
  { label: 'Thể loại', width: '96px' },
  { label: 'Nhận', width: '80px' },
  { label: 'Trả', width: '80px' },
  { label: 'Air', width: '80px' },
  { label: 'Trạng thái', width: '128px' },
  { label: 'Ưu tiên', width: '80px' },
  { label: 'Ghi chú', width: '220px' },
  { label: 'Link', width: '64px', className: 'text-center' },
  { label: 'Thao tác', width: '84px', className: 'text-center' },
];

const SKELETON_ROWS = Array.from({ length: 14 }, (_, index) => index);

function Skeleton({ className = '', box = false }: { className?: string; box?: boolean }) {
  return <span className={`${box ? 'skel-box' : 'skel-line'} ${className}`} aria-hidden="true" />;
}

function AuthSkeletonSidebar() {
  return (
    <aside id="sidebar" className="hidden xl:flex xl:sticky xl:inset-auto xl:z-auto xl:shadow-none shrink-0 flex-col">
      <div className="sb-shell">
        <div className="sb-brand">
          <div className="sb-logo-toggle auth-static-logo" aria-hidden="true">
            <span className="sb-logo-layer">
              <img className="sb-brand-symbol" src={logoSymbol} alt="" draggable={false} />
            </span>
          </div>
          <span className="sb-wordmark-link" aria-label="CreativeHub - Trang chính">
            <span className="sb-brand-wordmark-wrap" aria-hidden="true">
              <img className="sb-brand-wordmark" src={logoWordmark} alt="" draggable={false} />
              <span className="sb-brand-wordmark-creative" aria-hidden="true"></span>
            </span>
          </span>
        </div>

        <div className="sb-scroll">
          <nav id="nav" className="space-y-1.5 w-full" aria-label="Điều hướng đang tải">
            {NAVIGATION.map((item) => {
              const Icon = item.icon;
              const active = item.id === 'tasks';

              return (
                <div key={item.id} className={`nav-item ${active ? 'active' : ''}`}>
                  <span className="nav-ic"><Icon /></span>
                  <span className="nav-txt">{item.label}</span>
                  <span className="nav-tail">
                    <span className="nav-dot"></span>
                  </span>
                </div>
              );
            })}
          </nav>
        </div>

        <div className="sb-foot">
          <div className="nav-item nav-logout">
            <span className="nav-ic"><LogOut /></span>
            <span className="nav-txt">Đăng xuất</span>
          </div>
        </div>
      </div>
    </aside>
  );
}

function AuthSkeletonHeader() {
  return (
    <header className="topbar">
      <button className="xl:hidden icon-btn shrink-0" disabled aria-label="Mở sidebar">
        <Menu />
      </button>
      <div className="min-w-0">
        <h1 id="pageTitle" className="page-title">Video tháng</h1>
      </div>
      <div className="header-actions ml-auto flex items-center gap-2.5">
        <div className="topbar-month-control">
          <button type="button" className="icon-btn month-step-btn" disabled aria-label="Tháng trước">
            <ChevronLeft />
          </button>
          <button type="button" className="date-chip month-chip auth-month-skeleton" disabled aria-label="Tháng đang tải">
            <Calendar />
            <Skeleton className="w-[86px]" />
          </button>
          <button type="button" className="icon-btn month-step-btn" disabled aria-label="Tháng sau">
            <ChevronRight />
          </button>
        </div>
        <button className="icon-btn hidden sm:grid" disabled aria-label="Hộp thư"><Mail /></button>
        <button className="icon-btn" disabled aria-label="Thông báo"><Bell /></button>
        <button className="icon-btn" disabled aria-label="Đổi giao diện"><Moon /></button>
        <div className="header-account">
          <button type="button" className="header-user-button auth-user-skeleton" disabled aria-label="Tài khoản đang tải">
            <Skeleton box className="skel-avatar header-avatar" />
            <span className="hidden sm:grid leading-tight text-left auth-user-lines">
              <Skeleton className="w-[92px]" />
              <Skeleton className="w-[64px]" />
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}

function AuthSkeletonFilters() {
  return (
    <div className="sticky-filter-bar flex flex-wrap items-center gap-3 p-3">
      <div className="relative">
        <Search className="text-sub absolute left-4 top-1/2 -translate-y-1/2" style={{ width: '17px', height: '17px' }} />
        <input
          placeholder="Tìm tên video..."
          className="field w-64"
          style={{ paddingLeft: '42px' }}
          disabled
          aria-label="Tìm tên video"
        />
      </div>
      <button type="button" className="field auth-filter-select" disabled>
        Tất cả editor
      </button>
      <button type="button" className="field auth-filter-select auth-filter-status" disabled>
        Tất cả trạng thái
      </button>
      <div className="ml-auto text-[13px] text-sub font-semibold flex items-center mr-1 auth-count-skeleton">
        <Skeleton className="w-[88px]" />
      </div>
      <button className="btn btn-sm" disabled>
        <Plus style={{ width: '17px', height: '17px' }} /> Thêm Task
      </button>
    </div>
  );
}

function VideoSkeletonRow({ index }: { index: number }) {
  const titleWidths = ['w-[84%]', 'w-[70%]', 'w-[92%]', 'w-[62%]'];
  const noteWidths = ['w-[78%]', 'w-[88%]', 'w-[66%]', 'w-[94%]'];

  return (
    <tr className="auth-video-skeleton-row">
      <td className="text-center">
        <Skeleton className="mx-auto w-[18px]" />
      </td>
      <td>
        <Skeleton className={titleWidths[index % titleWidths.length]} />
      </td>
      <td>
        <Skeleton className="w-[54px]" />
      </td>
      <td>
        <div className="auth-editor-placeholder">
          <Skeleton box className="auth-editor-avatar" />
          <Skeleton className="w-[58px]" />
        </div>
      </td>
      <td>
        <Skeleton className="auth-skel-badge w-[44px]" />
      </td>
      <td>
        <Skeleton className="auth-skel-pill w-[62px]" />
      </td>
      <td>
        <Skeleton className="w-[48px]" />
      </td>
      <td>
        <Skeleton className="w-[48px]" />
      </td>
      <td>
        <Skeleton className="w-[48px]" />
      </td>
      <td>
        <Skeleton className="auth-skel-pill w-[82px]" />
      </td>
      <td>
        <Skeleton className="auth-skel-badge w-[36px]" />
      </td>
      <td>
        <div className="auth-note-placeholder">
          <Skeleton className={noteWidths[index % noteWidths.length]} />
          {index % 3 !== 1 ? <Skeleton className="w-[52%]" /> : null}
        </div>
      </td>
      <td className="text-center">
        <span className="auth-icon-placeholder" aria-hidden="true"><Link2 /></span>
      </td>
      <td className="text-center">
        <span className="auth-icon-placeholder" aria-hidden="true"><Trash2 /></span>
      </td>
    </tr>
  );
}

function VideoTableSkeleton() {
  return (
    <table className="ctable min-w-[1440px] auth-video-skeleton-table" data-tour="video-task-table">
      <thead>
        <tr>
          {TABLE_COLUMNS.map((column) => (
            <th key={column.label} className={column.className} style={{ width: column.width }}>
              {column.label}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {SKELETON_ROWS.map((index) => (
          <VideoSkeletonRow key={index} index={index} />
        ))}
      </tbody>
    </table>
  );
}

function DashboardSkeleton() {
  return (
    <div
      className="app-shell app-bg auth-dashboard-skeleton"
      aria-busy="true"
      aria-live="polite"
      aria-label="Đang tải dữ liệu"
    >
      <AuthSkeletonSidebar />
      <div className="app-main">
        <AuthSkeletonHeader />
        <main id="view" className="app-content">
          <div className="space-y-4" data-view="tasks">
            <AuthSkeletonFilters />
            <div className="card p-3 overflow-x-auto">
              <VideoTableSkeleton />
            </div>
          </div>
        </main>
        <footer
          className="app-footer"
          style={{ borderTop: '1px solid var(--border)' }}
        >
          CreativeHub | Developed by Doan Quoc Dat | v1.0.7
        </footer>
      </div>
    </div>
  );
}

export function AuthLoading() {
  return <DashboardSkeleton />;
}
