import { useIOSState } from './hooks/useIOSState';
import { IOSTestToolbar } from './components/IOSTestToolbar';
import { IOSFrame } from './components/IOSFrame';
import { IOSDashboardScreen } from './screens/IOSDashboardScreen';
import { IOSTasksScreen } from './screens/IOSTasksScreen';
import { IOSCalendarScreen } from './screens/IOSCalendarScreen';
import { IOSContentPlanScreen } from './screens/IOSContentPlanScreen';
import { IOSUsersScreen } from './screens/IOSUsersScreen';
import { IOSProfileScreen } from './screens/IOSProfileScreen';
import { IOSLoginScreen } from './screens/IOSLoginScreen';
import { IOSSheetRenderer } from './components/IOSSheetRenderer';
import './styles/ios.css';

export default function IOSPrototypeApp() {
  const iosState = useIOSState();
  const { currentTab, activeSheet } = iosState;

  // Screen meta mapping
  const screenMetaMap: Record<
    string,
    { title: string; rightAction?: 'add_task' | 'add_shoot' | 'add_content' | 'notification' | 'none' }
  > = {
    dashboard: { title: 'Tổng quan', rightAction: 'notification' },
    tasks: { title: 'Video tháng', rightAction: 'add_task' },
    calendar: { title: 'Lịch quay', rightAction: 'add_shoot' },
    content_plan: { title: 'Content Plan', rightAction: 'add_content' },
    users: { title: 'Nhân sự', rightAction: 'notification' },
    profile: { title: 'Cá nhân', rightAction: 'none' },
    login: { title: 'Đăng nhập', rightAction: 'none' },
  };

  const meta = screenMetaMap[currentTab] || { title: 'CreativeHub' };

  // Render current active tab screen
  const renderScreenContent = () => {
    switch (currentTab) {
      case 'dashboard':
        return <IOSDashboardScreen state={iosState} />;
      case 'tasks':
        return <IOSTasksScreen state={iosState} />;
      case 'calendar':
        return <IOSCalendarScreen state={iosState} />;
      case 'content_plan':
        return <IOSContentPlanScreen state={iosState} />;
      case 'users':
        return <IOSUsersScreen state={iosState} />;
      case 'profile':
        return <IOSProfileScreen state={iosState} />;
      case 'login':
        return <IOSLoginScreen state={iosState} />;
      default:
        return <IOSDashboardScreen state={iosState} />;
    }
  };

  // Sheet contents
  const sheetConfig = IOSSheetRenderer({ state: iosState });

  return (
    <div className="ios-prototype-root">
      {/* Outer Test Controls */}
      <IOSTestToolbar state={iosState} />

      {/* Main iPhone Frame & Viewport */}
      <div className="ios-viewport-wrapper">
        <IOSFrame
          state={iosState}
          title={meta.title}
          rightAction={meta.rightAction}
          sheetContent={
            sheetConfig
              ? {
                  isOpen: Boolean(activeSheet),
                  title: sheetConfig.title,
                  content: sheetConfig.content,
                }
              : undefined
          }
        >
          {renderScreenContent()}
        </IOSFrame>
      </div>
    </div>
  );
}
