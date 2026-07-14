import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { AlertTriangle, X } from 'lucide-react';
import { ConfirmDialogContext } from './confirmDialogContext';
import type { ConfirmOptions } from './confirmDialogContext';
import { useDocumentScrollLock } from './useDocumentScrollLock';

interface ConfirmState extends Required<Omit<ConfirmOptions, 'description'>> {
  description: string;
  resolve: (confirmed: boolean) => void;
}

export function ConfirmDialogProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ConfirmState | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useDocumentScrollLock(Boolean(state));

  const close = useCallback((confirmed: boolean) => {
    setState((current) => {
      current?.resolve(confirmed);
      return null;
    });

    window.requestAnimationFrame(() => {
      if (previousFocusRef.current?.isConnected) {
        previousFocusRef.current.focus();
      }
      previousFocusRef.current = null;
    });
  }, []);

  const requestConfirm = useCallback((options: ConfirmOptions) => new Promise<boolean>((resolve) => {
    previousFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    setState({
      title: options.title,
      description: options.description ?? '',
      confirmLabel: options.confirmLabel ?? 'Xác nhận',
      cancelLabel: options.cancelLabel ?? 'Hủy',
      variant: options.variant ?? 'default',
      resolve,
    });
  }), []);

  useEffect(() => {
    if (!state) return undefined;

    window.requestAnimationFrame(() => cancelRef.current?.focus());

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      event.stopImmediatePropagation();
      close(false);
    };

    document.addEventListener('keydown', handleKeyDown, true);
    return () => document.removeEventListener('keydown', handleKeyDown, true);
  }, [close, state]);

  const value = useMemo(() => ({ requestConfirm }), [requestConfirm]);

  return (
    <ConfirmDialogContext.Provider value={value}>
      {children}
      {state ? createPortal(
        <div
          className="modal-overlay modal-overlay--nested fixed inset-0 z-[70] flex items-center justify-center p-4"
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
              <button ref={cancelRef} type="button" className="btn-ghost" onClick={() => close(false)}>
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
        </div>,
        document.body
      ) : null}
    </ConfirmDialogContext.Provider>
  );
}
