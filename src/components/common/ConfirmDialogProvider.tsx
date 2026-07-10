import { useCallback, useMemo, useState } from 'react';
import { AlertTriangle, X } from 'lucide-react';
import { ConfirmDialogContext } from './confirmDialogContext';
import type { ConfirmOptions } from './confirmDialogContext';

interface ConfirmState extends Required<Omit<ConfirmOptions, 'description'>> {
  description: string;
  resolve: (confirmed: boolean) => void;
}

export function ConfirmDialogProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ConfirmState | null>(null);

  const close = useCallback((confirmed: boolean) => {
    setState((current) => {
      current?.resolve(confirmed);
      return null;
    });
  }, []);

  const requestConfirm = useCallback((options: ConfirmOptions) => new Promise<boolean>((resolve) => {
    setState({
      title: options.title,
      description: options.description ?? '',
      confirmLabel: options.confirmLabel ?? 'Xác nhận',
      cancelLabel: options.cancelLabel ?? 'Hủy',
      variant: options.variant ?? 'default',
      resolve,
    });
  }), []);

  const value = useMemo(() => ({ requestConfirm }), [requestConfirm]);

  return (
    <ConfirmDialogContext.Provider value={value}>
      {children}
      {state ? (
        <div
          className="modal-overlay fixed inset-0 z-[70] flex items-center justify-center p-4"
          onMouseDown={(event) => { if (event.target === event.currentTarget) close(false); }}
        >
          <section className="modal-card confirm-card" role="dialog" aria-modal="true" aria-labelledby="confirmDialogTitle">
            <div className="confirm-head">
              <span className={`confirm-icon confirm-icon--${state.variant}`}>
                <AlertTriangle />
              </span>
              <button type="button" className="icon-btn" onClick={() => close(false)} aria-label="Đóng">
                <X />
              </button>
            </div>

            <h2 id="confirmDialogTitle" className="confirm-title">{state.title}</h2>
            {state.description ? (
              <p className="confirm-desc">{state.description}</p>
            ) : null}

            <div className="confirm-actions">
              <button type="button" className="btn-ghost" onClick={() => close(false)}>
                {state.cancelLabel}
              </button>
              <button
                type="button"
                className={state.variant === 'danger' ? 'btn btn-danger' : 'btn'}
                onClick={() => close(true)}
              >
                {state.confirmLabel}
              </button>
            </div>
          </section>
        </div>
      ) : null}
    </ConfirmDialogContext.Provider>
  );
}
