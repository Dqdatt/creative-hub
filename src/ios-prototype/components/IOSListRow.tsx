import type { ReactNode } from 'react';
import { ChevronRight } from 'lucide-react';

interface IOSListRowProps {
  title: ReactNode;
  subtitle?: ReactNode;
  leftElement?: ReactNode;
  rightElement?: ReactNode;
  onClick?: () => void;
  showChevron?: boolean;
  className?: string;
}

export function IOSListRow({
  title,
  subtitle,
  leftElement,
  rightElement,
  onClick,
  showChevron = true,
  className = '',
}: IOSListRowProps) {
  return (
    <div
      onClick={onClick}
      className={`flex items-center justify-between p-3 bg-[var(--surface)] border border-[var(--border)] rounded-2xl shadow-2xs hover:bg-[var(--chip)] active:scale-[0.99] transition-all cursor-pointer ${className}`}
    >
      <div className="flex items-center gap-3 min-w-0 flex-1">
        {leftElement && <div className="shrink-0">{leftElement}</div>}
        <div className="flex flex-col min-w-0 flex-1">
          <div className="text-xs font-semibold text-[var(--text)] truncate">{title}</div>
          {subtitle && <div className="text-[11px] text-[var(--text-2)] truncate mt-0.5">{subtitle}</div>}
        </div>
      </div>

      <div className="flex items-center gap-2 shrink-0 ml-2">
        {rightElement}
        {showChevron && <ChevronRight className="w-4 h-4 text-[var(--muted)]" />}
      </div>
    </div>
  );
}
