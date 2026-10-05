import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { X } from 'lucide-react';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';

interface BottomSheetProps {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}

const EXIT_MS = 220;

// Sheet trượt từ dưới lên kiểu kính mờ. Giữ lại một nhịp khi đóng để chạy hiệu ứng ẩn.
export function BottomSheet({ open, title, onClose, children, footer }: BottomSheetProps) {
  const [mounted, setMounted] = useState(open);
  const [closing, setClosing] = useState(false);

  useEffect(() => {
    if (open) {
      setMounted(true);
      setClosing(false);
      return undefined;
    }
    if (!mounted) return undefined;
    setClosing(true);
    const timer = window.setTimeout(() => {
      setMounted(false);
      setClosing(false);
    }, EXIT_MS);
    return () => window.clearTimeout(timer);
  }, [mounted, open]);

  useEffect(() => {
    if (!open) return undefined;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose, open]);

  useDocumentScrollLock(mounted);

  if (!mounted) return null;

  return (
    <div className={`m-sheet-backdrop ${closing ? 'is-closing' : ''}`} onClick={onClose}>
      <section
        className="m-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="m-sheet-grabber" aria-hidden="true" />
        <header className="m-sheet-head">
          <h2>{title}</h2>
          <button type="button" className="m-sheet-close" aria-label="Đóng" onClick={onClose}>
            <X aria-hidden="true" />
          </button>
        </header>
        <div className="m-sheet-body">{children}</div>
        {footer ? <footer className="m-sheet-foot">{footer}</footer> : null}
      </section>
    </div>
  );
}
