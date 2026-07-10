import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { KPICards } from '../components/dashboard/KPICards';
import { EditorWorkload } from '../components/dashboard/EditorWorkload';
import { TeamOrderTable } from '../components/dashboard/TeamOrderTable';
import { UpcomingList } from '../components/dashboard/UpcomingList';
import { useDashboard } from '../hooks/useDashboard';
import { useMonth } from '../context/monthContext';

export default function Dashboard() {
  const { selectedMonth } = useMonth();
  const {
    tasks,
    shoots,
    editors,
    metrics,
    isLoading,
    loadError,
    isEmpty,
    refetch,
  } = useDashboard(selectedMonth);

  if (isLoading) {
    return (
      <div className="space-y-10 pt-2" data-view="dashboard" aria-busy="true">
        <LoadingState
          variant="block"
          shape="dashboard"
          message="Đang tải dữ liệu tổng quan..."
          className=""
        />
      </div>
    );
  }

  if (loadError) {
    return (
      <div className="space-y-10 pt-2" data-view="dashboard">
        <ErrorState title="Không thể tải tổng quan" message={loadError} onRetry={() => void refetch()} />
      </div>
    );
  }

  if (isEmpty) {
    return (
      <div className="space-y-10 pt-2" data-view="dashboard">
        <EmptyState
          title="Chưa có dữ liệu tổng quan"
          message="Thêm video task hoặc lịch quay để bắt đầu theo dõi."
        />
      </div>
    );
  }

  return (
    <div className="space-y-10 pt-2" data-view="dashboard">
      <KPICards
        monthValue={selectedMonth}
        totalVideos={metrics.totalVideos}
        doneVideos={metrics.doneVideos}
        doingVideos={metrics.doingVideos}
        urgentVideos={metrics.urgentVideos}
        totalShoots={metrics.totalShoots}
      />
      
      <EditorWorkload
        editors={editors}
        tasks={tasks}
        shoots={shoots}
      />
      
      <TeamOrderTable
        editors={editors}
        tasks={tasks}
      />
      
      <UpcomingList
        tasks={tasks}
        shoots={shoots}
      />
    </div>
  );
}
