import { Clapperboard } from 'lucide-react';

export function AuthLoading() {
  return (
    <div id="loginGate">
      <div className="blob blob-a"></div>
      <div className="blob blob-b"></div>
      <div className="stage">
        <div className="lg-card">
          <div className="lg-brand">
            <div className="lg-mark">
              <Clapperboard />
            </div>
            <div className="lg-wordmark">CreativeHub<span>Team Marketing</span></div>
          </div>
          <h1>Đang kiểm tra phiên</h1>
          <div className="auth-loading-status">
            <span className="auth-pulse-dot"></span>
            <span>Vui lòng chờ trong giây lát.</span>
          </div>
        </div>
      </div>
    </div>
  );
}
