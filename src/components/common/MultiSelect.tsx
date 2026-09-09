import { useCallback, useEffect, useId, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useLocation } from 'react-router-dom';
import { Check, ChevronDown } from 'lucide-react';
import type { CSSProperties } from 'react';

export interface MultiSelectOption {
  value: string;
  label: string;
}

interface MenuPosition {
  top: number;
  left: number;
  width: number;
  maxHeight: number;
  placement: 'top' | 'bottom';
}

interface MultiSelectProps {
  options: MultiSelectOption[];
  values: string[];
  onChange: (values: string[]) => void;
  allLabel: string;
  summaryUnit?: string;
  className?: string;
  ariaLabel?: string;
  style?: CSSProperties;
}

export function MultiSelect({
  options,
  values,
  onChange,
  allLabel,
  summaryUnit,
  className = '',
  ariaLabel,
  style,
}: MultiSelectProps) {
  const location = useLocation();
  const generatedId = useId();
  const listboxId = `${generatedId}-listbox`;
  const rootRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [menuPosition, setMenuPosition] = useState<MenuPosition | null>(null);

  const closeMenu = useCallback(() => {
    setOpen(false);
    setMenuPosition(null);
  }, []);

  const updateMenuPosition = useCallback(() => {
    const trigger = buttonRef.current;
    if (!trigger || !trigger.isConnected) {
      closeMenu();
      return;
    }

    const rect = trigger.getBoundingClientRect();
    const padding = 12;
    const bottomSpace = window.innerHeight - rect.bottom - padding;
    const topSpace = rect.top - padding;
    const openUp = bottomSpace < 180 && topSpace > bottomSpace;
    const maxHeight = Math.max(110, Math.min(320, Math.max(110, (openUp ? topSpace : bottomSpace) - 8)));
    const width = Math.max(rect.width, 168);

    setMenuPosition({
      top: openUp
        ? Math.max(padding, rect.top - maxHeight - 8)
        : Math.min(rect.bottom + 8, window.innerHeight - maxHeight - padding),
      left: Math.min(Math.max(padding, rect.left), Math.max(padding, window.innerWidth - width - padding)),
      width,
      maxHeight,
      placement: openUp ? 'top' : 'bottom',
    });
  }, [closeMenu]);

  useLayoutEffect(() => {
    if (!open) return;
    updateMenuPosition();
  }, [open, updateMenuPosition, values]);

  useEffect(() => {
    if (!open) return undefined;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (rootRef.current?.contains(target) || menuRef.current?.contains(target)) return;
      closeMenu();
    };
    const handleKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      closeMenu();
      buttonRef.current?.focus();
    };
    const handleViewportChange = () => updateMenuPosition();

    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('scroll', handleViewportChange, true);
    window.addEventListener('resize', handleViewportChange);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
      document.removeEventListener('scroll', handleViewportChange, true);
      window.removeEventListener('resize', handleViewportChange);
    };
  }, [closeMenu, open, updateMenuPosition]);

  useEffect(() => {
    closeMenu();
  }, [closeMenu, location.pathname]);

  const toggleValue = (value: string) => {
    onChange(values.includes(value) ? values.filter((item) => item !== value) : [...values, value]);
  };

  const triggerLabel = values.length === 0
    ? allLabel
    : values.length === 1
      ? options.find((option) => option.value === values[0])?.label ?? allLabel
      : `${values.length} ${summaryUnit ?? 'mục'}`;

  return (
    <div ref={rootRef} className={`styled-select-root ${className}`.trim()} style={style}>
      <button
        ref={buttonRef}
        type="button"
        className="field styled-select-trigger"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listboxId}
        aria-label={ariaLabel}
        onClick={() => setOpen((value) => !value)}
      >
        <span className="styled-select-value">{triggerLabel}</span>
        <ChevronDown className="styled-select-arrow" />
      </button>

      {open && menuPosition ? createPortal(
        <div
          ref={menuRef}
          id={listboxId}
          className="styled-select-menu"
          role="listbox"
          aria-multiselectable="true"
          data-placement={menuPosition.placement}
          style={{
            top: menuPosition.top,
            left: menuPosition.left,
            width: menuPosition.width,
            maxHeight: menuPosition.maxHeight,
          }}
        >
          <button
            type="button"
            className="styled-select-option"
            role="option"
            aria-selected={values.length === 0}
            onClick={() => onChange([])}
          >
            <span className="truncate">{allLabel}</span>
            {values.length === 0 ? <Check /> : null}
          </button>

          <div className="styled-select-sep" />

          {options.map((option) => {
            const selected = values.includes(option.value);
            return (
              <button
                key={option.value}
                type="button"
                className="styled-select-option"
                role="option"
                aria-selected={selected}
                onClick={() => toggleValue(option.value)}
              >
                <span className="truncate">{option.label}</span>
                {selected ? <Check /> : null}
              </button>
            );
          })}
        </div>,
        document.body
      ) : null}
    </div>
  );
}
