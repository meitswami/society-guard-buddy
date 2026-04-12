import { useMemo, useState } from 'react';

export type FlatMultiSelectOption = {
  id: string;
  flat_number: string;
  /** Shown under the flat number (e.g. primary member or owner). */
  subtitle?: string;
};

type Props = {
  flats: FlatMultiSelectOption[];
  selected: string[];
  onChange: (flatNumbers: string[]) => void;
  label?: string;
  compact?: boolean;
  className?: string;
  emptyHint?: string;
};

export function FlatMultiSelect({
  flats,
  selected,
  onChange,
  label = 'Flats',
  compact = false,
  className = '',
  emptyHint = 'No flats match your search.',
}: Props) {
  const [q, setQ] = useState('');

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return flats;
    return flats.filter(
      f =>
        f.flat_number.toLowerCase().includes(s) ||
        (f.subtitle && f.subtitle.toLowerCase().includes(s))
    );
  }, [flats, q]);

  const toggle = (num: string) => {
    onChange(selected.includes(num) ? selected.filter(x => x !== num) : [...selected, num]);
  };

  const selectAllFiltered = () => {
    const nums = new Set(filtered.map(f => f.flat_number));
    const merged = new Set([...selected, ...nums]);
    onChange([...merged]);
  };

  const clearFiltered = () => {
    const nums = new Set(filtered.map(f => f.flat_number));
    onChange(selected.filter(x => !nums.has(x)));
  };

  const gridClass = compact ? 'grid grid-cols-3 sm:grid-cols-4 gap-1' : 'grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-1.5';
  const btnClass = compact
    ? 'text-xs px-1 py-1.5 rounded border min-h-[2.75rem]'
    : 'text-xs p-2 rounded-lg border min-h-[3.25rem]';

  return (
    <div className={className}>
      <div className="mb-1.5 flex flex-wrap items-center justify-between gap-2">
        <p className="text-xs font-medium text-muted-foreground">
          {label} ({selected.length} selected)
        </p>
        {filtered.length > 0 && (
          <div className="flex gap-1">
            <button
              type="button"
              onClick={selectAllFiltered}
              className="text-[10px] font-medium text-primary underline"
            >
              All visible
            </button>
            <span className="text-[10px] text-muted-foreground">·</span>
            <button
              type="button"
              onClick={clearFiltered}
              className="text-[10px] font-medium text-muted-foreground underline"
            >
              Clear visible
            </button>
          </div>
        )}
      </div>
      <input
        type="search"
        className={`input-field mb-2 ${compact ? 'text-sm py-1.5' : ''}`}
        placeholder="Search flat or resident…"
        value={q}
        onChange={e => setQ(e.target.value)}
        autoComplete="off"
      />
      <div className={`max-h-48 overflow-y-auto ${gridClass}`}>
        {filtered.length === 0 ? (
          <p className="col-span-full text-xs text-muted-foreground py-2">{emptyHint}</p>
        ) : (
          filtered.map(f => {
            const on = selected.includes(f.flat_number);
            return (
              <button
                key={f.id}
                type="button"
                onClick={() => toggle(f.flat_number)}
                title={f.subtitle ? `${f.flat_number} · ${f.subtitle}` : f.flat_number}
                className={`${btnClass} flex flex-col items-center justify-center gap-0.5 text-center transition-colors ${
                  on
                    ? 'bg-primary text-primary-foreground border-primary'
                    : 'bg-card border-border text-foreground hover:bg-muted/60'
                }`}
              >
                <span className="font-mono font-semibold leading-none tabular-nums">{f.flat_number}</span>
                {f.subtitle ? (
                  <span
                    className={`w-full text-[9px] leading-[1.15] font-normal line-clamp-2 break-words hyphens-auto ${
                      on ? 'text-primary-foreground/90' : 'text-muted-foreground'
                    }`}
                  >
                    {f.subtitle}
                  </span>
                ) : null}
              </button>
            );
          })
        )}
      </div>
    </div>
  );
}
