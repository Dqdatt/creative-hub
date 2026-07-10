import { useMemo, useState } from 'react';
import type { ShootSchedule, ShootType, ShootFormData } from '../types/shoot';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { CalendarHeader } from '../components/calendar/CalendarHeader';
import { CalendarGrid } from '../components/calendar/CalendarGrid';
import { ShootModal } from '../components/calendar/ShootModal';
import { canEditShoot } from '../config/permissions';
import { useAuth } from '../context/authContext';
import { useShoots } from '../hooks/useShoots';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';
import { monthValueToDate } from '../utils/month';

function toIsoDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function getCalendarRange(date: Date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const first = new Date(year, month, 1);
  const startDow = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cellCount = Math.ceil((startDow + daysInMonth) / 7) * 7;
  const startDate = new Date(year, month, 1 - startDow);
  const endDate = new Date(year, month, cellCount - startDow);

  return {
    startDate: toIsoDate(startDate),
    endDate: toIsoDate(endDate),
  };
}

export default function Calendar() {
  const { role } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { selectedMonth, goToCurrentMonth } = useMonth();
  const [filter, setFilter] = useState<ShootType | 'all'>('all');

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedShoot, setSelectedShoot] = useState<ShootSchedule | null>(null);
  const [defaultDateForModal, setDefaultDateForModal] = useState('');
  const canManageShoots = canEditShoot(role);
  const canCreateShoot = canManageShoots;
  const canUpdateShoot = canManageShoots;
  const canDeleteShoot = canManageShoots;

  const currentDate = useMemo(() => monthValueToDate(selectedMonth), [selectedMonth]);

  const visibleRange = useMemo(() => getCalendarRange(currentDate), [currentDate]);
  const {
    shoots,
    editorOptions,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    modalError,
    refetch,
    createShoot,
    updateShoot,
    deleteShoot,
    clearModalError,
  } = useShoots(visibleRange);

  const monthShoots = useMemo(
    () => shoots.filter((shoot) => shoot.date.startsWith(selectedMonth)),
    [selectedMonth, shoots]
  );

  const handleDayClick = (dateStr: string) => {
    if (!canCreateShoot) return;
    clearModalError();
    setSelectedShoot(null);
    setDefaultDateForModal(dateStr);
    setIsModalOpen(true);
  };

  const handleShootClick = (shoot: ShootSchedule, e: React.MouseEvent) => {
    e.stopPropagation();
    clearModalError();
    setSelectedShoot(shoot);
    setDefaultDateForModal(shoot.date);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    if (isSaving || isDeleting) return;
    setIsModalOpen(false);
    setSelectedShoot(null);
    clearModalError();
  };

  const handleSave = async (data: ShootFormData) => {
    if (selectedShoot && !canUpdateShoot) return;
    if (!selectedShoot && !canCreateShoot) return;

    const saved = selectedShoot
      ? await updateShoot(selectedShoot.id, data)
      : await createShoot(data);

    if (saved) {
      setIsModalOpen(false);
      setSelectedShoot(null);
      clearModalError();
      showToast({
        type: 'success',
        message: selectedShoot ? 'Đã lưu thay đổi lịch quay.' : 'Đã thêm lịch quay.',
      });
    }
  };

  const handleDelete = async (id: string) => {
    if (!canDeleteShoot) return;

    const confirmed = await requestConfirm({
      title: 'Xóa lịch quay?',
      description: 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa lịch quay',
      variant: 'danger',
    });

    if (!confirmed) return;

    const deleted = await deleteShoot(id);

    if (deleted) {
      setIsModalOpen(false);
      setSelectedShoot(null);
      clearModalError();
      showToast({ type: 'success', message: 'Đã xóa lịch quay.' });
    }
  };

  return (
    <div className="calendar-page" data-view="calendar">
      <CalendarHeader
        filter={filter}
        onToday={goToCurrentMonth}
        onFilterChange={setFilter}
      />

      {loadError ? (
        <ErrorState title="Không thể tải lịch quay" message={loadError} onRetry={() => void refetch()} />
      ) : null}

      {!isLoading && !loadError && monthShoots.length === 0 ? (
        <EmptyState
          title="Chưa có lịch quay trong tháng đã chọn"
          message={canCreateShoot ? 'Bấm vào một ngày trên lịch để thêm lịch quay.' : 'Chưa có lịch quay trong tháng đã chọn.'}
        />
      ) : null}

      <div className="calendar-card card">
        {isLoading ? (
          <LoadingState
            variant="block"
            message="Đang tải lịch quay..."
            shape="calendar"
            className="calendar-loading px-3 py-12 text-center text-sub"
          />
        ) : (
          <CalendarGrid
            currentDate={currentDate}
            shoots={shoots}
            filter={filter}
            onDayClick={handleDayClick}
            onShootClick={handleShootClick}
            canCreateShoot={canCreateShoot}
          />
        )}
      </div>

      <ShootModal
        isOpen={isModalOpen}
        shoot={selectedShoot}
        editorOptions={editorOptions}
        defaultDate={defaultDateForModal}
        canEdit={selectedShoot ? canUpdateShoot : canCreateShoot}
        onClose={closeModal}
        onSave={handleSave}
        onDelete={canDeleteShoot ? handleDelete : undefined}
        isSaving={isSaving}
        isDeleting={isDeleting}
        errorMessage={modalError}
      />
    </div>
  );
}
