import { useEffect, useState } from 'react';

interface UseRouteHighlightOptions {
  targetId: string | null;
  selector: string | null;
  fallbackSelector?: string | null;
  ready: boolean;
  clearQuery: () => void;
  onMissing: () => void;
  durationMs?: number;
}

export const ROUTE_HIGHLIGHT_DURATION_MS = 850;
const MAX_RENDER_ATTEMPTS = 8;

export function useRouteHighlight({
  targetId,
  selector,
  fallbackSelector = null,
  ready,
  clearQuery,
  onMissing,
  durationMs = ROUTE_HIGHLIGHT_DURATION_MS,
}: UseRouteHighlightOptions) {
  const [activeTargetId, setActiveTargetId] = useState<string | null>(null);

  useEffect(() => {
    if (!targetId || !selector || !ready) return undefined;

    let cancelled = false;
    let attempts = 0;
    let frameId = 0;
    let timerId = 0;

    const activate = (element: Element) => {
      if (cancelled) return;
      element.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' });
      setActiveTargetId(targetId);
      timerId = window.setTimeout(() => {
        setActiveTargetId((current) => (current === targetId ? null : current));
        clearQuery();
      }, durationMs);
    };

    const findAndActivate = () => {
      if (cancelled) return;

      const element = document.querySelector(selector) ?? (fallbackSelector ? document.querySelector(fallbackSelector) : null);
      if (element) {
        activate(element);
        return;
      }

      attempts += 1;
      if (attempts <= MAX_RENDER_ATTEMPTS) {
        frameId = window.requestAnimationFrame(findAndActivate);
        return;
      }

      onMissing();
      clearQuery();
    };

    frameId = window.requestAnimationFrame(findAndActivate);

    return () => {
      cancelled = true;
      if (frameId) window.cancelAnimationFrame(frameId);
      if (timerId) window.clearTimeout(timerId);
    };
  }, [clearQuery, durationMs, fallbackSelector, onMissing, ready, selector, targetId]);

  return activeTargetId;
}
