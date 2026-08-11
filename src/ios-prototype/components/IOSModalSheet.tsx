import { type ReactNode, useEffect } from 'react';
import { X } from 'lucide-react';

interface IOSModalSheetProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}

export function IOSModalSheet({ isOpen, onClose, title, children }: IOSModalSheetProps) {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    if (isOpen) window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop */}
      <div className="ios-sheet-backdrop" onClick={onClose} />

      {/* Sheet panel */}
      <div className="ios-sheet-container">
        <div className="ios-sheet-handle" />

        <div className="ios-sheet-header">
          <h2 className="ios-sheet-title">{title}</h2>
          <button onClick={onClose} className="ios-sheet-close-btn" aria-label="Close">
            <X width={14} height={14} />
          </button>
        </div>

        <div className="ios-sheet-body">{children}</div>
      </div>
    </>
  );
}
