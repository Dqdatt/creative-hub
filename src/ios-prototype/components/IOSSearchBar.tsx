import { Search, X } from 'lucide-react';

interface IOSSearchBarProps {
  value: string;
  onChange: (val: string) => void;
  placeholder?: string;
}

export function IOSSearchBar({ value, onChange, placeholder = 'Tìm kiếm video, nhân sự...' }: IOSSearchBarProps) {
  return (
    <div className="relative w-full my-2">
      <div className="relative flex items-center">
        <Search className="absolute left-3 w-4 h-4 text-[var(--muted)] pointer-events-none" />
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full pl-9 pr-8 py-2 bg-[var(--chip)] text-[var(--text)] text-xs font-medium rounded-xl focus:outline-none focus:ring-2 focus:ring-[var(--accent)]/40 transition-all border border-transparent focus:bg-[var(--surface)] placeholder:text-[var(--muted)]"
        />
        {value && (
          <button
            onClick={() => onChange('')}
            className="absolute right-2.5 w-4 h-4 rounded-full bg-[var(--muted)]/40 text-[var(--text)] flex items-center justify-center hover:opacity-80 transition-opacity"
            aria-label="Clear"
          >
            <X className="w-2.5 h-2.5" />
          </button>
        )}
      </div>
    </div>
  );
}
