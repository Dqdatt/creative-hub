import { useCallback, useEffect, useRef, useState } from 'react';
import type { RealtimeChannel } from '@supabase/supabase-js';
import {
  getRecentNotifications,
  getUnreadNotificationCount,
  deleteNotification,
  deleteNotificationsOlderThan,
  markAllNotificationsRead,
  markNotificationRead,
  subscribeToNotifications,
  unsubscribeFromNotifications,
} from '../services/notificationsService';
import type { InternalNotification } from '../types/notification';

const DEFAULT_LIMIT = 15;

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

function capNotifications(notifications: InternalNotification[], limit: number) {
  return notifications.slice(0, limit);
}

function clampUnreadCount(value: number) {
  return Math.max(0, value);
}

function getTimeValue(value: string) {
  const time = new Date(value).getTime();
  return Number.isFinite(time) ? time : 0;
}

function resolveNotificationData(existing: InternalNotification | undefined, incoming: InternalNotification) {
  if (!existing) return incoming;

  return {
    ...existing,
    ...incoming,
    readAt: existing.readAt && !incoming.readAt ? existing.readAt : incoming.readAt,
  };
}

function mergeNotifications(
  current: InternalNotification[],
  incoming: InternalNotification[],
  limit: number,
) {
  const byId = new Map<string, InternalNotification>();

  for (const notification of current) {
    byId.set(notification.id, notification);
  }

  for (const notification of incoming) {
    byId.set(notification.id, resolveNotificationData(byId.get(notification.id), notification));
  }

  return capNotifications(
    Array.from(byId.values()).sort((a, b) =>
      getTimeValue(b.createdAt) - getTimeValue(a.createdAt) || b.id.localeCompare(a.id)
    ),
    limit
  );
}

export function useNotifications(profileId: string | null | undefined, limit = DEFAULT_LIMIT) {
  const requestIdRef = useRef(0);
  const profileIdRef = useRef<string | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);
  const pendingReadIdsRef = useRef<Set<string>>(new Set());
  const pendingDeleteIdsRef = useRef<Set<string>>(new Set());
  const markAllInFlightRef = useRef(false);
  const notificationsRef = useRef<InternalNotification[]>([]);
  const unreadCountRef = useRef(0);
  const [notifications, setNotifications] = useState<InternalNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [mutationError, setMutationError] = useState<string | null>(null);
  const [deletingIds, setDeletingIds] = useState<ReadonlySet<string>>(() => new Set());
  const [isDeletingOlder, setIsDeletingOlder] = useState(false);

  const commitNotifications = useCallback((nextNotifications: InternalNotification[]) => {
    notificationsRef.current = nextNotifications;
    setNotifications(nextNotifications);
  }, []);

  const updateNotifications = useCallback((updater: (current: InternalNotification[]) => InternalNotification[]) => {
    const next = updater(notificationsRef.current);
    notificationsRef.current = next;
    setNotifications(next);
  }, []);

  const commitUnreadCount = useCallback((nextUnreadCount: number) => {
    const next = clampUnreadCount(nextUnreadCount);
    unreadCountRef.current = next;
    setUnreadCount(next);
  }, []);

  const updateUnreadCount = useCallback((updater: (current: number) => number) => {
    const next = clampUnreadCount(updater(unreadCountRef.current));
    unreadCountRef.current = next;
    setUnreadCount(next);
  }, []);

  useEffect(() => {
    const nextProfileId = profileId ?? null;
    if (profileIdRef.current === nextProfileId) return;

    profileIdRef.current = nextProfileId;
    requestIdRef.current += 1;
    pendingReadIdsRef.current.clear();
    pendingDeleteIdsRef.current.clear();
    markAllInFlightRef.current = false;
    commitNotifications([]);
    commitUnreadCount(0);
    setLoadError(null);
    setMutationError(null);
    setDeletingIds(new Set());
    setIsDeletingOlder(false);
    setIsLoading(Boolean(nextProfileId));
  }, [commitNotifications, commitUnreadCount, profileId]);

  const loadNotifications = useCallback(async (options?: { silent?: boolean }) => {
    if (!profileId) {
      commitNotifications([]);
      commitUnreadCount(0);
      setIsLoading(false);
      setLoadError(null);
      return;
    }

    const activeProfileId = profileId;
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!options?.silent) setIsLoading(true);
    setLoadError(null);

    try {
      const [nextNotifications, nextUnreadCount] = await Promise.all([
        getRecentNotifications({ limit }),
        getUnreadNotificationCount(),
      ]);

      if (requestId !== requestIdRef.current || profileIdRef.current !== activeProfileId) return;
      updateNotifications((current) => mergeNotifications(current, nextNotifications, limit));
      commitUnreadCount(nextUnreadCount);
    } catch (error) {
      if (requestId !== requestIdRef.current || profileIdRef.current !== activeProfileId) return;
      setLoadError(getErrorMessage(error, 'Không thể tải thông báo.'));
    } finally {
      if (requestId === requestIdRef.current && profileIdRef.current === activeProfileId) setIsLoading(false);
    }
  }, [commitNotifications, commitUnreadCount, limit, profileId, updateNotifications]);

  useEffect(() => {
    void loadNotifications();
  }, [loadNotifications]);

  useEffect(() => {
    if (channelRef.current) {
      const previousChannel = channelRef.current;
      channelRef.current = null;
      void unsubscribeFromNotifications(previousChannel);
    }

    if (!profileId) {
      commitNotifications([]);
      commitUnreadCount(0);
      return undefined;
    }

    const subscriptionProfileId = profileId;
    let hasSubscribedOnce = false;
    const channel = subscribeToNotifications(profileId, {
      onInsert: (notification) => {
        if (profileIdRef.current !== subscriptionProfileId || notification.recipientId !== subscriptionProfileId) return;
        const existingNotification = notificationsRef.current.find((item) => item.id === notification.id);
        const insertedUnread = !existingNotification && !notification.readAt;
        updateNotifications((current) => {
          return mergeNotifications(current, [notification], limit);
        });

        if (insertedUnread) {
          updateUnreadCount((current) => current + 1);
        }
      },
      onUpdate: (notification) => {
        if (profileIdRef.current !== subscriptionProfileId || notification.recipientId !== subscriptionProfileId) return;
        const existingNotification = notificationsRef.current.find((item) => item.id === notification.id);
        let unreadDelta = 0;
        if (existingNotification) {
          if (!existingNotification.readAt && notification.readAt) unreadDelta = -1;
          if (existingNotification.readAt && !notification.readAt) unreadDelta = 1;
        }
        updateNotifications((current) => {
          const existing = current.find((item) => item.id === notification.id);
          if (!existing) return current;
          return mergeNotifications(current, [notification], limit);
        });
        if (unreadDelta !== 0) {
          updateUnreadCount((current) => current + unreadDelta);
        }
        if (!existingNotification) {
          void loadNotifications({ silent: true });
        }
      },
      onError: () => {
        void loadNotifications({ silent: true });
      },
      onReconnect: () => {
        if (!hasSubscribedOnce) {
          hasSubscribedOnce = true;
          return;
        }
        void loadNotifications({ silent: true });
      },
      onDelete: (notificationId) => {
        if (profileIdRef.current !== subscriptionProfileId) return;
        const deletedNotification = notificationsRef.current.find((notification) => notification.id === notificationId);
        updateNotifications((current) => {
          const deleted = current.find((notification) => notification.id === notificationId);
          if (!deleted) return current;
          return current.filter((notification) => notification.id !== notificationId);
        });
        if (deletedNotification && !deletedNotification.readAt) {
          updateUnreadCount((count) => count - 1);
        }
        if (!deletedNotification) {
          void loadNotifications({ silent: true });
        }
      },
    });
    channelRef.current = channel;

    return () => {
      if (channelRef.current === channel) {
        channelRef.current = null;
      }
      void unsubscribeFromNotifications(channel);
    };
  }, [commitNotifications, commitUnreadCount, limit, loadNotifications, profileId, updateNotifications, updateUnreadCount]);

  const markOneRead = useCallback(async (notificationId: string) => {
    if (pendingReadIdsRef.current.has(notificationId)) return true;
    setMutationError(null);
    pendingReadIdsRef.current.add(notificationId);
    const optimisticReadAt = new Date().toISOString();
    const existingNotification = notificationsRef.current.find((notification) => notification.id === notificationId);
    const optimisticallyMarkedUnread = Boolean(existingNotification && !existingNotification.readAt);

    updateNotifications((current) => current.map((notification) => {
      if (notification.id !== notificationId || notification.readAt) return notification;
      return { ...notification, readAt: optimisticReadAt };
    }));

    if (optimisticallyMarkedUnread) {
      updateUnreadCount((current) => current - 1);
    }

    try {
      const readAt = await markNotificationRead(notificationId);
      updateNotifications((current) => current.map((notification) =>
        notification.id === notificationId
          ? { ...notification, readAt }
          : notification
      ));
      return true;
    } catch (error) {
      setMutationError(getErrorMessage(error, 'Không thể cập nhật trạng thái thông báo.'));
      await loadNotifications({ silent: true });
      return false;
    } finally {
      pendingReadIdsRef.current.delete(notificationId);
    }
  }, [loadNotifications, updateNotifications, updateUnreadCount]);

  const markAllRead = useCallback(async () => {
    if (markAllInFlightRef.current) return false;
    setMutationError(null);
    markAllInFlightRef.current = true;

    try {
      await markAllNotificationsRead();
      const readAt = new Date().toISOString();
      updateNotifications((current) => current.map((notification) => (
        notification.readAt ? notification : { ...notification, readAt }
      )));
      await loadNotifications({ silent: true });
      return true;
    } catch (error) {
      setMutationError(getErrorMessage(error, 'Không thể cập nhật trạng thái thông báo.'));
      await loadNotifications({ silent: true });
      return false;
    } finally {
      markAllInFlightRef.current = false;
    }
  }, [loadNotifications, updateNotifications]);

  const deleteOne = useCallback(async (notificationId: string) => {
    if (pendingDeleteIdsRef.current.has(notificationId)) return false;
    setMutationError(null);
    pendingDeleteIdsRef.current.add(notificationId);
    setDeletingIds((current) => new Set(current).add(notificationId));

    try {
      const result = await deleteNotification(notificationId);
      const deletedNotification = notificationsRef.current.find((notification) => notification.id === result.notificationId);
      updateNotifications((current) => {
        const deleted = current.find((notification) => notification.id === result.notificationId);
        return deleted ? current.filter((notification) => notification.id !== result.notificationId) : current;
      });
      if (deletedNotification && !deletedNotification.readAt) {
        updateUnreadCount((current) => current - 1);
      }
      return true;
    } catch (error) {
      setMutationError(getErrorMessage(error, 'Không thể xóa thông báo.'));
      await loadNotifications({ silent: true });
      return false;
    } finally {
      pendingDeleteIdsRef.current.delete(notificationId);
      setDeletingIds((current) => {
        const next = new Set(current);
        next.delete(notificationId);
        return next;
      });
    }
  }, [loadNotifications, updateNotifications, updateUnreadCount]);

  const deleteOlderThan = useCallback(async (days = 15) => {
    if (isDeletingOlder) return null;
    setMutationError(null);
    setIsDeletingOlder(true);

    try {
      const result = await deleteNotificationsOlderThan(days);
      await loadNotifications({ silent: true });
      return result;
    } catch (error) {
      setMutationError(getErrorMessage(error, 'Không thể xóa thông báo cũ.'));
      await loadNotifications({ silent: true });
      return null;
    } finally {
      setIsDeletingOlder(false);
    }
  }, [isDeletingOlder, loadNotifications]);

  return {
    notifications,
    unreadCount,
    isLoading,
    loadError,
    mutationError,
    deletingIds,
    isDeletingOlder,
    refetch: loadNotifications,
    markOneRead,
    markAllRead,
    deleteOne,
    deleteOlderThan,
  };
}
