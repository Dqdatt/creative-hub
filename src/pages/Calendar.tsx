import { useCallback, useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { useSearchParams } from 'react-router-dom';
import { CalendarDays, X } from 'lucide-react';
import type { ShootSchedule, ShootType, ShootFormData } from '../types/shoot';
import { EmptyState } from '../components/common/EmptyState';
import { ErrorState } from '../components/common/ErrorState';
import { LoadingState } from '../components/common/LoadingState';
import { CalendarHeader } from '../components/calendar/CalendarHeader';
import { CalendarGrid } from '../components/calendar/CalendarGrid';
import { ShootModal } from '../components/calendar/ShootModal';
import { useAuth } from '../context/authContext';
import { useShoots } from '../hooks/useShoots';
import { useRouteHighlight } from '../hooks/useRouteHighlight';
import { fetchShootById } from '../services/shootsService';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { useMonth } from '../context/monthContext';
import { monthValueToDate } from '../utils/month';
import { isIsoDate, isUuid } from '../utils/id';
import { SHOOT_TYPES_META } from '../data/shoots';
import { useDocumentScrollLock } from '../components/common/useDocumentScrollLock';

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

function formatAgendaDate(value: string) {
  const [year, month, day] = value.split('-');
  if (!year || !month || !day) return value;
  return `${day}/${month}/${year}`;
}

function DayAgendaModal({
  date,
  events,
  onClose,
  onShootClick,
}: {
  date: string;
  events: ShootSchedule[];
  onClose: () => void;
  onShootClick: (shoot: ShootSchedule, e: React.MouseEvent) => void;
}) {
  useDocumentScrollLock(true);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [onClose]);

  return createPortal(
    <div
      className="modal-overlay fixed inset-0 z-[70] flex items-center justify-center overflow-y-auto px-4 py-6"
      onClick={(event) => { if (event.target === event.currentTarget) onClose(); }}
    >
      <section className="modal-card day-agenda-card">
        <div className="day-agenda-head">
          <div className="flex min-w-0 items-center gap-3">
            <span className="icoc icoc-lg" style={{ background: 'var(--grad)', color: '#fff' }}>
              <CalendarDays />
            </span>
            <div className="min-w-0">
              <h2>Lịch ngày {formatAgendaDate(date)}</h2>
              <p>{events.length} lịch quay</p>
            </div>
          </div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Đóng">
            <X />
          </button>
        </div>

        <div className="day-agenda-list">
          {events.map((event) => {
            const meta = SHOOT_TYPES_META[event.type];
            return (
              <button
                key={event.id}
                type="button"
                className="day-agenda-item"
                onClick={(clickEvent) => {
                  onShootClick(event, clickEvent);
                  onClose();
                }}
              >
                <span className="day-agenda-type" style={{ background: meta.dot }} />
                <span className="min-w-0">
                  <strong>{event.place}</strong>
                  <span>{meta.label}{event.time ? ` · ${event.time}` : ''}</span>
                  <span>{event.displayCrew || event.crew || 'Chưa có crew/editor'}</span>
                  {event.note ? <em>{event.note}</em> : null}
                </span>
              </button>
            );
          })}
        </div>
      </section>
    </div>,
    document.body
  );
}

export default function Calendar() {
  const { can } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { selectedMonth, setSelectedMonth, goToCurrentMonth } = useMonth();
  const [searchParams, setSearchParams] = useSearchParams();
  const [filter, setFilter] = useState<ShootType | 'all'>('all');

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedShoot, setSelectedShoot] = useState<ShootSchedule | null>(null);
  const [defaultDateForModal, setDefaultDateForModal] = useState('');
  const [agenda, setAgenda] = useState<{ date: string; events: ShootSchedule[] } | null>(null);
  const canCreateShoot = can('shoots:create');
  const canUpdateShoot = can('shoots:update');
  const canDeleteShoot = can('shoots:delete');
  const highlightParam = searchParams.get('highlight');
  const legacyShootParam = searchParams.get('shoot');
  const targetShootId = highlightParam ?? legacyShootParam;
  const dateParam = searchParams.get('date');

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
    setAgenda(null);
    clearModalError();
    setSelectedShoot(shoot);
    setDefaultDateForModal(shoot.date);
    setIsModalOpen(true);
  };

  const clearShootHighlightParams = useCallback(() => {
    setSearchParams((current) => {
      const next = new URLSearchParams(current);
      next.delete('highlight');
      next.delete('shoot');
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  const clearDateParam = useCallback(() => {
    setSearchParams((current) => {
      const next = new URLSearchParams(current);
      next.delete('date');
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  const handleMoreClick = (dateStr: string, events: ShootSchedule[], e: React.MouseEvent) => {
    e.stopPropagation();
    setAgenda({ date: dateStr, events });
  };

  const closeModal = () => {
    if (isSaving || isDeleting) return;
    setIsModalOpen(false);
    setSelectedShoot(null);
    clearModalError();
  };

  useEffect(() => {
    if (dateParam && !isIsoDate(dateParam)) {
      showToast({ type: 'warning', message: 'Đường dẫn ngày lịch quay không hợp lệ.' });
      clearDateParam();
      return;
    }

    if (dateParam) {
      const targetMonth = dateParam.slice(0, 7);
      if (targetMonth !== selectedMonth) setSelectedMonth(targetMonth);
    }
  }, [clearDateParam, dateParam, selectedMonth, setSelectedMonth, showToast]);

  useEffect(() => {
    if (!targetShootId) return;

    if (!isUuid(targetShootId)) {
      showToast({ type: 'warning', message: 'Đường dẫn lịch quay không hợp lệ.' });
      clearShootHighlightParams();
      return;
    }

    const visibleShoot = shoots.find((shoot) => shoot.id === targetShootId);
    if (visibleShoot) {
      if (visibleShoot.date.slice(0, 7) !== selectedMonth) {
        setSelectedMonth(visibleShoot.date.slice(0, 7));
      }
      if (filter !== 'all' && visibleShoot.type !== filter) {
        setFilter('all');
      }
      return;
    }

    if (isLoading) return;

    let cancelled = false;

    void fetchShootById(targetShootId)
      .then((shoot) => {
        if (cancelled) return;
        if (!shoot) {
          showToast({ type: 'warning', message: 'Nội dung liên quan không còn tồn tại hoặc bạn không có quyền xem.' });
          clearShootHighlightParams();
          return;
        }

        if (shoot.date.slice(0, 7) !== selectedMonth) {
          setSelectedMonth(shoot.date.slice(0, 7));
        }
        if (filter !== 'all' && shoot.type !== filter) {
          setFilter('all');
        }
      })
      .catch(() => {
        if (cancelled) return;
        showToast({ type: 'warning', message: 'Nội dung liên quan không còn tồn tại hoặc bạn không có quyền xem.' });
        clearShootHighlightParams();
      });

    return () => {
      cancelled = true;
    };
  }, [clearShootHighlightParams, filter, isLoading, selectedMonth, setSelectedMonth, shoots, showToast, targetShootId]);

  const visibleTargetShoot = targetShootId && isUuid(targetShootId)
    ? shoots.find((shoot) => shoot.id === targetShootId && (filter === 'all' || shoot.type === filter))
    : null;
  const handleShootHighlightMissing = useCallback(() => {
    showToast({ type: 'warning', message: 'Nội dung liên quan không còn tồn tại hoặc bạn không có quyền xem.' });
  }, [showToast]);
  const handleDateHighlightMissing = useCallback(() => {
    showToast({ type: 'warning', message: 'Không tìm thấy ngày lịch quay liên quan.' });
  }, [showToast]);
  const highlightedShootId = useRouteHighlight({
    targetId: targetShootId && isUuid(targetShootId) ? targetShootId : null,
    selector: targetShootId && isUuid(targetShootId) ? `[data-shoot-id="${targetShootId}"]` : null,
    fallbackSelector: visibleTargetShoot ? `[data-calendar-date="${visibleTargetShoot.date}"]` : null,
    ready: !isLoading && Boolean(visibleTargetShoot),
    clearQuery: clearShootHighlightParams,
    onMissing: handleShootHighlightMissing,
  });
  const highlightedDate = useRouteHighlight({
    targetId: dateParam && isIsoDate(dateParam) ? dateParam : null,
    selector: dateParam && isIsoDate(dateParam) ? `[data-calendar-date="${dateParam}"]` : null,
    ready: !isLoading && Boolean(dateParam && isIsoDate(dateParam) && dateParam.startsWith(selectedMonth)),
    clearQuery: clearDateParam,
    onMissing: handleDateHighlightMissing,
  });

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
            onMoreClick={handleMoreClick}
            canCreateShoot={canCreateShoot}
            highlightedShootId={highlightedShootId}
            highlightedDate={highlightedDate}
          />
        )}
      </div>

      {agenda ? (
        <DayAgendaModal
          date={agenda.date}
          events={agenda.events}
          onClose={() => setAgenda(null)}
          onShootClick={handleShootClick}
        />
      ) : null}

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
