import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FileText } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { DashboardView } from '../components/dashboard/DashboardView';
import { SectionCard } from '../components/dashboard/SectionCard';
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

  const reportModal = (
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
  );

  if (isLoading) {
    return (
      <div className="dashboard" data-view="dashboard" aria-busy="true">
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
      <div className="dashboard" data-view="dashboard">
        <ErrorState title="Không thể tải tổng quan" message={loadError} onRetry={() => void refetch()} />
      </div>
    );
  }

  if (isEmpty) {
    return (
      <div className="dashboard" data-view="dashboard">
        <SectionCard
          title="Tổng quan"
          subtitle="Tháng này chưa có video task hay lịch quay nào."
          action={canCreateReport ? (
            <button type="button" className="btn btn-sm" onClick={() => setReportOpen(true)}>
              <FileText /> Tạo báo cáo
            </button>
          ) : undefined}
        >
          <EmptyState
            title="Chưa có dữ liệu tổng quan"
            message="Thêm video task hoặc lịch quay để bắt đầu theo dõi."
          />
        </SectionCard>
        {reportModal}
      </div>
    );
  }

  return (
    <>
      <DashboardView
        monthValue={selectedMonth}
        metrics={metrics}
        editors={editors}
        tasks={tasks}
        shoots={shoots}
        canCreateReport={canCreateReport}
        onOpenReport={() => setReportOpen(true)}
        onOpenWaiting={() => navigate(taskListPath({ status: 'Chờ' }))}
        onOpenOverdue={() => navigate(taskListPath({ attention: 'overdue' }))}
        onOpenMissingLinks={() => navigate(taskListPath({ status: 'Đã xong', attention: 'missing-link' }))}
      />
      {reportModal}
    </>
  );
}
