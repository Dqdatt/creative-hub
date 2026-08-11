import { ChevronLeft, Plus, Bell } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import logoSymbol from '../../assets/logo.png';

interface IOSTopbarProps {
  state: IOSStateReturn;
  title: string;
  showBack?: boolean;
  onBack?: () => void;
  rightAction?: 'add_task' | 'add_shoot' | 'add_content' | 'notification' | 'none';
}

export function IOSTopbar({ state, title, showBack = false, onBack, rightAction = 'notification' }: IOSTopbarProps) {
  const { openSheet } = state;

  return (
    <header className="ios-topbar">
      {/* Left */}
      <div className="ios-topbar-left">
        {showBack ? (
          <button onClick={onBack} className="ios-back-btn" aria-label="Back">
            <ChevronLeft width={20} height={20} />
            <span>Trở về</span>
          </button>
        ) : (
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <img src={logoSymbol} alt="CreativeHub" style={{ width: 24, height: 24, objectFit: 'contain' }} />
          </div>
        )}
      </div>

      {/* Center Title */}
      <h1 className="ios-topbar-title">{title}</h1>

      {/* Right */}
      <div className="ios-topbar-right">
        {rightAction === 'add_task' && (
          <button onClick={() => openSheet('task_create')} className="ios-add-btn" aria-label="Tạo Task">
            <Plus width={16} height={16} strokeWidth={2.5} />
          </button>
        )}

        {rightAction === 'add_shoot' && (
          <button onClick={() => openSheet('shoot_create')} className="ios-add-btn" aria-label="Tạo Lịch Quay">
            <Plus width={16} height={16} strokeWidth={2.5} />
          </button>
        )}

        {rightAction === 'add_content' && (
          <button onClick={() => openSheet('content_plan_detail')} className="ios-add-btn" aria-label="Tạo Content">
            <Plus width={16} height={16} strokeWidth={2.5} />
          </button>
        )}

        {rightAction === 'notification' && (
          <button
            onClick={() => openSheet('more_menu')}
            className="ios-topbar-icon-btn"
            aria-label="Thông báo"
            style={{ position: 'relative' }}
          >
            <Bell width={16} height={16} />
            <span style={{
              position: 'absolute',
              top: 8, right: 8,
              width: 7, height: 7,
              borderRadius: '50%',
              background: '#EF4444',
              border: '1.5px solid #F8F9FB',
            }} />
          </button>
        )}

        {rightAction === 'none' && <div style={{ width: 36 }} />}
      </div>
    </header>
  );
}
