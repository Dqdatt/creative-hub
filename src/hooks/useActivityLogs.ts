import { useCallback, useEffect, useState } from 'react';
import { fetchRecentActivityLogs } from '../services/activityLogService';
import type { ActivityLog } from '../types/activityLog';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

export function useActivityLogs(limit = 20) {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadLogs = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);

    try {
      const nextLogs = await fetchRecentActivityLogs(limit);
      setLogs(nextLogs);
    } catch (error) {
      setLoadError(getErrorMessage(error, 'Không thể tải nhật ký hoạt động. Vui lòng thử lại.'));
      setLogs([]);
    } finally {
      setIsLoading(false);
    }
  }, [limit]);

  useEffect(() => {
    void loadLogs();
  }, [loadLogs]);

  return {
    logs,
    isLoading,
    loadError,
    isEmpty: !isLoading && !loadError && logs.length === 0,
    refetch: loadLogs,
  };
}
