import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FileText } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { AttentionCard } from '../components/dashboard/AttentionCard';
import { KPICards } from '../components/dashboard/KPICards';
import { EditorWorkload } from '../components/dashboard/EditorWorkload';
import { TeamOrderTable } from '../components/dashboard/TeamOrderTable';
import { UpcomingList } from '../components/dashboard/UpcomingList';
import { ReportModal } from '../components/dashboard/ReportModal';
import { useDashboard } from '../hooks/useDashboard';
import { useMonth } from '../context/monthContext';
import { useAuth } from '../context/authContext';

export default function Dashboard() {
  const navigate = useNavigate();
  const { can, role } = useAuth();
  const { selectedMonth, setSelectedMonth } = useMonth();
  const [reportOpen, setReportOpen] = useState(false);
  const [reportEditorFilter, setReportEditorFilter] = useState('all');
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
  const canCreateReport = can('dashboard:report');
  const taskListPath = (params: Record<string, string>) => {
    const query = new URLSearchParams(params).toString();
    return role === 'admin' ? `/calendar?source=task&${query}` : `/tasks?${query}`;
  };

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
        <div className="dashboard-actions">
          {canCreateReport ? (
            <button type="button" className="btn" onClick={() => setReportOpen(true)}>
              <FileText /> Tạo báo cáo
            </button>
          ) : null}
        </div>
        <EmptyState
          title="Chưa có dữ liệu tổng quan"
          message="Thêm video task hoặc lịch quay để bắt đầu theo dõi."
        />
        <ReportModal
          isOpen={reportOpen}
          monthValue={selectedMonth}
          editorFilter={reportEditorFilter}
          editors={editors}
          tasks={tasks}
          shoots={shoots}
          onMonthChange={setSelectedMonth}
          onEditorChange={setReportEditorFilter}
          onClose={() => setReportOpen(false)}
        />
      </div>
    );
  }

  return (
    <div className="space-y-10 pt-2" data-view="dashboard">
      <div className="dashboard-actions">
        {canCreateReport ? (
          <button type="button" className="btn" onClick={() => setReportOpen(true)}>
            <FileText /> Tạo báo cáo
          </button>
        ) : null}
      </div>

      <KPICards
        monthValue={selectedMonth}
        totalVideos={metrics.totalVideos}
        doneVideos={metrics.doneVideos}
        totalShoots={metrics.totalShoots}
      />

      <AttentionCard
        pendingVideos={metrics.pendingVideos}
        overdueVideos={metrics.overdueVideos}
        doneWithoutResultLinks={metrics.doneWithoutResultLinks}
        onOpenWaiting={() => navigate(taskListPath({ status: 'Chờ' }))}
        onOpenOverdue={() => navigate(taskListPath({ attention: 'overdue' }))}
        onOpenMissingLinks={() => navigate(taskListPath({ status: 'Đã xong', attention: 'missing-link' }))}
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

      <ReportModal
        isOpen={reportOpen}
        monthValue={selectedMonth}
        editorFilter={reportEditorFilter}
        editors={editors}
        tasks={tasks}
        shoots={shoots}
        onMonthChange={setSelectedMonth}
        onEditorChange={setReportEditorFilter}
        onClose={() => setReportOpen(false)}
      />
    </div>
  );
}
