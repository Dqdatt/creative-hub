import { useState } from 'react';
import { Mail, Lock, LogIn, CheckCircle2 } from 'lucide-react';
import type { IOSStateReturn } from '../hooks/useIOSState';
import logoSymbol from '../../assets/logo.png';

interface Props { state: IOSStateReturn }

export function IOSLoginScreen({ state }: Props) {
  const { setCurrentTab } = state;
  const [email, setEmail] = useState('dat.dq@company.com');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setTimeout(() => { setIsSubmitting(false); setCurrentTab('dashboard'); }, 700);
  };

  return (
    <div className="ios-screen-enter" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: 580, padding: '0 24px', gap: 24 }}>
      {/* Brand Header */}
      <div style={{ textAlign: 'center' }}>
        <div style={{ width: 72, height: 72, borderRadius: 22, background: '#fff', padding: 14, boxShadow: '0 6px 24px rgba(0,0,0,0.1)', border: '1px solid rgba(0,0,0,0.06)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
          <img src={logoSymbol} alt="CreativeHub" style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
        </div>
        <h1 style={{ fontSize: 24, fontWeight: 800, color: '#111', letterSpacing: -0.5, margin: '0 0 6px', transition: 'color 0.3s' }}>CreativeHub Ops</h1>
        <p style={{ fontSize: 13, color: '#9AA0B2', margin: 0, maxWidth: 240 }}>Hệ thống quản lý Video Task & Lịch quay</p>
      </div>

      {/* Form Card */}
      <form
        onSubmit={handleSubmit}
        style={{ width: '100%', background: '#fff', borderRadius: 24, padding: '24px 20px', boxShadow: '0 4px 24px rgba(0,0,0,0.08)', border: '1px solid rgba(0,0,0,0.05)', display: 'flex', flexDirection: 'column', gap: 16 }}
      >
        {/* Email field */}
        <div>
          <label className="ios-field-label">Email công việc</label>
          <div style={{ position: 'relative' }}>
            <Mail width={15} height={15} color="#9AA0B2" style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} />
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="ios-field"
              style={{ paddingLeft: 36 }}
              required
              placeholder="email@company.com"
            />
          </div>
        </div>

        {/* Password field */}
        <div>
          <label className="ios-field-label">Mật khẩu</label>
          <div style={{ position: 'relative' }}>
            <Lock width={15} height={15} color="#9AA0B2" style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} />
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="ios-field"
              style={{ paddingLeft: 36 }}
              placeholder="••••••••"
            />
          </div>
        </div>

        {/* Forgot password */}
        <div style={{ textAlign: 'right', marginTop: -8 }}>
          <button type="button" style={{ fontSize: 12.5, fontWeight: 700, color: '#7C5CFF', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>
            Quên mật khẩu?
          </button>
        </div>

        {/* Submit */}
        <button type="submit" disabled={isSubmitting} className="ios-primary-btn">
          {isSubmitting ? (
            <div style={{ width: 18, height: 18, border: '2.5px solid rgba(255,255,255,0.4)', borderTopColor: '#fff', borderRadius: '50%', animation: 'spin 0.7s linear infinite', margin: '0 auto' }} />
          ) : (
            <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
              <LogIn width={16} height={16} />
              Đăng nhập
            </span>
          )}
        </button>
      </form>

      {/* Security note */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5, color: '#9AA0B2', fontWeight: 500 }}>
        <CheckCircle2 width={14} height={14} color="#22C55E" />
        <span>Bảo mật 2FA • Xác thực Supabase Auth</span>
      </div>
    </div>
  );
}
