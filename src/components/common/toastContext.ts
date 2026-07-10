import { createContext, useContext } from 'react';

export type ToastType = 'success' | 'error' | 'info' | 'warning';

export interface ToastInput {
  type?: ToastType;
  title?: string;
  message: string;
  durationMs?: number;
}

export interface ToastContextValue {
  showToast: (toast: ToastInput) => void;
}

export const ToastContext = createContext<ToastContextValue | undefined>(undefined);

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) throw new Error('useToast must be used inside ToastProvider');
  return context;
}
