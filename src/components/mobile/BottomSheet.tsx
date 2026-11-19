import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent, ReactNode } from 'react';
import { X } from 'lucide-react';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';

interface BottomSheetProps {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}

interface DragState {
  pointerId: number;
  startY: number;
  lastY: number;
  lastTime: number;
  velocity: number;
  dy: number;
}

const EXIT_MS = 220;
const DRAG_CLOSE_DISTANCE = 96;
const DRAG_CLOSE_VELOCITY = 0.6;
const DRAG_IDLE_TIMEOUT_MS = 100;

// Sheet trượt từ dưới lên kiểu kính mờ. Giữ lại một nhịp khi đóng để chạy hiệu ứng ẩn.
export function BottomSheet({ open, title, onClose, children, footer }: BottomSheetProps) {
  const [mounted, setMounted] = useState(open);
  const [closing, setClosing] = useState(false);
  const sheetRef = useRef<HTMLElement>(null);
  const dragRef = useRef<DragState | null>(null);

  useEffect(() => {
    const sheet = sheetRef.current;
    if (open) {
      dragRef.current = null;
      if (sheet) {
        sheet.classList.remove('is-dragging', 'is-settled');
        sheet.removeAttribute('data-dragged');
        sheet.style.transform = '';
      }
      setMounted(true);
      setClosing(false);
      return undefined;
    }
    if (!mounted) return undefined;
    dragRef.current = null;
    if (sheet) {
      sheet.classList.remove('is-dragging');
      if (!sheet.hasAttribute('data-dragged')) sheet.style.transform = '';
    }
    setClosing(true);
    const timer = window.setTimeout(() => {
      dragRef.current = null;
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

  const handlePointerDown = (event: ReactPointerEvent<HTMLElement>) => {
    if (dragRef.current) return;
    if (closing || !open) return;
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    const target = event.target instanceof Element ? event.target : null;
    if (!target || !target.closest('.m-sheet-grabber, .m-sheet-head') || target.closest('button')) return;

    const now = performance.now();
    dragRef.current = {
      pointerId: event.pointerId,
      startY: event.clientY,
      lastY: event.clientY,
      lastTime: now,
      velocity: 0,
      dy: 0,
    };
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Bỏ qua nếu pointerId không hỗ trợ capture (ví dụ sự kiện giả lập).
    }
  };

  const handlePointerMove = (event: ReactPointerEvent<HTMLElement>) => {
    const drag = dragRef.current;
    const sheet = sheetRef.current;
    if (!drag || !sheet || event.pointerId !== drag.pointerId) return;

    const now = performance.now();
    const dt = now - drag.lastTime;
    if (dt > 0) {
      const instantVelocity = (event.clientY - drag.lastY) / dt;
      drag.velocity = drag.velocity === 0 ? instantVelocity : drag.velocity * 0.4 + instantVelocity * 0.6;
      drag.lastY = event.clientY;
      drag.lastTime = now;
    }

    const dy = Math.max(0, event.clientY - drag.startY);
    drag.dy = dy;
    sheet.classList.add('is-dragging', 'is-settled');
    sheet.style.transform = `translateY(${dy}px)`;
  };

  const handlePointerEnd = (event: ReactPointerEvent<HTMLElement>) => {
    const drag = dragRef.current;
    const sheet = sheetRef.current;
    if (!drag || !sheet || event.pointerId !== drag.pointerId) return;

    dragRef.current = null;
    try {
      if (event.currentTarget.hasPointerCapture(event.pointerId)) {
        event.currentTarget.releasePointerCapture(event.pointerId);
      }
    } catch {
      // Bỏ qua nếu capture đã được trình duyệt giải phóng.
    }

    const isCancel = event.type === 'pointercancel';
    const dy = isCancel ? drag.dy : Math.max(0, event.clientY - drag.startY);
    const idleMs = performance.now() - drag.lastTime;
    let velocity = idleMs > DRAG_IDLE_TIMEOUT_MS ? 0 : drag.velocity;
    if (!isCancel && event.clientY !== drag.lastY && idleMs > 0 && idleMs <= DRAG_IDLE_TIMEOUT_MS) {
      const tailVelocity = (event.clientY - drag.lastY) / idleMs;
      velocity = velocity === 0 ? tailVelocity : velocity * 0.4 + tailVelocity * 0.6;
    }

    sheet.classList.remove('is-dragging');
    if (dy > DRAG_CLOSE_DISTANCE || velocity > DRAG_CLOSE_VELOCITY) {
      sheet.setAttribute('data-dragged', '');
      onClose();
      return;
    }
    sheet.style.transform = '';
  };

  if (!mounted) return null;

  return (
    <div className={`m-sheet-backdrop ${closing ? 'is-closing' : ''}`} onClick={onClose}>
      <section
        ref={sheetRef}
        className="m-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerEnd}
        onPointerCancel={handlePointerEnd}
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
