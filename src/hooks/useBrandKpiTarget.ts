import { useCallback, useEffect, useRef, useState } from 'react';
import {
  clearBrandKpiTarget,
  fetchBrandKpiTarget,
  saveBrandKpiTarget,
  type BrandKpiTarget,
} from '../services/brandKpiService';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

// Chỉ tiêu KPI của BRAND theo tháng đang xem. Tháng chưa nhập thì target = null
// và dashboard chỉ hiện số đếm được.
export function useBrandKpiTarget(monthValue: string, enabled = true) {
  const requestIdRef = useRef(0);
  const [target, setTarget] = useState<BrandKpiTarget | null>(null);
  const [isLoading, setIsLoading] = useState(enabled);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!enabled) {
      setTarget(null);
      setIsLoading(false);
      return;
    }

    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    setIsLoading(true);
    setLoadError(null);

    try {
      const result = await fetchBrandKpiTarget(monthValue);
      if (requestId !== requestIdRef.current) return;
      setTarget(result);
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setTarget(null);
      setLoadError(getErrorMessage(error, 'Không thể tải KPI BRAND.'));
    } finally {
      if (requestId === requestIdRef.current) setIsLoading(false);
    }
  }, [enabled, monthValue]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = useCallback(async (longVideos: number, motion: number, userId?: string | null) => {
    const saved = await saveBrandKpiTarget({ monthValue, longVideos, motion }, userId);
    // Chốt ngay state để bảng cập nhật mà không cần chờ một vòng tải lại.
    requestIdRef.current += 1;
    setTarget(saved);
    setLoadError(null);
    return saved;
  }, [monthValue]);

  const clear = useCallback(async () => {
    await clearBrandKpiTarget(monthValue);
    requestIdRef.current += 1;
    setTarget(null);
    setLoadError(null);
  }, [monthValue]);

  return { target, isLoading, loadError, save, clear, refetch: load };
}
