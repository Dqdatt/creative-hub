import { useCallback, useEffect, useRef, useState } from 'react';
import { createShoot, deleteShoot, fetchShoots, updateShoot } from '../services/shootsService';
import { fetchContentPlanEditorOptions } from '../services/contentPlanService';
import type { ContentPlanEditorOption } from '../types/contentPlan';
import type { ShootFormData, ShootSchedule } from '../types/shoot';
import { useRealtimeSubscription } from './useRealtimeSubscription';

interface UseShootsOptions {
  startDate: string;
  endDate: string;
}

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

export function useShoots({ startDate, endDate }: UseShootsOptions) {
  const requestIdRef = useRef(0);
  const [shoots, setShoots] = useState<ShootSchedule[]>([]);
  const [editorOptions, setEditorOptions] = useState<ContentPlanEditorOption[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [modalError, setModalError] = useState<string | null>(null);

  const loadShoots = useCallback(async (options?: LoadOptions) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!options?.silent) {
      setIsLoading(true);
    }
    setLoadError(null);

    try {
      const [nextShoots, nextEditorOptions] = await Promise.all([
        fetchShoots(startDate, endDate),
        fetchContentPlanEditorOptions(),
      ]);
      if (requestId !== requestIdRef.current) return;
      setShoots(nextShoots);
      setEditorOptions(nextEditorOptions);
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setLoadError(getErrorMessage(error, 'Không thể tải lịch quay. Vui lòng thử lại.'));
      setShoots([]);
      setEditorOptions([]);
    } finally {
      if (requestId === requestIdRef.current) {
        setIsLoading(false);
      }
    }
  }, [endDate, startDate]);

  useEffect(() => {
    void loadShoots();
  }, [loadShoots]);

  useRealtimeSubscription({
    tables: ['shoots', 'shoot_editors'],
    onChange: () => loadShoots({ silent: true }),
  });

  const createShootSchedule = useCallback(async (data: ShootFormData) => {
    setIsSaving(true);
    setModalError(null);

    try {
      await createShoot(data);
      await loadShoots();
      return true;
    } catch (error) {
      setModalError(getErrorMessage(error, 'Không thể lưu lịch quay. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadShoots]);

  const updateShootSchedule = useCallback(async (shootId: string, data: ShootFormData) => {
    setIsSaving(true);
    setModalError(null);

    try {
      await updateShoot(shootId, data);
      await loadShoots();
      return true;
    } catch (error) {
      setModalError(getErrorMessage(error, 'Không thể lưu lịch quay. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadShoots]);

  const deleteShootSchedule = useCallback(async (shootId: string) => {
    setIsDeleting(true);
    setModalError(null);

    try {
      await deleteShoot(shootId);
      await loadShoots();
      return true;
    } catch (error) {
      setModalError(getErrorMessage(error, 'Không thể xóa lịch quay. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsDeleting(false);
    }
  }, [loadShoots]);

  const clearModalError = useCallback(() => {
    setModalError(null);
  }, []);

  return {
    shoots,
    editorOptions,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    modalError,
    refetch: loadShoots,
    createShoot: createShootSchedule,
    updateShoot: updateShootSchedule,
    deleteShoot: deleteShootSchedule,
    clearModalError,
  };
}
