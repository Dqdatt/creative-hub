import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AlertCircle, Eye, EyeOff } from 'lucide-react';
import { useAuth } from '../context/authContext';
import './Login.css';

export default function Login() {
  const navigate = useNavigate();
  const { signIn, authError, configError, clearAuthError } = useAuth();
  const [showPass, setShowPass] = useState(false);
  const [email, setEmail] = useState('');
  const [pass, setPass] = useState('');
  const [submitting, setSubmitting] = useState(false);
  
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submitting) return;

    setSubmitting(true);
    const { error, defaultRoute } = await signIn(email, pass);
    setSubmitting(false);
    if (!error && defaultRoute) navigate(defaultRoute, { replace: true });
  };

  const visibleError = authError ?? configError;

  return (
    <div id="loginGate">
      <div className="blob blob-a"></div>
      <div className="blob blob-b"></div>
      <div className="blob blob-c"></div>
      <div className="sprockets tl"><span></span><span></span><span></span><span></span><span></span><span></span></div>
      <div className="sprockets br"><span></span><span></span><span></span><span></span><span></span><span></span></div>

      <div className="stage">
        <form className="lg-card" onSubmit={handleLogin}>
          <div className="lg-brand">
            <div className="lg-mark">
              <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20.2 6 3 11l-.9-2.4c-.3-1.1.3-2.2 1.3-2.5l13.5-4c1.1-.3 2.2.3 2.5 1.3Z"/><path d="m6.2 5.3 3.1 3.9"/><path d="m12.4 3.4 3.1 4"/><path d="M3 11h18v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>
              </svg>
            </div>
            <div className="lg-wordmark">CreativeHub<span>Team Marketing</span></div>
          </div>

          <h1>Đăng nhập</h1>

          <label className="lg-flabel" htmlFor="loginEmail">Email</label>
          <div className="field-wrap">
            <input
              id="loginEmail"
              name="email"
              type="email"
              value={email}
              onChange={(e) => {
                clearAuthError();
                setEmail(e.target.value);
              }}
              className={`lg-field ${visibleError ? 'err' : ''}`}
              placeholder="ten@congty.com"
              autoComplete="email"
              required
              disabled={submitting}
            />
          </div>

          <label className="lg-flabel" htmlFor="loginPassword">Mật khẩu</label>
          <div className="field-wrap">
            <input
              id="loginPassword"
              name="password"
              type={showPass ? 'text' : 'password'}
              value={pass}
              onChange={(e) => {
                clearAuthError();
                setPass(e.target.value);
              }}
              className={`lg-field has-icon ${visibleError ? 'err' : ''}`}
              placeholder="Nhập mật khẩu"
              autoComplete="current-password"
              required
              disabled={submitting}
            />
            <button type="button" className="eye-btn" onClick={() => setShowPass(!showPass)} disabled={submitting} aria-label={showPass ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}>
              {showPass ? <EyeOff className="w-[17px] h-[17px]" /> : <Eye className="w-[17px] h-[17px]" />}
            </button>
          </div>

          <div className={`lg-err ${visibleError ? 'show' : ''}`} role="alert">
            <AlertCircle />
            <span>{visibleError}</span>
          </div>

          <div className="row-between">
            <label className="remember is-disabled"><input type="checkbox" checked disabled /> Duy trì phiên đăng nhập</label>
            <button type="button" className="forgot" onClick={() => clearAuthError()}>Quên mật khẩu?</button>
          </div>

          <button type="submit" className="btn-primary" disabled={submitting || Boolean(configError)}>
            <span>{submitting ? 'Đang đăng nhập...' : 'Đăng nhập'}</span>
          </button>

          <p className="foot-note">Chưa có tài khoản? <a href="mailto:admin@creativehub.vn">Liên hệ quản trị viên</a></p>
        </form>
      </div>
    </div>
  );
}
