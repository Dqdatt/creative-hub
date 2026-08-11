interface IOSSegmentedControlOption<T extends string> {
  id: T;
  label: string;
  count?: number;
}

interface IOSSegmentedControlProps<T extends string> {
  options: IOSSegmentedControlOption<T>[];
  selected: T;
  onChange: (val: T) => void;
}

export function IOSSegmentedControl<T extends string>({ options, selected, onChange }: IOSSegmentedControlProps<T>) {
  return (
    <div className="flex items-center p-1 bg-[var(--chip)] rounded-xl border border-[var(--border)] w-full gap-1 my-1.5 overflow-x-auto no-scrollbar">
      {options.map((opt) => {
        const isActive = selected === opt.id;
        return (
          <button
            key={opt.id}
            onClick={() => onChange(opt.id)}
            className={`flex-1 py-1.5 px-3 rounded-lg text-xs font-semibold whitespace-nowrap transition-all flex items-center justify-center gap-1.5 ${
              isActive
                ? 'bg-[var(--surface)] text-[var(--accent)] shadow-xs border border-[var(--border-strong)]'
                : 'text-[var(--text-2)] hover:text-[var(--text)]'
            }`}
          >
            <span>{opt.label}</span>
            {typeof opt.count === 'number' && (
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${
                  isActive ? 'bg-[var(--accent)]/15 text-[var(--accent)]' : 'bg-[var(--border)] text-[var(--text-2)]'
                }`}
              >
                {opt.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
