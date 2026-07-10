import { createContext, useContext } from 'react';

export interface ConfirmOptions {
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: 'default' | 'danger';
}

export interface ConfirmDialogContextValue {
  requestConfirm: (options: ConfirmOptions) => Promise<boolean>;
}

export const ConfirmDialogContext = createContext<ConfirmDialogContextValue | undefined>(undefined);

export function useConfirmDialog() {
  const context = useContext(ConfirmDialogContext);
  if (!context) throw new Error('useConfirmDialog must be used inside ConfirmDialogProvider');
  return context;
}
