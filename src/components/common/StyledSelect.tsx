import { Children, isValidElement, useCallback, useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useLocation } from 'react-router-dom';
import { ChevronDown, Check } from 'lucide-react';
import type { CSSProperties, ChangeEvent, KeyboardEvent, ReactElement, ReactNode, SelectHTMLAttributes } from 'react';

type StyledSelectProps = SelectHTMLAttributes<HTMLSelectElement>;

interface SelectOption {
  value: string;
  label: ReactNode;
  disabled: boolean;
}

interface MenuPosition {
  top: number;
  left: number;
  width: number;
  maxHeight: number;
  placement: 'top' | 'bottom';
}

type OptionElement = ReactElement<{
  value?: string | number;
  children?: ReactNode;
  disabled?: boolean;
}>;

function getTextLabel(label: ReactNode) {
  if (typeof label === 'string') return label;
  if (typeof label === 'number') return String(label);
  return '';
}

function createChangeEvent(value: string, name?: string) {
  return {
    target: { value, name },
    currentTarget: { value, name },
  } as ChangeEvent<HTMLSelectElement>;
}

function optionDomId(listboxId: string, value: string) {
  return `${listboxId}-${encodeURIComponent(value).replace(/%/g, '')}`;
}

export function StyledSelect({
  id,
  name,
  className = '',
  children,
  value,
  defaultValue,
  disabled,
  onChange,
  style,
}: StyledSelectProps) {
  const location = useLocation();
  const generatedId = useId();
  const resolvedId = id ?? `styled-select-${generatedId}`;
  const listboxId = `${resolvedId}-listbox`;
  const rootRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [menuPosition, setMenuPosition] = useState<MenuPosition | null>(null);
  const [highlightedValue, setHighlightedValue] = useState('');

  const options = useMemo<SelectOption[]>(() =>
    Children.toArray(children)
      .filter(isValidElement)
      .map((child) => {
        const option = child as OptionElement;
        const optionValue = option.props.value ?? getTextLabel(option.props.children);

        return {
          value: String(optionValue),
          label: option.props.children ?? String(optionValue),
          disabled: Boolean(option.props.disabled),
        };
      }),
    [children]
  );

  const firstEnabledValue = options.find((option) => !option.disabled)?.value ?? '';
  const isControlled = value !== undefined;
  const [internalValue, setInternalValue] = useState(() => String(defaultValue ?? firstEnabledValue));
  const selectedValue = String(isControlled ? value : internalValue);
  const selectedOption = options.find((option) => option.value === selectedValue) ?? options[0] ?? null;
  const enabledOptions = useMemo(() => options.filter((option) => !option.disabled), [options]);

  const closeMenu = useCallback((restoreFocus = false) => {
    setOpen(false);
    setMenuPosition(null);
    if (restoreFocus) {
      window.requestAnimationFrame(() => buttonRef.current?.focus());
    }
  }, []);

  useEffect(() => {
    if (!isControlled && defaultValue !== undefined) {
      setInternalValue(String(defaultValue));
    }
  }, [defaultValue, isControlled]);

  const updateMenuPosition = useCallback(() => {
    const trigger = buttonRef.current;
    if (!trigger || !trigger.isConnected) {
      closeMenu();
      return;
    }

    const rect = trigger.getBoundingClientRect();
    const viewportPadding = 12;
    const triggerVisible = rect.width > 0
      && rect.height > 0
      && rect.bottom > viewportPadding
      && rect.top < window.innerHeight - viewportPadding
      && rect.right > viewportPadding
      && rect.left < window.innerWidth - viewportPadding;

    const modalScrollViewport = rootRef.current?.closest<HTMLElement>('.member-modal-body, .modal-scroll-body');
    const modalPanel = rootRef.current?.closest<HTMLElement>('.modal-card');
    const modalBoundary = modalScrollViewport ?? modalPanel;
    const modalBoundaryRect = modalBoundary?.getBoundingClientRect();
    const triggerVisibleInModal = !modalBoundaryRect
      || (
        rect.bottom > modalBoundaryRect.top + 8
        && rect.top < modalBoundaryRect.bottom - 8
        && rect.right > modalBoundaryRect.left + 8
        && rect.left < modalBoundaryRect.right - 8
      );

    if (!triggerVisible || !triggerVisibleInModal) {
      closeMenu();
      return;
    }

    const preferredMaxHeight = 320;
    const bottomSpace = window.innerHeight - rect.bottom - viewportPadding;
    const topSpace = rect.top - viewportPadding;
    const openUp = bottomSpace < 180 && topSpace > bottomSpace;
    const availableSpace = Math.max(110, openUp ? topSpace - 8 : bottomSpace - 8);
    const maxHeight = Math.max(110, Math.min(preferredMaxHeight, availableSpace));
    const width = Math.min(rect.width, window.innerWidth - viewportPadding * 2);

    setMenuPosition({
      top: openUp ? Math.max(viewportPadding, rect.top - maxHeight - 8) : Math.min(rect.bottom + 8, window.innerHeight - maxHeight - viewportPadding),
      left: Math.min(Math.max(viewportPadding, rect.left), window.innerWidth - width - viewportPadding),
      width,
      maxHeight,
      placement: openUp ? 'top' : 'bottom',
    });
  }, [closeMenu]);

  useLayoutEffect(() => {
    if (!open) return;
    updateMenuPosition();
  }, [open, updateMenuPosition, selectedValue]);

  useEffect(() => {
    if (!open) return;

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (rootRef.current?.contains(target) || menuRef.current?.contains(target)) return;
      closeMenu();
    };
    const handleKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeMenu(true);
      }
    };
    const handleViewportChange = () => updateMenuPosition();

    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('scroll', handleViewportChange, true);
    window.addEventListener('resize', handleViewportChange);

    const observer = new ResizeObserver(handleViewportChange);
    if (buttonRef.current) observer.observe(buttonRef.current);
    const modalScrollViewport = rootRef.current?.closest<HTMLElement>('.member-modal-body, .modal-scroll-body');
    if (modalScrollViewport) observer.observe(modalScrollViewport);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
      document.removeEventListener('scroll', handleViewportChange, true);
      window.removeEventListener('resize', handleViewportChange);
      observer.disconnect();
    };
  }, [closeMenu, open, updateMenuPosition]);

  useEffect(() => {
    closeMenu();
  }, [closeMenu, location.pathname]);

  useEffect(() => {
    if (!open) return;
    setHighlightedValue(selectedOption?.value ?? enabledOptions[0]?.value ?? '');
  }, [enabledOptions, open, selectedOption?.value]);

  const commitValue = (nextValue: string) => {
    const option = options.find((item) => item.value === nextValue);
    if (!option || option.disabled || disabled) return;

    if (!isControlled) setInternalValue(nextValue);
    onChange?.(createChangeEvent(nextValue, name));
    closeMenu(true);
  };

  const openMenu = () => {
    if (disabled) return;
    updateMenuPosition();
    setHighlightedValue(selectedOption?.value ?? enabledOptions[0]?.value ?? '');
    setOpen(true);
  };

  const toggleMenu = () => {
    if (disabled) return;
    if (open) {
      closeMenu();
      return;
    }
    openMenu();
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (disabled) return;

    if (event.key === 'Escape') {
      closeMenu(true);
      return;
    }

    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      if (open && highlightedValue) {
        commitValue(highlightedValue);
        return;
      }
      toggleMenu();
      return;
    }

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      if (!open) {
        openMenu();
        return;
      }
      const currentIndex = enabledOptions.findIndex((option) => option.value === selectedValue);
      const highlightedIndex = enabledOptions.findIndex((option) => option.value === highlightedValue);
      const direction = event.key === 'ArrowDown' ? 1 : -1;
      const baseIndex = highlightedIndex >= 0 ? highlightedIndex : currentIndex;
      const nextIndex = baseIndex < 0
        ? 0
        : (baseIndex + direction + enabledOptions.length) % enabledOptions.length;
      const nextOption = enabledOptions[nextIndex];
      if (nextOption) setHighlightedValue(nextOption.value);
    }
  };

  return (
    <div
      ref={rootRef}
      className={`styled-select-root ${className}`.trim()}
      style={style as CSSProperties}
      data-disabled={disabled ? 'true' : undefined}
    >
      {name ? <input type="hidden" name={name} value={selectedOption?.value ?? ''} disabled={disabled} /> : null}
      <button
        ref={buttonRef}
        id={resolvedId}
        type="button"
        className="field styled-select-trigger"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listboxId}
        aria-activedescendant={open && highlightedValue ? optionDomId(listboxId, highlightedValue) : undefined}
        onClick={toggleMenu}
        onKeyDown={handleKeyDown}
      >
        <span className="styled-select-value">{selectedOption?.label ?? 'Chọn'}</span>
        <ChevronDown className="styled-select-arrow" />
      </button>

      {open && menuPosition ? createPortal(
        <div
          ref={menuRef}
          id={listboxId}
          className="styled-select-menu"
          role="listbox"
          aria-labelledby={resolvedId}
          data-placement={menuPosition.placement}
          style={{
            top: menuPosition.top,
            left: menuPosition.left,
            width: menuPosition.width,
            maxHeight: menuPosition.maxHeight,
          }}
        >
          {options.map((option) => {
          const selected = option.value === selectedValue;
          const highlighted = option.value === highlightedValue;

          return (
            <button
              key={option.value}
              id={optionDomId(listboxId, option.value)}
              type="button"
              className="styled-select-option"
              role="option"
              aria-selected={selected}
              data-highlighted={highlighted ? 'true' : undefined}
              disabled={option.disabled}
              onMouseEnter={() => setHighlightedValue(option.value)}
              onClick={() => commitValue(option.value)}
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
