import { useEffect, useRef, useState } from 'react';
import { Calendar } from 'lucide-react';
import { fmtIsoDateToDisplay, parseDisplayDateToIso } from '@/lib/dateFormat';

interface DateInputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type' | 'value' | 'onChange'> {
  /** Show dd/MM/yyyy formatted hint below the input (legacy prop, kept for compat) */
  showHint?: boolean;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
}

/**
 * Date field with dd/MM/yyyy manual typing and an optional native calendar picker.
 * Emits `yyyy-MM-dd` via onChange (same as `<input type="date">`).
 */
export function DateInput({
  showHint = true,
  value,
  className,
  onChange,
  disabled,
  ...props
}: DateInputProps) {
  const calendarRef = useRef<HTMLInputElement>(null);
  const [text, setText] = useState('');
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (!focused) {
      setText(typeof value === 'string' && value ? fmtIsoDateToDisplay(value) : '');
    }
  }, [value, focused]);

  const emitChange = (iso: string) => {
    if (!onChange) return;
    onChange({ target: { value: iso }, currentTarget: { value: iso } } as React.ChangeEvent<HTMLInputElement>);
  };

  const handleTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const next = e.target.value;
    setText(next);
    const iso = parseDisplayDateToIso(next);
    if (iso) emitChange(iso);
  };

  const handleBlur = () => {
    setFocused(false);
    const iso = parseDisplayDateToIso(text);
    if (iso) {
      setText(fmtIsoDateToDisplay(iso));
      if (String(value ?? '') !== iso) emitChange(iso);
      return;
    }
    setText(typeof value === 'string' && value ? fmtIsoDateToDisplay(value) : '');
  };

  const handleCalendarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const iso = e.target.value;
    setText(iso ? fmtIsoDateToDisplay(iso) : '');
    if (iso) emitChange(iso);
  };

  const openCalendar = () => {
    const el = calendarRef.current;
    if (!el || disabled) return;
    if (typeof el.showPicker === 'function') el.showPicker();
    else el.click();
  };

  return (
    <div>
      <div className="relative flex items-center">
        <input
          type="text"
          inputMode="numeric"
          placeholder="dd/mm/yyyy"
          className={`${className || ''} pr-9`}
          value={text}
          onChange={handleTextChange}
          onFocus={() => setFocused(true)}
          onBlur={handleBlur}
          disabled={disabled}
          autoComplete="off"
          {...props}
        />
        <button
          type="button"
          className="absolute right-2 p-1 text-muted-foreground hover:text-foreground disabled:opacity-40"
          onClick={openCalendar}
          disabled={disabled}
          tabIndex={-1}
          aria-label="Open calendar"
        >
          <Calendar className="w-4 h-4" />
        </button>
        <input
          ref={calendarRef}
          type="date"
          className="sr-only"
          tabIndex={-1}
          aria-hidden
          value={typeof value === 'string' ? value : ''}
          onChange={handleCalendarChange}
          disabled={disabled}
        />
      </div>
      {showHint && !text && (
        <p className="text-[10px] text-muted-foreground mt-0.5">Type dd/mm/yyyy or use the calendar</p>
      )}
    </div>
  );
}
