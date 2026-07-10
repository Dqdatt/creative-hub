import { AlertTriangle } from 'lucide-react';

interface ErrorStateProps {
  title?: string;
  message?: string;
  description?: string;
  onRetry?: () => void;
  retryLabel?: string;
}

export function ErrorState({ title = 'Không thể tải dữ liệu', message, description, onRetry, retryLabel = 'Tải lại' }: ErrorStateProps) {
  const detail = description ?? message;

  return (
    <div className="card state-card state-card--error">
      <span className="state-icon state-icon--error" aria-hidden="true">
        <AlertTriangle />
      </span>
      <div className="min-w-0 flex-1">
        <p className="state-title">{title}</p>
        {detail ? <p className="state-desc">{detail}</p> : null}
      </div>
      {onRetry ? (
        <button type="button" className="btn-ghost" onClick={onRetry}>
          {retryLabel}
        </button>
      ) : null}
    </div>
  );
}
