import { Children, isValidElement, useCallback, useEffect, useId, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
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
  const generatedId = useId();
  const resolvedId = id ?? `styled-select-${generatedId}`;
  const rootRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [menuPosition, setMenuPosition] = useState<MenuPosition | null>(null);

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

  useEffect(() => {
    if (!isControlled && defaultValue !== undefined) {
      setInternalValue(String(defaultValue));
    }
  }, [defaultValue, isControlled]);

  const updateMenuPosition = useCallback(() => {
    const trigger = buttonRef.current;
    if (!trigger) return;

    const rect = trigger.getBoundingClientRect();
    const viewportPadding = 12;
    const preferredMaxHeight = 280;
    const bottomSpace = window.innerHeight - rect.bottom - viewportPadding;
    const topSpace = rect.top - viewportPadding;
    const openUp = bottomSpace < 170 && topSpace > bottomSpace;
    const maxHeight = Math.max(156, Math.min(preferredMaxHeight, openUp ? topSpace - 8 : bottomSpace - 8));

    setMenuPosition({
      top: openUp ? Math.max(viewportPadding, rect.top - maxHeight - 8) : rect.bottom + 8,
      left: Math.min(Math.max(viewportPadding, rect.left), window.innerWidth - rect.width - viewportPadding),
      width: rect.width,
      maxHeight,
    });
  }, []);

  useEffect(() => {
    if (!open) return;
    updateMenuPosition();

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (rootRef.current?.contains(target) || menuRef.current?.contains(target)) return;
      setOpen(false);
    };
    const handleViewportChange = () => updateMenuPosition();

    document.addEventListener('pointerdown', handlePointerDown);
    window.addEventListener('resize', handleViewportChange);
    window.addEventListener('scroll', handleViewportChange, true);

    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      window.removeEventListener('resize', handleViewportChange);
      window.removeEventListener('scroll', handleViewportChange, true);
    };
  }, [open, updateMenuPosition]);

  const commitValue = (nextValue: string) => {
    const option = options.find((item) => item.value === nextValue);
    if (!option || option.disabled || disabled) return;

    if (!isControlled) setInternalValue(nextValue);
    onChange?.(createChangeEvent(nextValue, name));
    setOpen(false);
  };

  const openMenu = () => {
    if (disabled) return;
    updateMenuPosition();
    setOpen(true);
  };

  const toggleMenu = () => {
    if (disabled) return;
    if (open) {
      setOpen(false);
      return;
    }
    openMenu();
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (disabled) return;

    if (event.key === 'Escape') {
      setOpen(false);
      return;
    }

    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      toggleMenu();
      return;
    }

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const enabledOptions = options.filter((option) => !option.disabled);
      const currentIndex = enabledOptions.findIndex((option) => option.value === selectedValue);
      const direction = event.key === 'ArrowDown' ? 1 : -1;
      const nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + direction + enabledOptions.length) % enabledOptions.length;
      const nextOption = enabledOptions[nextIndex];
      if (nextOption) commitValue(nextOption.value);
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
        aria-controls={`${resolvedId}-listbox`}
        onClick={toggleMenu}
        onKeyDown={handleKeyDown}
      >
        <span className="styled-select-value">{selectedOption?.label ?? 'Chọn'}</span>
        <ChevronDown className="styled-select-arrow" />
      </button>

      {open && menuPosition ? createPortal(
        <div
          ref={menuRef}
          id={`${resolvedId}-listbox`}
          className="styled-select-menu"
          role="listbox"
          aria-labelledby={resolvedId}
          style={{
            top: menuPosition.top,
            left: menuPosition.left,
            width: menuPosition.width,
            maxHeight: menuPosition.maxHeight,
          }}
        >
          {options.map((option) => {
          const selected = option.value === selectedValue;

          return (
            <button
              key={option.value}
              type="button"
              className="styled-select-option"
              role="option"
              aria-selected={selected}
              disabled={option.disabled}
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
