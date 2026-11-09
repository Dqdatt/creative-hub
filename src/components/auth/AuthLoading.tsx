import { useIsMobile } from '../../hooks/useIsMobile';
import logoSymbol from '../../assets/logo.png';

const DESKTOP_NAV_ITEMS = Array.from({ length: 6 }, (_, index) => index);
const DESKTOP_ROWS = Array.from({ length: 8 }, (_, index) => index);

function Skeleton({ className = '', box = false }: { className?: string; box?: boolean }) {
  return <span className={`${box ? 'skel-box' : 'skel-line'} ${className}`} aria-hidden="true" />;
}

function DesktopBootSkeleton() {
  return (
    <div className="boot-desktop">
      <aside className="boot-sidebar" aria-hidden="true">
        <div className="boot-brand">
          <img src={logoSymbol} alt="" draggable={false} />
          <div className="boot-brand-copy">
            <Skeleton className="w-[98px]" />
            <Skeleton className="w-[64px]" />
          </div>
        </div>
        <div className="boot-nav">
          {DESKTOP_NAV_ITEMS.map((item) => (
            <div key={item} className={`boot-nav-item ${item === 2 ? 'is-active' : ''}`}>
              <Skeleton box className="boot-nav-icon" />
              <Skeleton className={item % 2 ? 'w-[104px]' : 'w-[82px]'} />
            </div>
          ))}
        </div>
        <div className="boot-sidebar-foot">
          <Skeleton box className="boot-avatar" />
          <div className="boot-brand-copy">
            <Skeleton className="w-[104px]" />
            <Skeleton className="w-[72px]" />
          </div>
        </div>
      </aside>

      <div className="boot-main">
        <header className="boot-topbar" aria-hidden="true">
          <Skeleton className="w-[132px]" />
          <div className="boot-topbar-actions">
            <Skeleton box className="boot-month" />
            <Skeleton box className="boot-circle" />
            <Skeleton box className="boot-circle" />
            <Skeleton box className="boot-avatar" />
          </div>
        </header>

        <main className="boot-content">
          <div className="boot-toolbar" aria-hidden="true">
            <Skeleton box className="boot-search" />
            <Skeleton box className="boot-filter" />
            <Skeleton box className="boot-filter" />
            <Skeleton box className="boot-add" />
          </div>
          <section className="boot-table" aria-hidden="true">
            <div className="boot-table-head">
              <Skeleton className="w-[24%]" />
              <Skeleton className="w-[12%]" />
              <Skeleton className="w-[16%]" />
              <Skeleton className="w-[10%]" />
              <Skeleton className="w-[18%]" />
            </div>
            {DESKTOP_ROWS.map((row) => (
              <div key={row} className="boot-table-row">
                <Skeleton className={row % 2 ? 'w-[28%]' : 'w-[34%]'} />
                <Skeleton className="w-[12%]" />
                <div className="boot-person"><Skeleton box className="boot-mini-avatar" /><Skeleton className="w-[70px]" /></div>
                <Skeleton box className="boot-pill" />
                <Skeleton className={row % 3 ? 'w-[16%]' : 'w-[11%]'} />
              </div>
            ))}
          </section>
        </main>
      </div>
    </div>
  );
}

function MobileNativeSplash() {
  return (
    <div className="native-splash" aria-hidden="true">
      <span className="native-splash-light" />
      <div className="native-splash-content">
        <div className="native-splash-mark">
          <span className="native-splash-mark-glow" />
          <img src={logoSymbol} alt="" draggable={false} />
        </div>
        <div className="native-splash-brand">
          <strong>CreativeHub</strong>
          <span>TEAM MARKETING</span>
        </div>
        <div className="native-splash-progress">
          <span />
        </div>
        <p>Đang chuẩn bị không gian làm việc</p>
      </div>
    </div>
  );
}

export function AuthLoading() {
  const isMobile = useIsMobile();

  return (
    <div
      className="auth-boot"
      role="status"
      aria-busy="true"
      aria-live="polite"
      aria-label="Đang khởi động CreativeHub"
    >
      <span className="sr-only">Đang khởi động CreativeHub...</span>
      {isMobile ? <MobileNativeSplash /> : <DesktopBootSkeleton />}
    </div>
  );
}
