import { AlarmClock, Hourglass, Link2Off } from 'lucide-react';
import { MetricTile } from './MetricTile';
import { SectionCard } from './SectionCard';

interface AttentionSectionProps {
  pendingVideos: number;
  overdueVideos: number;
  doneWithoutResultLinks: number;
  onOpenWaiting: () => void;
  onOpenOverdue: () => void;
  onOpenMissingLinks: () => void;
}

export function AttentionSection({
  pendingVideos,
  overdueVideos,
  doneWithoutResultLinks,
  onOpenWaiting,
  onOpenOverdue,
  onOpenMissingLinks,
}: AttentionSectionProps) {
  return (
    <SectionCard title="Cần xử lý" subtitle="Bấm vào một ô để mở đúng danh sách việc.">
      <div className="tile-grid">
        <MetricTile
          icon={Hourglass}
          value={pendingVideos}
          label="Chờ nhận việc"
          hint="Video đang ở trạng thái Chờ."
          onClick={onOpenWaiting}
        />
        <MetricTile
          icon={AlarmClock}
          value={overdueVideos}
          label="Trễ hạn trả"
          hint="Chưa xong mà đã qua hạn trả."
          onClick={onOpenOverdue}
        />
        <MetricTile
          icon={Link2Off}
          value={doneWithoutResultLinks}
          label="Xong, thiếu link"
          hint="Đã xong nhưng chưa điền Link thành phẩm."
          onClick={onOpenMissingLinks}
        />
      </div>
    </SectionCard>
  );
}
