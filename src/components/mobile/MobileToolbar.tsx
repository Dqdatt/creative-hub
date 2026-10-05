import { useState } from 'react';
import type { ReactNode } from 'react';
import { Search, SlidersHorizontal } from 'lucide-react';
import { BottomSheet } from './BottomSheet';
import { useMobileChrome } from './mobileChrome';

export interface ToolbarChip<T extends string> {
  value: T;
  label: string;
}

interface MobileToolbarProps<T extends string> {
  search: string;
  onSearchChange: (value: string) => void;
  searchPlaceholder: string;
  chips?: ToolbarChip<T>[];
  chipValue?: T;
  onChipChange?: (value: T) => void;
  chipsLabel?: string;
  /** Nội dung sheet Bộ lọc (các bộ lọc phụ). */
  filters?: ReactNode;
  activeFilterCount?: number;
  onResetFilters?: () => void;
  resultLabel?: string;
}

// Thanh tìm kiếm + bộ lọc dạng gọn cho mobile. Lướt xuống thì thu lại, lướt lên thì hiện.
export function MobileToolbar<T extends string>({
  search,
  onSearchChange,
  searchPlaceholder,
  chips,
  chipValue,
  onChipChange,
  chipsLabel = 'Lọc nhanh',
  filters,
  activeFilterCount = 0,
  onResetFilters,
  resultLabel,
}: MobileToolbarProps<T>) {
  const { toolbarHidden } = useMobileChrome();
  const [sheetOpen, setSheetOpen] = useState(false);

  return (
    <div className={`m-toolbar ${toolbarHidden ? 'is-hidden' : ''}`} aria-hidden={toolbarHidden || undefined}>
      <div className="m-toolbar-row">
        <label className="m-search">
          <Search aria-hidden="true" />
          <input
            type="search"
            value={search}
            placeholder={searchPlaceholder}
            aria-label={searchPlaceholder}
            onChange={(event) => onSearchChange(event.target.value)}
          />
        </label>
        {filters ? (
          <button
            type="button"
            className={`m-chip ${activeFilterCount ? 'is-active' : ''}`}
            onClick={() => setSheetOpen(true)}
            aria-label={activeFilterCount ? `Bộ lọc, đang bật ${activeFilterCount}` : 'Bộ lọc'}
          >
            <SlidersHorizontal aria-hidden="true" />
            {activeFilterCount ? activeFilterCount : 'Lọc'}
          </button>
        ) : null}
      </div>
      {chips?.length ? (
        <div className="m-chip-row" role="group" aria-label={chipsLabel}>
          {chips.map((chip) => (
            <button
              key={chip.value}
              type="button"
              className={`m-chip ${chip.value === chipValue ? 'is-active' : ''}`}
              aria-pressed={chip.value === chipValue}
              onClick={() => onChipChange?.(chip.value)}
            >
              {chip.label}
            </button>
          ))}
        </div>
      ) : null}
      {resultLabel ? <p className="m-result-label">{resultLabel}</p> : null}

      {filters ? (
        <BottomSheet
          open={sheetOpen}
          title="Bộ lọc"
          onClose={() => setSheetOpen(false)}
          footer={(
            <>
              {onResetFilters ? (
                <button type="button" className="m-btn m-btn--ghost" onClick={onResetFilters}>Đặt lại</button>
              ) : null}
              <button type="button" className="m-btn" onClick={() => setSheetOpen(false)}>Xong</button>
            </>
          )}
        >
          {filters}
        </BottomSheet>
      ) : null}
    </div>
  );
}

interface FilterGroupProps<T extends string> {
  label: string;
  options: ToolbarChip<T>[];
  value: T;
  onChange: (value: T) => void;
}

export function FilterGroup<T extends string>({ label, options, value, onChange }: FilterGroupProps<T>) {
  return (
    <div className="m-filter-group">
      <span className="m-filter-label">{label}</span>
      <div className="m-chip-wrap" role="group" aria-label={label}>
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            className={`m-chip ${option.value === value ? 'is-active' : ''}`}
            aria-pressed={option.value === value}
            onClick={() => onChange(option.value)}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
