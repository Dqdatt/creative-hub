import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import { useDocumentScrollLock } from '../common/useDocumentScrollLock';
import { formatVietnameseMonth } from '../../utils/month';
import type { BrandKpiTarget } from '../../services/brandKpiService';

interface BrandKpiModalProps {
  isOpen: boolean;
  monthValue: string;
  target: BrandKpiTarget | null;
  onSave: (longVideos: number, motion: number) => Promise<void>;
  onClear: () => Promise<void>;
  onClose: () => void;
}

function parseCount(value: string) {
  if (!/^\d+$/.test(value.trim())) return null;
  return Number(value.trim());
}

export function BrandKpiModal({
  isOpen,
  monthValue,
  target,
  onSave,
  onClear,
  onClose,
}: BrandKpiModalProps) {
  const [longVideos, setLongVideos] = useState('');
  const [motion, setMotion] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useDocumentScrollLock(isOpen);

  // Nạp lại mỗi lần mở để không giữ số của tháng vừa xem trước đó.
  useEffect(() => {
    if (!isOpen) return;
    setLongVideos(target ? String(target.longVideos) : '');
    setMotion(target ? String(target.motion) : '');
    setError(null);
  }, [isOpen, target]);

  if (!isOpen) return null;

  const runAction = async (action: () => Promise<void>) => {
    setIsSaving(true);
    setError(null);
    try {
      await action();
      onClose();
    } catch (actionError) {
      setError(actionError instanceof Error ? actionError.message : 'Không thể lưu KPI.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    const parsedLong = parseCount(longVideos);
    const parsedMotion = parseCount(motion);

    if (parsedLong === null || parsedMotion === null) {
      setError('Chỉ tiêu phải là số nguyên không âm.');
      return;
    }

    void runAction(() => onSave(parsedLong, parsedMotion));
  };

  return createPortal(
    <div
      className="modal-overlay fixed inset-0 z-50 flex items-center justify-center px-4"
      onClick={(event) => { if (event.target === event.currentTarget && !isSaving) onClose(); }}
    >
      <form className="modal-card w-[94%] max-w-md p-5" onSubmit={handleSubmit}>
        <div className="mb-5 flex items-start justify-between gap-3">
          <div>
            <h2 className="text-[18px] font-extrabold leading-tight">Chỉ tiêu KPI BRAND</h2>
            <p className="text-[12.5px] text-sub mt-1">
              {formatVietnameseMonth(monthValue)} · chỉ tiêu tổng cho cả team.
            </p>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Đóng" disabled={isSaving}>
            <X />
          </button>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-1.5">
            <span className="text-[12.5px] font-semibold">Video dài</span>
            <input
              className="field"
              inputMode="numeric"
              value={longVideos}
              onChange={(event) => setLongVideos(event.target.value)}
              placeholder="0"
              autoFocus
            />
          </label>
          <label className="grid gap-1.5">
            <span className="text-[12.5px] font-semibold">Motion</span>
            <input
              className="field"
              inputMode="numeric"
              value={motion}
              onChange={(event) => setMotion(event.target.value)}
              placeholder="0"
            />
          </label>
        </div>

        {error ? <p className="mt-3 text-[12.5px] font-semibold text-[var(--danger)]">{error}</p> : null}

        <div className="mt-5 flex flex-wrap items-center justify-end gap-2">
          {target ? (
            <button
              type="button"
              className="btn-ghost mr-auto"
              onClick={() => void runAction(onClear)}
              disabled={isSaving}
            >
              Xóa chỉ tiêu
            </button>
          ) : null}
          <button type="button" className="btn-ghost" onClick={onClose} disabled={isSaving}>
            Hủy
          </button>
          <button type="submit" className="btn btn-sm" disabled={isSaving}>
            {isSaving ? 'Đang lưu...' : 'Lưu KPI'}
          </button>
        </div>
      </form>
    </div>,
    document.body
  );
}
