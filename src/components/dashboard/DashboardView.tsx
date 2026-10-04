import { AlarmClock, FileText } from 'lucide-react';
import { EmptyState } from '../common/EmptyState';
import { SectionCard } from './SectionCard';
import type { DashboardMetrics } from '../../hooks/useDashboard';
import type { BrandKpiTarget } from '../../services/brandKpiService';
import type { Editor, VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';
import { monthValueToDate } from '../../utils/month';
import { AttentionSection } from './AttentionSection';
import { EditorTable } from './EditorTable';
import { BrandKpiCard } from './BrandKpiCard';
import { EditorMatrixTable } from './EditorMatrixTable';
import { OrderTotalsTable } from './OrderTotalsTable';
import { OverviewSection } from './OverviewSection';
import { TeamOrderTable } from './TeamOrderTable';
import { UpcomingShootsCard, UrgentTasksCard } from './UpcomingList';

interface DashboardViewProps {
  monthValue: string;
  metrics: DashboardMetrics;
  editors: Editor[];
  tasks: VideoTask[];
  shoots: ShootSchedule[];
  canCreateReport: boolean;
  /** Admin chỉ xem bảng chi tiết editor x team order x loại video, xếp dọc hết bề ngang. */
  isAdmin: boolean;
  /** Nút bật/tắt số liệu trễ deadline trên hai bảng của admin. */
  showLateDeadline: boolean;
  onToggleLateDeadline: () => void;
  /** null nghĩa là tháng đang xem chưa nhập chỉ tiêu KPI BRAND. */
  brandKpiTarget: BrandKpiTarget | null;
  onEditBrandKpi: () => void;
  onOpenReport: () => void;
  onOpenWaiting: () => void;
  onOpenOverdue: () => void;
  onOpenMissingLinks: () => void;
}

// Hàng trên là các ô chỉ số, hàng dưới là hai bảng tổng hợp và cột việc cần làm.
export function DashboardView({
  monthValue,
  metrics,
  editors,
  tasks,
  shoots,
  canCreateReport,
  isAdmin,
  showLateDeadline,
  onToggleLateDeadline,
  brandKpiTarget,
  onEditBrandKpi,
  onOpenReport,
  onOpenWaiting,
  onOpenOverdue,
  onOpenMissingLinks,
}: DashboardViewProps) {
  if (isAdmin) {
    const headerActions = (
      <div className="dsection-actions">
        <button
          type="button"
          className="btn-ghost"
          aria-pressed={showLateDeadline}
          onClick={onToggleLateDeadline}
          title={showLateDeadline ? 'Ẩn số liệu trễ deadline' : 'Hiện số liệu trễ deadline'}
        >
          <AlarmClock /> Trễ deadline
        </button>
        {canCreateReport ? (
          <button type="button" className="btn btn-sm" onClick={onOpenReport}>
            <FileText /> Tạo báo cáo
          </button>
        ) : null}
      </div>
    );

    // Tháng chỉ có livestream hoặc lịch "Khác" thì hai bảng đều rỗng; không có
    // nhánh này admin sẽ thấy một trang trắng không giải thích gì.
    if (metrics.editorMatrix.editors.length === 0) {
      return (
        <div className="dashboard" data-view="dashboard">
          <SectionCard
            title={`Tổng task tháng ${monthValueToDate(monthValue).getMonth() + 1}`}
            action={headerActions}
          >
            <EmptyState
              title="Chưa có video task hay buổi quay trong tháng"
              message="Buổi quay chỉ tính Lịch quay và On set; livestream và lịch Khác không vào bảng này."
            />
          </SectionCard>
        </div>
      );
    }

    return (
      <div className="dashboard" data-view="dashboard">
        <EditorMatrixTable
          matrix={metrics.editorMatrix}
          monthValue={monthValue}
          showLateDeadline={showLateDeadline}
          action={headerActions}
        />
        <BrandKpiCard
          brandKpi={metrics.brandKpi}
          monthValue={monthValue}
          target={brandKpiTarget}
          onEditTarget={onEditBrandKpi}
        />
        <OrderTotalsTable matrix={metrics.editorMatrix} showLateDeadline={showLateDeadline} />
      </div>
    );
  }

  return (
    <div className="dashboard" data-view="dashboard">
      <div className="dashboard-row dashboard-row--top">
        <OverviewSection
          monthValue={monthValue}
          metrics={metrics}
          editorCount={editors.length}
          canCreateReport={canCreateReport}
          onOpenReport={onOpenReport}
        />
        <AttentionSection
          pendingVideos={metrics.pendingVideos}
          overdueVideos={metrics.overdueVideos}
          doneWithoutResultLinks={metrics.doneWithoutResultLinks}
          onOpenWaiting={onOpenWaiting}
          onOpenOverdue={onOpenOverdue}
          onOpenMissingLinks={onOpenMissingLinks}
        />
      </div>

      <div className="dashboard-row dashboard-row--main">
        <div className="dashboard-col">
          <EditorTable editorStats={metrics.editorStats} />
          <TeamOrderTable
            editors={editors}
            teamStats={metrics.teamStats}
            totalVideos={metrics.totalVideos}
          />
        </div>

        <div className="dashboard-col">
          <UrgentTasksCard tasks={tasks} />
          <UpcomingShootsCard shoots={shoots} />
        </div>
      </div>
    </div>
  );
}
