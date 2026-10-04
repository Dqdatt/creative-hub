import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FileText } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { DashboardView } from '../components/dashboard/DashboardView';
import { SectionCard } from '../components/dashboard/SectionCard';
import { ReportModal } from '../components/dashboard/ReportModal';
import { BrandKpiModal } from '../components/dashboard/BrandKpiModal';
import { useDashboard } from '../hooks/useDashboard';
import { useBrandKpiTarget } from '../hooks/useBrandKpiTarget';
import { useMonth } from '../context/monthContext';
import { useAuth } from '../context/authContext';
import { useToast } from '../components/common/toastContext';

export default function Dashboard() {
  const navigate = useNavigate();
  const { can, role, user } = useAuth();
  const { showToast } = useToast();
  const { selectedMonth, setSelectedMonth } = useMonth();
  const [reportOpen, setReportOpen] = useState(false);
  const [reportEditorFilter, setReportEditorFilter] = useState('all');
  const [showLateDeadline, setShowLateDeadline] = useState(true);
  const [brandKpiOpen, setBrandKpiOpen] = useState(false);
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
  const isAdmin = role === 'admin';
  const canCreateReport = can('dashboard:report');
  // Chỉ admin thấy card KPI nên cũng chỉ admin cần tải chỉ tiêu.
  const brandKpi = useBrandKpiTarget(selectedMonth, isAdmin);
  const taskListPath = (params: Record<string, string>) => {
    const query = new URLSearchParams(params).toString();
    return isAdmin ? `/calendar?source=task&${query}` : `/tasks?${query}`;
  };

  const brandKpiModal = (
    <BrandKpiModal
      isOpen={brandKpiOpen}
      monthValue={selectedMonth}
      target={brandKpi.target}
      onSave={async (longVideos, motion) => {
        await brandKpi.save(longVideos, motion, user?.id);
        showToast({ type: 'success', message: 'Đã lưu chỉ tiêu KPI BRAND.' });
      }}
      onClear={async () => {
        await brandKpi.clear();
        showToast({ type: 'success', message: 'Đã xóa chỉ tiêu KPI BRAND.' });
      }}
      onClose={() => setBrandKpiOpen(false)}
    />
  );

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
        isAdmin={isAdmin}
        showLateDeadline={showLateDeadline}
        onToggleLateDeadline={() => setShowLateDeadline((value) => !value)}
        brandKpiTarget={brandKpi.target}
        onEditBrandKpi={() => setBrandKpiOpen(true)}
        onOpenReport={() => setReportOpen(true)}
        onOpenWaiting={() => navigate(taskListPath({ status: 'Chờ' }))}
        onOpenOverdue={() => navigate(taskListPath({ attention: 'overdue' }))}
        onOpenMissingLinks={() => navigate(taskListPath({ status: 'Đã xong', attention: 'missing-link' }))}
      />
      {reportModal}
      {isAdmin ? brandKpiModal : null}
    </>
  );
}
