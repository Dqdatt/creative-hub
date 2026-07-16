import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/authContext';
import {
  assignEditorToContentPlan,
  createContentPlanRow,
  deleteContentPlanRow,
  fetchContentPlan,
  fetchContentPlanEditorOptions,
  updateContentPlanRow,
} from '../services/contentPlanService';
import type { ContentPlanEditorOption, ContentPlanFormData, ContentPlanItem } from '../types/contentPlan';
import { useRealtimeSubscription } from './useRealtimeSubscription';

function getErrorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}

interface LoadOptions {
  silent?: boolean;
}

export function useContentPlan(monthValue: string) {
  const { user } = useAuth();
  const requestIdRef = useRef(0);
  const [items, setItems] = useState<ContentPlanItem[]>([]);
  const [editorOptions, setEditorOptions] = useState<ContentPlanEditorOption[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  const loadContentPlan = useCallback(async (options?: LoadOptions) => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!options?.silent) {
      setIsLoading(true);
    }
    setLoadError(null);

    try {
      const [nextItems, nextEditors] = await Promise.all([
        fetchContentPlan(monthValue),
        fetchContentPlanEditorOptions(),
      ]);
      if (requestId !== requestIdRef.current) return;
      setItems(nextItems);
      setEditorOptions(nextEditors);
    } catch (error) {
      if (requestId !== requestIdRef.current) return;
      setLoadError(getErrorMessage(error, 'Không thể tải Content Plan. Vui lòng thử lại.'));
      setItems([]);
      setEditorOptions([]);
    } finally {
      if (requestId === requestIdRef.current) {
        setIsLoading(false);
      }
    }
  }, [monthValue]);

  useEffect(() => {
    void loadContentPlan();
  }, [loadContentPlan]);

  useRealtimeSubscription({
    tables: ['content_plan'],
    onChange: () => loadContentPlan({ silent: true }),
  });

  const createItem = useCallback(async (data: ContentPlanFormData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      await createContentPlanRow(data, user?.id);
      await loadContentPlan();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu lịch air. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadContentPlan, user?.id]);

  const updateItem = useCallback(async (item: ContentPlanItem, data: ContentPlanFormData) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      await updateContentPlanRow(item.id, data, user?.id, item);
      await loadContentPlan();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể lưu lịch air. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadContentPlan, user?.id]);

  const assignEditor = useCallback(async (item: ContentPlanItem, editorId: string) => {
    setIsSaving(true);
    setSaveError(null);

    try {
      await assignEditorToContentPlan(item.id, editorId);
      await loadContentPlan();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể phân công editor. Vui lòng thử lại.'));
      await loadContentPlan({ silent: true });
      return false;
    } finally {
      setIsSaving(false);
    }
  }, [loadContentPlan]);

  const deleteItem = useCallback(async (item: ContentPlanItem) => {
    setIsDeleting(true);
    setSaveError(null);

    try {
      await deleteContentPlanRow(item.id);
      await loadContentPlan();
      return true;
    } catch (error) {
      setSaveError(getErrorMessage(error, 'Không thể xóa lịch air. Vui lòng thử lại.'));
      return false;
    } finally {
      setIsDeleting(false);
    }
  }, [loadContentPlan]);

  const clearSaveError = useCallback(() => {
    setSaveError(null);
  }, []);

  return {
    items,
    editorOptions,
    isLoading,
    isSaving,
    isDeleting,
    loadError,
    saveError,
    refetch: loadContentPlan,
    createItem,
    updateItem,
    assignEditor,
    deleteItem,
    clearSaveError,
  };
}
