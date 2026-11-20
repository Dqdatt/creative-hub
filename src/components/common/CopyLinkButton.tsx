import { useState, useRef, useEffect, type MouseEvent } from 'react';
import { Copy, Check } from 'lucide-react';
import { useToast } from './toastContext';

export interface CopyLinkButtonProps {
  link: string;
  className: string;
  label: string;
  iconSize?: number;
}

export function CopyLinkButton({ link, className, label, iconSize }: CopyLinkButtonProps) {
  const { showToast } = useToast();
  const [copied, setCopied] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, []);

  const handleCopy = async (event: MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    event.preventDefault();

    if (!navigator?.clipboard?.writeText) {
      showToast({ type: 'error', message: 'Không copy được link.' });
      return;
    }

    try {
      await navigator.clipboard.writeText(link);
      setCopied(true);
      showToast({ type: 'success', message: 'Đã copy link.' });

      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      timerRef.current = setTimeout(() => {
        setCopied(false);
      }, 1500);
    } catch {
      showToast({ type: 'error', message: 'Không copy được link.' });
    }
  };

  const Icon = copied ? Check : Copy;

  return (
    <button
      type="button"
      className={className}
      title="Copy link"
      aria-label={label}
      onClick={handleCopy}
    >
      <Icon size={iconSize} aria-hidden="true" />
    </button>
  );
}
