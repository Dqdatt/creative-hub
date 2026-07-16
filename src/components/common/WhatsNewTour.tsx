import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useLocation, useNavigate } from 'react-router-dom';
import { X } from 'lucide-react';
import { PRODUCT_UPDATE } from '../../config/productUpdates';
import { canAccessRoute } from '../../config/permissions';
import type { AppRole, EffectivePermissions } from '../../config/permissions';

type Placement = 'right' | 'left' | 'bottom' | 'top' | 'center';

interface WhatsNewTourProps {
  open: boolean;
  role: AppRole;
  permissions: EffectivePermissions;
  onClose: () => void;
}

interface SpotlightRect {
  top: number;
  left: number;
  width: number;
  height: number;
}

interface PopoverLayout {
  top: number;
  left: number;
  placement: Placement;
}

const SPOTLIGHT_PAD = 8;
const VIEWPORT_MARGIN = 16;
const POPOVER_GAP = 14;
const ESTIMATED_POPOVER_WIDTH = 360;
const ESTIMATED_POPOVER_HEIGHT = 230;
const MAX_TARGET_WAIT_FRAMES = 70;

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function getVisibleElement(selectors: readonly string[]) {
  for (const selector of selectors) {
    const elements = Array.from(document.querySelectorAll<HTMLElement>(selector));
    const visibleElement = elements.find((element) => {
      const rect = element.getBoundingClientRect();
      const styles = window.getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 && styles.visibility !== 'hidden' && styles.display !== 'none';
    });

    if (visibleElement) return visibleElement;
  }

  return null;
}

function getSpotlightRect(target: HTMLElement): SpotlightRect {
  const rect = target.getBoundingClientRect();
  const top = Math.max(VIEWPORT_MARGIN, rect.top - SPOTLIGHT_PAD);
  const left = Math.max(VIEWPORT_MARGIN, rect.left - SPOTLIGHT_PAD);
  const right = Math.min(window.innerWidth - VIEWPORT_MARGIN, rect.right + SPOTLIGHT_PAD);
  const bottom = Math.min(window.innerHeight - VIEWPORT_MARGIN, rect.bottom + SPOTLIGHT_PAD);

  return {
    top,
    left,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top),
  };
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

function resolvePopoverLayout(rect: SpotlightRect | null, popoverWidth: number, popoverHeight: number): PopoverLayout {
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const maxLeft = Math.max(VIEWPORT_MARGIN, viewportWidth - popoverWidth - VIEWPORT_MARGIN);
  const maxTop = Math.max(VIEWPORT_MARGIN, viewportHeight - popoverHeight - VIEWPORT_MARGIN);

  if (!rect || rect.width <= 0 || rect.height <= 0) {
    return {
      placement: 'center',
      left: clamp((viewportWidth - popoverWidth) / 2, VIEWPORT_MARGIN, maxLeft),
      top: clamp((viewportHeight - popoverHeight) / 2, VIEWPORT_MARGIN, maxTop),
    };
  }

  const canPlaceRight = viewportWidth - rect.left - rect.width >= popoverWidth + POPOVER_GAP + VIEWPORT_MARGIN;
  if (canPlaceRight) {
    return {
      placement: 'right',
      left: rect.left + rect.width + POPOVER_GAP,
      top: clamp(rect.top + rect.height / 2 - popoverHeight / 2, VIEWPORT_MARGIN, maxTop),
    };
  }

  const canPlaceLeft = rect.left >= popoverWidth + POPOVER_GAP + VIEWPORT_MARGIN;
  if (canPlaceLeft) {
    return {
      placement: 'left',
      left: rect.left - popoverWidth - POPOVER_GAP,
      top: clamp(rect.top + rect.height / 2 - popoverHeight / 2, VIEWPORT_MARGIN, maxTop),
    };
  }

  const canPlaceBottom = viewportHeight - rect.top - rect.height >= popoverHeight + POPOVER_GAP + VIEWPORT_MARGIN;
  if (canPlaceBottom) {
    return {
      placement: 'bottom',
      left: clamp(rect.left + rect.width / 2 - popoverWidth / 2, VIEWPORT_MARGIN, maxLeft),
      top: rect.top + rect.height + POPOVER_GAP,
    };
  }

  const canPlaceTop = rect.top >= popoverHeight + POPOVER_GAP + VIEWPORT_MARGIN;
  if (canPlaceTop) {
    return {
      placement: 'top',
      left: clamp(rect.left + rect.width / 2 - popoverWidth / 2, VIEWPORT_MARGIN, maxLeft),
      top: rect.top - popoverHeight - POPOVER_GAP,
    };
  }

  return {
    placement: 'center',
    left: clamp((viewportWidth - popoverWidth) / 2, VIEWPORT_MARGIN, maxLeft),
    top: clamp((viewportHeight - popoverHeight) / 2, VIEWPORT_MARGIN, maxTop),
  };
}

function getPageScroller() {
  return document.getElementById('view') ?? document.scrollingElement ?? document.documentElement;
}

export function WhatsNewTour({ open, role, permissions, onClose }: WhatsNewTourProps) {
  const [stepIndex, setStepIndex] = useState(0);
  const [target, setTarget] = useState<HTMLElement | null>(null);
  const [spotlightRect, setSpotlightRect] = useState<SpotlightRect | null>(null);
  const [popoverLayout, setPopoverLayout] = useState<PopoverLayout>(() =>
    resolvePopoverLayout(null, ESTIMATED_POPOVER_WIDTH, ESTIMATED_POPOVER_HEIGHT)
  );
  const [startedPath, setStartedPath] = useState<string | null>(null);
  const popoverRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const wasOpenRef = useRef(false);
  const navigate = useNavigate();
  const location = useLocation();
  const step = PRODUCT_UPDATE.steps[stepIndex];
  const lastStepIndex = PRODUCT_UPDATE.steps.length - 1;
  const canUseStepRoute = canAccessRoute(role, step.route, permissions);

  const targetSelectors = useMemo(() => (
    canUseStepRoute ? step.targets : []
  ), [canUseStepRoute, step.targets]);

  const updateLayout = useCallback((nextTarget: HTMLElement | null = target) => {
    const nextRect = nextTarget ? getSpotlightRect(nextTarget) : null;
    const popoverRect = popoverRef.current?.getBoundingClientRect();
    const popoverWidth = popoverRect?.width || ESTIMATED_POPOVER_WIDTH;
    const popoverHeight = popoverRect?.height || ESTIMATED_POPOVER_HEIGHT;

    setSpotlightRect(nextRect);
    setPopoverLayout(resolvePopoverLayout(nextRect, popoverWidth, popoverHeight));
  }, [target]);

  const closeTour = useCallback(() => {
    onClose();

    if (startedPath && startedPath !== location.pathname && canAccessRoute(role, startedPath, permissions)) {
      navigate(startedPath, { replace: true });
    }
  }, [location.pathname, navigate, onClose, permissions, role, startedPath]);

  useEffect(() => {
    if (!open) {
      wasOpenRef.current = false;
      setStepIndex(0);
      setTarget(null);
      setSpotlightRect(null);
      setStartedPath(null);
      return;
    }

    if (wasOpenRef.current) return;
    wasOpenRef.current = true;
    setStartedPath(location.pathname);
    setStepIndex(0);
    window.requestAnimationFrame(() => closeButtonRef.current?.focus());
  }, [location.pathname, open]);

  useEffect(() => {
    if (!open) return undefined;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeTour();
        return;
      }

      if (event.key !== 'Tab') return;

      const focusables = popoverRef.current?.querySelectorAll<HTMLElement>(
        'button:not(:disabled), [href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])'
      );
      if (!focusables || focusables.length === 0) return;

      const first = focusables[0];
      const last = focusables[focusables.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [closeTour, open]);

  useEffect(() => {
    if (!open) return undefined;
    setTarget(null);
    setSpotlightRect(null);

    if (canUseStepRoute && location.pathname !== step.route) {
      navigate(step.route);
      return undefined;
    }

    let frameId = 0;
    let cancelled = false;
    let attempts = 0;

    const locateTarget = () => {
      if (cancelled) return;

      const nextTarget = getVisibleElement(targetSelectors);
      if (nextTarget || attempts >= MAX_TARGET_WAIT_FRAMES) {
        const resolvedTarget = nextTarget ?? null;
        setTarget(resolvedTarget);

        if (resolvedTarget) {
          resolvedTarget.scrollIntoView({
            block: 'center',
            inline: 'nearest',
            behavior: prefersReducedMotion() ? 'auto' : 'smooth',
          });

          window.requestAnimationFrame(() => updateLayout(resolvedTarget));
        } else {
          updateLayout(null);
        }
        return;
      }

      attempts += 1;
      frameId = window.requestAnimationFrame(locateTarget);
    };

    frameId = window.requestAnimationFrame(locateTarget);

    return () => {
      cancelled = true;
      window.cancelAnimationFrame(frameId);
    };
  }, [canUseStepRoute, location.pathname, navigate, open, step.route, targetSelectors, updateLayout]);

  useEffect(() => {
    if (!open) return undefined;

    let frameId = 0;
    const requestLayoutUpdate = () => {
      window.cancelAnimationFrame(frameId);
      frameId = window.requestAnimationFrame(() => updateLayout());
    };
    const scroller = getPageScroller();
    const observer = new ResizeObserver(requestLayoutUpdate);

    window.addEventListener('resize', requestLayoutUpdate);
    window.addEventListener('scroll', requestLayoutUpdate, true);
    scroller.addEventListener('scroll', requestLayoutUpdate);
    if (target) observer.observe(target);
    if (popoverRef.current) observer.observe(popoverRef.current);

    return () => {
      window.cancelAnimationFrame(frameId);
      window.removeEventListener('resize', requestLayoutUpdate);
      window.removeEventListener('scroll', requestLayoutUpdate, true);
      scroller.removeEventListener('scroll', requestLayoutUpdate);
      observer.disconnect();
    };
  }, [open, target, updateLayout]);

  if (!open) return null;

  const canGoBack = stepIndex > 0;
  const isLastStep = stepIndex === lastStepIndex;
  const stepLabel = `${stepIndex + 1} / ${PRODUCT_UPDATE.steps.length}`;

  const goBack = () => {
    setStepIndex((current) => Math.max(0, current - 1));
  };

  const goNext = () => {
    if (isLastStep) {
      closeTour();
      return;
    }

    setStepIndex((current) => Math.min(lastStepIndex, current + 1));
  };

  const panelStyles = spotlightRect
    ? {
        top: { left: 0, top: 0, width: '100%', height: spotlightRect.top },
        right: { left: spotlightRect.left + spotlightRect.width, top: spotlightRect.top, width: `calc(100% - ${spotlightRect.left + spotlightRect.width}px)`, height: spotlightRect.height },
        bottom: { left: 0, top: spotlightRect.top + spotlightRect.height, width: '100%', height: `calc(100% - ${spotlightRect.top + spotlightRect.height}px)` },
        left: { left: 0, top: spotlightRect.top, width: spotlightRect.left, height: spotlightRect.height },
      }
    : null;
  const spotlightStyle = spotlightRect ?? undefined;

  return createPortal(
    <div className="whats-new-tour" aria-live="polite">
      {panelStyles ? (
        <>
          <div className="tour-dim-panel" style={panelStyles.top} />
          <div className="tour-dim-panel" style={panelStyles.right} />
          <div className="tour-dim-panel" style={panelStyles.bottom} />
          <div className="tour-dim-panel" style={panelStyles.left} />
          <div className="tour-spotlight-ring" style={spotlightStyle} />
          <div className="tour-spotlight-blocker" style={spotlightStyle} aria-hidden="true" />
        </>
      ) : (
        <div className="tour-dim-panel tour-dim-panel--full" />
      )}

      <section
        ref={popoverRef}
        className={`tour-popover tour-popover--${popoverLayout.placement}`}
        style={{ top: popoverLayout.top, left: popoverLayout.left }}
        role="dialog"
        aria-modal="true"
        aria-labelledby="whatsNewTourTitle"
        aria-describedby="whatsNewTourBody"
      >
        <button ref={closeButtonRef} type="button" className="tour-close icon-btn" onClick={closeTour} aria-label="Đóng">
          <X />
        </button>

        <div className="tour-label">CÓ GÌ MỚI</div>
        <h2 id="whatsNewTourTitle" className="tour-title">{step.title}</h2>
        <p id="whatsNewTourBody" className="tour-body">{step.body}</p>

        <div className="tour-footer">
          <span className="tour-step" aria-label={`Bước ${stepLabel}`}>{stepLabel}</span>
          <div className="tour-actions">
            {canGoBack ? (
              <button type="button" className="btn-ghost" onClick={goBack}>
                Quay lại
              </button>
            ) : null}
            <button type="button" className="btn" onClick={goNext}>
              {step.primaryLabel}
            </button>
          </div>
        </div>
      </section>
    </div>,
    document.body,
  );
}
