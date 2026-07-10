import { Component } from 'react';
import type { ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, Home, RefreshCw } from 'lucide-react';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('App error boundary:', error, info);
  }

  private reloadPage = () => {
    window.location.reload();
  };

  private goHome = () => {
    window.location.assign('/');
  };

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <div className="app-bg error-boundary-screen">
        <section className="card error-boundary-card" role="alert">
          <span className="state-icon state-icon--error" aria-hidden="true">
            <AlertTriangle />
          </span>
          <div>
            <h1>Đã có lỗi xảy ra</h1>
            <p>Ứng dụng gặp sự cố khi hiển thị màn hình này. Vui lòng tải lại trang hoặc quay về trang chính.</p>
          </div>
          <div className="error-boundary-actions">
            <button type="button" className="btn" onClick={this.reloadPage}>
              <RefreshCw /> Tải lại trang
            </button>
            <button type="button" className="btn-ghost" onClick={this.goHome}>
              <Home /> Quay về trang chính
            </button>
          </div>
        </section>
      </div>
    );
  }
}
