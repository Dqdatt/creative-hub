import { Inbox } from 'lucide-react';

interface EmptyStateProps {
  title?: string;
  message?: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({ title, message, description, actionLabel, onAction }: EmptyStateProps) {
  const displayTitle = title ?? message ?? 'Chưa có dữ liệu';
  const displayDescription = description ?? (title ? message : undefined);

  return (
    <div className="card state-card state-card--empty">
      <span className="state-icon" aria-hidden="true">
        <Inbox />
      </span>
      <div className="min-w-0 flex-1">
        <p className="state-title">{displayTitle}</p>
        {displayDescription ? <p className="state-desc">{displayDescription}</p> : null}
      </div>
      {actionLabel && onAction ? (
        <button type="button" className="btn-ghost" onClick={onAction}>
          {actionLabel}
        </button>
      ) : null}
    </div>
  );
}
