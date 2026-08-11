import { LayoutDashboard, Clapperboard, Plus, CalendarDays, UserRound } from 'lucide-react';
import type { IOSStateReturn, IOSTab } from '../hooks/useIOSState';

interface IOSBottomNavProps {
  state: IOSStateReturn;
}

// 5-tab layout: dashboard | tasks | [+] | calendar | profile
const LEFT_TABS: Array<{ id: IOSTab; label: string; icon: typeof LayoutDashboard }> = [
  { id: 'dashboard', label: 'Tổng quan', icon: LayoutDashboard },
  { id: 'tasks', label: 'Video', icon: Clapperboard },
];

const RIGHT_TABS: Array<{ id: IOSTab; label: string; icon: typeof LayoutDashboard }> = [
  { id: 'calendar', label: 'Lịch quay', icon: CalendarDays },
  { id: 'profile', label: 'Cá nhân', icon: UserRound },
];

export function IOSBottomNav({ state }: IOSBottomNavProps) {
  const { currentTab, setCurrentTab, openSheet } = state;

  const renderTab = (tab: { id: IOSTab; label: string; icon: typeof LayoutDashboard }) => {
    const Icon = tab.icon;
    const isActive = currentTab === tab.id;

    return (
      <button
        key={tab.id}
        onClick={() => setCurrentTab(tab.id)}
        className={`ios-nav-tab ${isActive ? 'active' : ''}`}
        aria-label={tab.label}
      >
        <Icon
          width={22}
          height={22}
          strokeWidth={isActive ? 2.5 : 1.8}
          style={{ transition: 'stroke-width 0.15s' }}
        />
        <span>{tab.label}</span>
      </button>
    );
  };

  return (
    <nav className="ios-bottom-bar">
      {LEFT_TABS.map(renderTab)}

      {/* Center + button */}
      <button
        className="ios-nav-center-btn"
        onClick={() => openSheet('task_create')}
        aria-label="Tạo mới"
      >
        <Plus width={22} height={22} strokeWidth={2.5} />
      </button>

      {RIGHT_TABS.map(renderTab)}
    </nav>
  );
}
