import { useEffect, useRef, useState } from 'react';
import { Bell, BellOff, Loader2, MoreHorizontal, Trash2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { canAccessRoute, getDefaultAuthenticatedRoute } from '../../config/permissions';
import type { AppRole, EffectivePermissions } from '../../config/permissions';
import { getNotificationPresentation } from '../../config/notificationPresentation';
import { useConfirmDialog } from '../common/confirmDialogContext';
import { useToast } from '../common/toastContext';
import type { DeleteOldNotificationsResult } from '../../types/notification';
import type { InternalNotification } from '../../types/notification';
import { formatVietnameseRelativeTime } from '../../utils/dateTime';
import { resolveNotificationActionUrl } from '../../utils/notificationAction';

interface NotificationCenterProps {
  notifications: InternalNotification[];
  unreadCount: number;
  isLoading: boolean;
  loadError: string | null;
  mutationError: string | null;
  isOpen: boolean;
  role: AppRole | string | null | undefined;
  permissions: EffectivePermissions | null | undefined;
  onOpenChange: (open: boolean) => void;
  onMarkOneRead: (notificationId: string) => Promise<boolean>;
  onMarkAllRead: () => Promise<boolean>;
  onDeleteOne: (notificationId: string) => Promise<boolean>;
  onDeleteOlderThan: (days?: number) => Promise<DeleteOldNotificationsResult | null>;
  onRetry: (options?: { silent?: boolean }) => Promise<void>;
  deletingIds: ReadonlySet<string>;
  isDeletingOlder: boolean;
}

function getBadgeText(count: number) {
  return count > 99 ? '99+' : String(count);
}

function getBellLabel(unreadCount: number) {
  if (unreadCount > 0) {
    return `Mở thông báo, ${unreadCount} thông báo chưa đọc`;
  }

  return 'Mở thông báo';
}

export function NotificationCenter({
  notifications,
  unreadCount,
  isLoading,
  loadError,
  mutationError,
  isOpen,
  role,
  permissions,
  onOpenChange,
  onMarkOneRead,
  onMarkAllRead,
  onDeleteOne,
  onDeleteOlderThan,
  onRetry,
  deletingIds,
  isDeletingOlder,
}: NotificationCenterProps) {
  const navigate = useNavigate();
  const { requestConfirm } = useConfirmDialog();
  const { showToast } = useToast();
  const rootRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const [isMarkingAll, setIsMarkingAll] = useState(false);
  const [actionsOpen, setActionsOpen] = useState(false);

  useEffect(() => {
    if (!isOpen) return undefined;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (rootRef.current?.contains(target)) return;
      onOpenChange(false);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      onOpenChange(false);
      window.requestAnimationFrame(() => buttonRef.current?.focus());
    };

    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onOpenChange]);

  const handleMarkAll = async () => {
    if (unreadCount === 0 || isMarkingAll) return;
    setActionsOpen(false);
    setIsMarkingAll(true);
    const marked = await onMarkAllRead();
    setIsMarkingAll(false);

    if (!marked) {
      showToast({
        type: 'error',
        message: mutationError ?? 'Không thể đánh dấu tất cả thông báo.',
      });
    }
  };

  const handleDeleteOne = async (notification: InternalNotification, event: React.MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    if (deletingIds.has(notification.id)) return;

    const deleted = await onDeleteOne(notification.id);
    if (!deleted) {
      showToast({
        type: 'error',
        message: mutationError ?? 'Không thể xóa thông báo.',
      });
    }
  };

  const handleDeleteOld = async () => {
    if (isDeletingOlder) return;
    setActionsOpen(false);

    const confirmed = await requestConfirm({
      title: 'Xóa thông báo cũ?',
      description: 'Các thông báo của bạn cũ hơn 15 ngày sẽ bị xóa vĩnh viễn.',
      confirmLabel: 'Xóa thông báo',
      cancelLabel: 'Hủy',
      variant: 'danger',
    });

    if (!confirmed) return;

    const result = await onDeleteOlderThan(15);
    if (!result) {
      showToast({
        type: 'error',
        message: mutationError ?? 'Không thể xóa thông báo cũ.',
      });
      return;
    }

    showToast({
      type: 'success',
      message: result.deletedCount > 0
        ? `Đã xóa ${result.deletedCount} thông báo cũ.`
        : 'Không có thông báo nào cũ hơn 15 ngày.',
    });
  };

  const handleNotificationClick = (notification: InternalNotification) => {
    if (!notification.readAt) {
      void onMarkOneRead(notification.id).then((marked) => {
        if (marked) return;
        showToast({
          type: 'error',
          message: mutationError ?? 'Không thể cập nhật trạng thái thông báo.',
        });
      });
    }

    const action = resolveNotificationActionUrl(notification.actionUrl);
    if (!action) {
      showToast({ type: 'warning', message: 'Đường dẫn thông báo không còn hợp lệ.' });
      onOpenChange(false);
      return;
    }

    if (!canAccessRoute(role, action.route, permissions)) {
      showToast({ type: 'warning', message: 'Bạn không có quyền mở nội dung này.' });
      navigate(getDefaultAuthenticatedRoute(role, permissions), { replace: true });
      onOpenChange(false);
      return;
    }

    navigate(action.to);
    onOpenChange(false);
  };

  return (
    <div ref={rootRef} className="notification-center">
      <button
        ref={buttonRef}
        type="button"
        className="icon-btn notification-bell"
        aria-label={getBellLabel(unreadCount)}
        title="Thông báo"
        aria-haspopup="dialog"
        aria-expanded={isOpen}
        onClick={() => onOpenChange(!isOpen)}
      >
        <Bell />
        {unreadCount > 0 ? (
          <span className="notification-badge" aria-label={`${unreadCount} thông báo chưa đọc`}>
            {getBadgeText(unreadCount)}
          </span>
        ) : null}
      </button>

	  {isOpen ? (
        <section
          className="notification-panel card"
          role="dialog"
          aria-labelledby="notificationPanelTitle"
        >
          <header className="notification-panel-head">
            <div className="min-w-0">
              <h2 id="notificationPanelTitle">Thông báo</h2>
              {unreadCount > 0 ? <p>{unreadCount} chưa đọc</p> : null}
            </div>
            <div className="notification-actions">
              <button
                type="button"
                className="notification-actions-trigger"
                aria-label="Mở thao tác thông báo"
                aria-haspopup="menu"
                aria-expanded={actionsOpen}
                title="Thao tác thông báo"
                onClick={() => setActionsOpen((open) => !open)}
              >
                <MoreHorizontal />
              </button>
              {actionsOpen ? (
                <div className="notification-actions-menu card" role="menu">
                  <button
                    type="button"
                    role="menuitem"
                    className="notification-actions-item"
                    onClick={() => void handleMarkAll()}
                    disabled={unreadCount === 0 || isMarkingAll}
                  >
                    {isMarkingAll ? 'Đang lưu...' : 'Đánh dấu tất cả đã đọc'}
                  </button>
                  <button
                    type="button"
                    role="menuitem"
                    className="notification-actions-item"
                    onClick={() => void handleDeleteOld()}
                    disabled={isDeletingOlder}
                  >
                    {isDeletingOlder ? (
                      <>
                        <Loader2 aria-hidden="true" />
                        <span>Đang xóa...</span>
                      </>
                    ) : (
                      <span>Xóa thông báo quá 15 ngày</span>
                    )}
                  </button>
                </div>
              ) : null}
            </div>
          </header>

          <div className="notification-list" aria-live="polite">
            {isLoading && notifications.length === 0 ? (
              <div className="notification-loading">
                <Loader2 aria-hidden="true" />
                <span>Đang tải thông báo...</span>
              </div>
            ) : null}

            {loadError && notifications.length === 0 ? (
              <div className="notification-empty">
                <BellOff aria-hidden="true" />
                <strong>Không thể tải thông báo.</strong>
                <button type="button" className="notification-retry" onClick={() => void onRetry()}>
                  Thử lại
                </button>
              </div>
            ) : null}

            {!isLoading && !loadError && notifications.length === 0 ? (
              <div className="notification-empty">
                <BellOff aria-hidden="true" />
                <strong>Chưa có thông báo</strong>
                <span>Các cập nhật liên quan đến bạn sẽ xuất hiện tại đây.</span>
              </div>
            ) : null}

            {notifications.map((notification) => {
              const presentation = getNotificationPresentation(notification.type);
              const Icon = presentation.icon;
              const unread = !notification.readAt;

              return (
                <div
                  key={notification.id}
                  className={`notification-row ${unread ? 'is-unread' : ''}`}
                >
                  <button
                    type="button"
                    className="notification-item"
                    onClick={() => handleNotificationClick(notification)}
                    aria-label={`${notification.title}${unread ? ', chưa đọc' : ''}`}
                  >
                    <span className={`notification-type-icon notification-type-icon--${presentation.accent}`} aria-hidden="true">
                      <Icon />
                    </span>
                    <span className="notification-item-copy">
                      <span className="notification-item-title">
                        {notification.title}
                        {unread ? <span className="notification-unread-dot" aria-hidden="true" /> : null}
                      </span>
                      <span className="notification-item-body">{notification.body}</span>
                      <span className="notification-item-time">{formatVietnameseRelativeTime(notification.createdAt)}</span>
                    </span>
                  </button>
                  <button
                    type="button"
                    className="notification-delete"
                    aria-label="Xóa thông báo"
                    title="Xóa thông báo"
                    onClick={(event) => void handleDeleteOne(notification, event)}
                    disabled={deletingIds.has(notification.id)}
                  >
                    {deletingIds.has(notification.id) ? <Loader2 aria-hidden="true" /> : <Trash2 aria-hidden="true" />}
                  </button>
                </div>
              );
            })}
          </div>
        </section>
      ) : null}
    </div>
  );
}
