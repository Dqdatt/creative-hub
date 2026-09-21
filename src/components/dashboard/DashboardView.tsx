import type { DashboardMetrics } from '../../hooks/useDashboard';
import type { Editor, VideoTask } from '../../types/task';
import type { ShootSchedule } from '../../types/shoot';
import { AttentionSection } from './AttentionSection';
import { EditorTable } from './EditorTable';
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
  onOpenReport,
  onOpenWaiting,
  onOpenOverdue,
  onOpenMissingLinks,
}: DashboardViewProps) {
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
