import { AlertTriangle, ExternalLink } from 'lucide-react';

interface AttentionCardProps {
  pendingVideos: number;
  overdueVideos: number;
  doneWithoutResultLinks: number;
  onOpenPending: () => void;
  onOpenOverdue: () => void;
  onOpenMissingLinks: () => void;
}

export function AttentionCard({
  pendingVideos,
  overdueVideos,
  doneWithoutResultLinks,
  onOpenPending,
  onOpenOverdue,
  onOpenMissingLinks,
}: AttentionCardProps) {
  const items = [
    { label: 'Pending', value: pendingVideos, action: onOpenPending },
    { label: 'Quá hạn', value: overdueVideos, action: onOpenOverdue },
    { label: 'Xong thiếu link', value: doneWithoutResultLinks, action: onOpenMissingLinks },
  ];

  return (
    <section className="card dashboard-attention p-5">
      <div className="section-eyebrow p-0">
        <span className="icoc" style={{ background: 'color-mix(in srgb,var(--warning) 14%,transparent)', color: 'var(--warning)' }}>
          <AlertTriangle />
        </span>
        <div>
          <h2 className="text-[17px] font-extrabold leading-none tracking-tight">Cần chú ý</h2>
          <p className="text-[12.5px] text-sub mt-1.5">Các đầu việc cần rà soát trong tháng.</p>
        </div>
      </div>

      <div className="mt-4 grid gap-3 md:grid-cols-3">
        {items.map((item) => (
          <button
            key={item.label}
            type="button"
            className="attention-action"
            onClick={item.action}
          >
            <span>
              <strong>{item.value}</strong>
              <em>{item.label}</em>
            </span>
            <ExternalLink />
          </button>
        ))}
      </div>
    </section>
  );
}
