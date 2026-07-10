import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AlertTriangle, CheckCircle2, Info, X, XCircle } from 'lucide-react';
import { ToastContext } from './toastContext';
import type { ToastInput } from './toastContext';

interface ToastItem extends Required<Omit<ToastInput, 'durationMs'>> {
  id: string;
  isExiting: boolean;
}

const TOAST_ICON = {
  success: CheckCircle2,
  error: XCircle,
  info: Info,
  warning: AlertTriangle,
};

function createToastId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function getToastDuration(type: ToastItem['type'], durationMs?: number) {
  if (durationMs !== undefined) return durationMs;
  if (type === 'success') return 3000;
  if (type === 'warning') return 4000;
  if (type === 'error') return 6000;
  return 4000;
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const timersRef = useRef<Map<string, ReturnType<typeof window.setTimeout>>>(new Map());

  const removeToastNow = useCallback((id: string) => {
    const timer = timersRef.current.get(id);
    if (timer) window.clearTimeout(timer);
    timersRef.current.delete(id);
    setToasts((current) => current.filter((toast) => toast.id !== id));
  }, []);

  const dismissToast = useCallback((id: string) => {
    const timer = timersRef.current.get(id);
    if (timer) window.clearTimeout(timer);
    timersRef.current.delete(id);

    setToasts((current) =>
      current.map((toast) => toast.id === id ? { ...toast, isExiting: true } : toast)
    );
    window.setTimeout(() => removeToastNow(id), 220);
  }, [removeToastNow]);

  useEffect(() => () => {
    timersRef.current.forEach((timer) => window.clearTimeout(timer));
    timersRef.current.clear();
  }, []);

  const showToast = useCallback((toast: ToastInput) => {
    const id = createToastId();
    const type = toast.type ?? 'info';
    const nextToast: ToastItem = {
      id,
      type,
      title: toast.title ?? (type === 'success' ? 'Thành công' : type === 'error' ? 'Có lỗi xảy ra' : type === 'warning' ? 'Cần kiểm tra' : 'Thông tin'),
      message: toast.message,
      isExiting: false,
    };

    setToasts((current) => [nextToast, ...current].slice(0, 4));
    const duration = getToastDuration(type, toast.durationMs);
    if (duration > 0) {
      const timer = window.setTimeout(() => dismissToast(id), duration);
      timersRef.current.set(id, timer);
    }
  }, [dismissToast]);

  const value = useMemo(() => ({ showToast }), [showToast]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-stack" aria-live="polite" aria-atomic="false">
        {toasts.map((toast) => {
          const Icon = TOAST_ICON[toast.type];

          return (
            <div key={toast.id} className={`toast toast--${toast.type} ${toast.isExiting ? 'is-exiting' : ''}`}>
              <span className="toast-icon"><Icon /></span>
              <div className="min-w-0">
                <div className="toast-title">{toast.title}</div>
                <div className="toast-message">{toast.message}</div>
              </div>
              <button type="button" className="toast-close" onClick={() => dismissToast(toast.id)} aria-label="Đóng thông báo">
                <X />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}
