import { AlertTriangle, CircleCheck, Clapperboard, FileText, Gauge, Video } from 'lucide-react';
import type { DashboardMetrics } from '../../hooks/useDashboard';
import { formatVietnameseMonth, monthValueToDate } from '../../utils/month';
import { MetricTile } from './MetricTile';
import { SectionCard } from './SectionCard';

interface OverviewSectionProps {
  monthValue: string;
  metrics: DashboardMetrics;
  editorCount: number;
  canCreateReport: boolean;
  onOpenReport: () => void;
}

export function OverviewSection({
  monthValue,
  metrics,
  editorCount,
  canCreateReport,
  onOpenReport,
}: OverviewSectionProps) {
  const monthDate = monthValueToDate(monthValue);
  const previousLabel = formatVietnameseMonth(metrics.previousMonthValue).toLowerCase().replace(',', '');
  const compare = `so với ${previousLabel}`;

  return (
    <SectionCard
      title={`Tổng quan tháng ${monthDate.getMonth() + 1} · ${monthDate.getFullYear()}`}
      subtitle={`${editorCount} editor · mọi con số đều so với ${previousLabel}.`}
      action={canCreateReport ? (
        <button type="button" className="btn btn-sm" onClick={onOpenReport}>
          <FileText /> Tạo báo cáo
        </button>
      ) : undefined}
    >
      <div className="tile-grid">
        <MetricTile
          icon={Clapperboard}
          value={metrics.totalVideos}
          label="Tổng video"
          hint="Video có ngày air rơi vào tháng này."
          delta={metrics.totalVideos - metrics.previous.totalVideos}
          deltaTone="neutral"
          deltaLabel={compare}
        />
        <MetricTile
          icon={CircleCheck}
          value={metrics.doneVideos}
          label="Đã hoàn thành"
          hint="Video ở trạng thái Đã xong."
          delta={metrics.doneVideos - metrics.previous.doneVideos}
          deltaTone="up-is-good"
          deltaLabel={compare}
        />
        <MetricTile
          icon={Gauge}
          value={`${metrics.completionRate}%`}
          label="Tỉ lệ hoàn thành"
          hint="Số video đã xong chia cho tổng video trong tháng."
          delta={metrics.completionRate - metrics.previous.completionRate}
          deltaTone="up-is-good"
          deltaLabel={`điểm ${compare}`}
        />
        <MetricTile
          icon={AlertTriangle}
          value={metrics.overdueVideos}
          label="Trễ hạn"
          hint="Chưa xong mà đã qua hạn trả."
          delta={metrics.overdueVideos - metrics.previous.overdueVideos}
          deltaTone="down-is-good"
          deltaLabel={compare}
        />
        <MetricTile
          icon={Video}
          value={metrics.totalShoots}
          label="Buổi quay"
          hint="Chỉ tính Lịch quay và On set."
          delta={metrics.totalShoots - metrics.previous.totalShoots}
          deltaTone="neutral"
          deltaLabel={compare}
        />
      </div>
    </SectionCard>
  );
}
