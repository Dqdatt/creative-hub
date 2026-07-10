type LoadingStateProps =
  | {
      variant: 'table';
      message: string;
      colSpan: number;
      minWidthClass: string;
      rows?: number;
    }
  | {
      variant: 'block';
      message: string;
      className: string;
      shape?: 'card' | 'calendar' | 'dashboard' | 'profile';
    };

function SkeletonLine({ className = '' }: { className?: string }) {
  return <span className={`skel-line ${className}`} aria-hidden="true" />;
}

function renderTableSkeleton(rows = 6, colSpan: number) {
  return Array.from({ length: rows }).map((_, index) => (
    <tr key={index}>
      <td colSpan={colSpan} className="skeleton-table-cell">
        <div className="skeleton-table-row">
          <span className="skel-dot" aria-hidden="true" />
          <SkeletonLine className="w-[28%]" />
          <SkeletonLine className="w-[12%]" />
          <SkeletonLine className="w-[18%]" />
          <SkeletonLine className="w-[10%]" />
          <SkeletonLine className="w-[14%]" />
        </div>
      </td>
    </tr>
  ));
}

export function LoadingState(props: LoadingStateProps) {
  if (props.variant === 'table') {
    return (
      <table className={`ctable skeleton-table ${props.minWidthClass}`} aria-label={props.message}>
        <tbody>
          {renderTableSkeleton(props.rows ?? 6, props.colSpan)}
        </tbody>
      </table>
    );
  }

  if (props.shape === 'dashboard') {
    return (
      <div className={`skeleton-dashboard ${props.className}`} aria-label={props.message}>
        <div className="skeleton-kpis">
          {Array.from({ length: 3 }).map((_, index) => (
            <div key={index} className="card skeleton-card">
              <span className="skel-box skel-icon" />
              <div className="min-w-0 flex-1">
                <SkeletonLine className="w-[46%]" />
                <SkeletonLine className="mt-3 w-[72%]" />
              </div>
              <SkeletonLine className="w-[42px]" />
            </div>
          ))}
        </div>
        <div className="skeleton-workload">
          {Array.from({ length: 3 }).map((_, index) => (
            <div key={index} className="card skeleton-editor-card">
              <div className="flex items-center gap-3">
                <span className="skel-box skel-avatar" />
                <div className="min-w-0 flex-1">
                  <SkeletonLine className="w-[58%]" />
                  <SkeletonLine className="mt-3 w-[36%]" />
                </div>
                <SkeletonLine className="w-[34px]" />
              </div>
              <div className="mt-5 space-y-3">
                <SkeletonLine className="w-full" />
                <SkeletonLine className="w-[92%]" />
                <SkeletonLine className="w-[84%]" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (props.shape === 'calendar') {
    return (
      <div className={`skeleton-calendar ${props.className}`} aria-label={props.message}>
        {Array.from({ length: 49 }).map((_, index) => (
          <div key={index} className={index < 7 ? 'skeleton-cal-head' : 'skeleton-cal-cell'}>
            {index >= 7 ? (
              <>
                <SkeletonLine className="w-[22px]" />
                <SkeletonLine className="mt-3 w-[74%]" />
                <SkeletonLine className="mt-2 w-[58%]" />
              </>
            ) : null}
          </div>
        ))}
      </div>
    );
  }

  if (props.shape === 'profile') {
    return (
      <div className={`skeleton-profile card ${props.className}`} aria-label={props.message}>
        <div className="skeleton-profile-side">
          <span className="skel-box skel-profile-avatar" />
          <SkeletonLine className="w-[72%]" />
          <SkeletonLine className="w-[86%]" />
          <div className="flex gap-2">
            <SkeletonLine className="w-[72px]" />
            <SkeletonLine className="w-[96px]" />
          </div>
        </div>
        <div className="skeleton-profile-form">
          <SkeletonLine className="w-[180px]" />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {Array.from({ length: 6 }).map((_, index) => (
              <div key={index}>
                <SkeletonLine className="w-[84px]" />
                <span className="skel-field mt-2" />
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`skeleton-block ${props.className}`} aria-label={props.message}>
      <SkeletonLine className="w-[34%]" />
      <SkeletonLine className="w-[62%]" />
      <SkeletonLine className="w-[48%]" />
    </div>
  );
}
