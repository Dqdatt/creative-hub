import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { BellOff, CheckCheck, Loader2, Trash2 } from 'lucide-react';
import { canAccessRoute, getDefaultAuthenticatedRoute } from '../config/permissions';
import { getNotificationPresentation } from '../config/notificationPresentation';
import { useAuth } from '../context/authContext';
import { useConfirmDialog } from '../components/common/confirmDialogContext';
import { useToast } from '../components/common/toastContext';
import { useAppOutlet } from '../components/mobile/outletContext';
import type { InternalNotification } from '../types/notification';
import { formatVietnameseRelativeTime } from '../utils/dateTime';
import { resolveNotificationActionUrl } from '../utils/notificationAction';

const DAY_MS = 86_400_000;

function groupLabel(createdAt: string) {
  const created = new Date(createdAt);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (created >= today) return 'Hôm nay';
  if (created.getTime() >= today.getTime() - DAY_MS) return 'Hôm qua';
  return 'Trước đó';
}

// Trang Thông báo cho giao diện mobile: cùng dữ liệu và thao tác với chuông
// thông báo trên desktop, hiển thị thành danh sách toàn trang.
export default function Notifications() {
  const navigate = useNavigate();
  const { role, permissions } = useAuth();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const { notifications: data } = useAppOutlet();
  const [isMarkingAll, setIsMarkingAll] = useState(false);
  const {
    notifications,
    unreadCount,
    isLoading,
    loadError,
    mutationError,
    markOneRead,
    markAllRead,
    deleteOne,
    deleteOlderThan,
    refetch,
    deletingIds,
    isDeletingOlder,
  } = data;

  const groups = useMemo(() => {
    const map = new Map<string, InternalNotification[]>();
    notifications.forEach((notification) => {
      const label = groupLabel(notification.createdAt);
      map.set(label, [...(map.get(label) ?? []), notification]);
    });
    return Array.from(map.entries());
  }, [notifications]);

  const handleOpen = (notification: InternalNotification) => {
    if (!notification.readAt) {
      void markOneRead(notification.id).then((marked) => {
        if (!marked) showToast({ type: 'error', message: mutationError ?? 'Không thể cập nhật trạng thái thông báo.' });
      });
    }

    const action = resolveNotificationActionUrl(notification.actionUrl);
    if (!action) {
      showToast({ type: 'warning', message: 'Đường dẫn thông báo không còn hợp lệ.' });
      return;
    }
    if (!canAccessRoute(role, action.route, permissions)) {
      showToast({ type: 'warning', message: 'Bạn không có quyền mở nội dung này.' });
      navigate(getDefaultAuthenticatedRoute(role, permissions), { replace: true });
      return;
    }
    navigate(action.to);
  };

  const handleMarkAll = async () => {
    if (unreadCount === 0 || isMarkingAll) return;
    setIsMarkingAll(true);
    const marked = await markAllRead();
    setIsMarkingAll(false);
    if (!marked) showToast({ type: 'error', message: mutationError ?? 'Không thể đánh dấu tất cả thông báo.' });
  };

  const handleDelete = async (notification: InternalNotification) => {
    if (deletingIds.has(notification.id)) return;
    const deleted = await deleteOne(notification.id);
    if (!deleted) showToast({ type: 'error', message: mutationError ?? 'Không thể xóa thông báo.' });
  };

  const handleDeleteOld = async () => {
    if (isDeletingOlder) return;
    const confirmed = await requestConfirm({
      title: 'Xóa thông báo cũ?',
      description: 'Các thông báo của bạn cũ hơn 15 ngày sẽ bị xóa vĩnh viễn.',
      confirmLabel: 'Xóa thông báo',
      cancelLabel: 'Hủy',
      variant: 'danger',
    });
    if (!confirmed) return;

    const result = await deleteOlderThan(15);
    if (!result) {
      showToast({ type: 'error', message: mutationError ?? 'Không thể xóa thông báo cũ.' });
      return;
    }
    showToast({
      type: 'success',
      message: result.deletedCount > 0 ? `Đã xóa ${result.deletedCount} thông báo cũ.` : 'Không có thông báo nào cũ hơn 15 ngày.',
    });
  };

  return (
    <div className="m-stack" data-view="notifications">
      <div className="m-row-actions">
        <span className="m-muted">{unreadCount > 0 ? `${unreadCount} chưa đọc` : 'Đã đọc hết'}</span>
        <button type="button" className="m-chip" onClick={() => void handleMarkAll()} disabled={unreadCount === 0 || isMarkingAll}>
          {isMarkingAll ? <Loader2 className="m-spin" aria-hidden="true" /> : <CheckCheck aria-hidden="true" />}
          Đọc hết
        </button>
        <button type="button" className="m-chip" onClick={() => void handleDeleteOld()} disabled={isDeletingOlder}>
          {isDeletingOlder ? <Loader2 className="m-spin" aria-hidden="true" /> : <Trash2 aria-hidden="true" />}
          Xóa cũ
        </button>
      </div>

      {isLoading && notifications.length === 0 ? (
        <div className="m-card m-empty"><Loader2 className="m-spin" aria-hidden="true" /><span>Đang tải thông báo...</span></div>
      ) : null}

      {loadError && notifications.length === 0 ? (
        <div className="m-card m-empty">
          <BellOff aria-hidden="true" />
          <b>Không thể tải thông báo.</b>
          <button type="button" className="m-chip" onClick={() => void refetch()}>Thử lại</button>
        </div>
      ) : null}

      {!isLoading && !loadError && notifications.length === 0 ? (
        <div className="m-card m-empty">
          <BellOff aria-hidden="true" />
          <b>Chưa có thông báo</b>
          <span>Các cập nhật liên quan đến bạn sẽ xuất hiện tại đây.</span>
        </div>
      ) : null}

      {groups.map(([label, items]) => (
        <section key={label} className="m-section">
          <h2 className="m-section-label">{label}</h2>
          <div className="m-card m-list">
            {items.map((notification) => {
              const presentation = getNotificationPresentation(notification.type);
              const Icon = presentation.icon;
              const unread = !notification.readAt;
              return (
                <div key={notification.id} className={`m-noti ${unread ? 'is-unread' : ''}`}>
                  <button
                    type="button"
                    className="m-noti-main"
                    onClick={() => handleOpen(notification)}
                    aria-label={`${notification.title}${unread ? ', chưa đọc' : ''}`}
                  >
                    <span className={`m-noti-icon notification-type-icon--${presentation.accent}`} aria-hidden="true"><Icon /></span>
                    <span className="m-noti-copy">
                      <span className="m-noti-title">{notification.title}</span>
                      <span className="m-noti-body">{notification.body}</span>
                      <span className="m-noti-time">{formatVietnameseRelativeTime(notification.createdAt)}</span>
                    </span>
                    {unread ? <span className="m-noti-dot" aria-hidden="true" /> : null}
                  </button>
                  <button
                    type="button"
                    className="m-noti-delete"
                    aria-label="Xóa thông báo"
                    onClick={() => void handleDelete(notification)}
                    disabled={deletingIds.has(notification.id)}
                  >
                    {deletingIds.has(notification.id) ? <Loader2 className="m-spin" aria-hidden="true" /> : <Trash2 aria-hidden="true" />}
                  </button>
                </div>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}
