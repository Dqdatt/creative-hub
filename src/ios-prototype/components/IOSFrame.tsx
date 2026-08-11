import type { ReactNode } from 'react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import { IOSTopbar } from './IOSTopbar';
import { IOSBottomNav } from './IOSBottomNav';
import { IOSModalSheet } from './IOSModalSheet';

interface IOSFrameProps {
  state: IOSStateReturn;
  title: string;
  children: ReactNode;
  showBack?: boolean;
  onBack?: () => void;
  rightAction?: 'add_task' | 'add_shoot' | 'add_content' | 'notification' | 'none';
  sheetContent?: {
    isOpen: boolean;
    title: string;
    content: ReactNode;
  };
}

export function IOSFrame({
  state,
  title,
  children,
  showBack = false,
  onBack,
  rightAction = 'notification',
  sheetContent,
}: IOSFrameProps) {
  const { viewScale, closeSheet } = state;

  return (
    <div
      className={`ios-device-frame transition-transform duration-300`}
      style={{ transform: viewScale === 'fit' ? 'scale(0.9)' : 'scale(1)', transformOrigin: 'top center' }}
    >
      {/* Dynamic Island */}
      <div className="ios-dynamic-island" />

      {/* iOS Status Bar */}
      <div className="ios-status-bar">
        <span className="ios-status-bar-time">9:41</span>
        <div className="ios-status-bar-icons">
          <div className="ios-status-icon-signal">
            <span /><span /><span /><span />
          </div>
          {/* WiFi icon (simple SVG) */}
          <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor" style={{ color: 'var(--sb-icon, #111)', transition: 'color 0.3s' }}>
            <path d="M8 9.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zm0-3.5a5.5 5.5 0 014.33 2.1.75.75 0 11-1.18.93A4 4 0 008 7.5a4 4 0 00-3.15 1.53.75.75 0 11-1.18-.93A5.5 5.5 0 018 6zm0-3.5a9 9 0 016.93 3.27.75.75 0 11-1.16.96A7.5 7.5 0 008 4.5a7.5 7.5 0 00-5.77 2.23.75.75 0 11-1.16-.96A9 9 0 018 2.5z"/>
          </svg>
          <div className="ios-battery">
            <div className="ios-battery-fill" />
          </div>
        </div>
      </div>

      {/* Topbar */}
      <IOSTopbar state={state} title={title} showBack={showBack} onBack={onBack} rightAction={rightAction} />

      {/* Main Body Content */}
      <main className="ios-body-content">{children}</main>

      {/* Bottom Nav */}
      <IOSBottomNav state={state} />

      {/* Home Indicator */}
      <div className="ios-home-indicator" />

      {/* Bottom Modal Sheet */}
      {sheetContent && (
        <IOSModalSheet isOpen={sheetContent.isOpen} onClose={closeSheet} title={sheetContent.title}>
          {sheetContent.content}
        </IOSModalSheet>
      )}
    </div>
  );
}
