import { fmtIsoDateToDisplay } from '@/lib/dateFormat';

interface DateInputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type'> {
  /** Show dd/MM/yyyy formatted hint below the input (legacy prop, kept for compat) */
  showHint?: boolean;
}

/**
 * Custom date input that always displays the selected date in dd/MM/yyyy format
 * regardless of browser locale. The native date input is rendered with opacity-0
 * on top so clicking opens the calendar, while the formatted value is shown beneath.
 */
export function DateInput({ showHint = true, value, className, ...props }: DateInputProps) {
  const displayValue = typeof value === 'string' && value ? fmtIsoDateToDisplay(value) : '';

  return (
    <div className="relative">
      {/* Visible formatted display */}
      <div
        className={`${className || ''} pointer-events-none`}
        aria-hidden="true"
      >
        {displayValue || <span className="text-muted-foreground">dd/mm/yyyy</span>}
      </div>
      {/* Native date input overlaid with full opacity-0 so it captures clicks/taps */}
      <input
        type="date"
        className={`${className || ''} absolute inset-0 opacity-0 cursor-pointer`}
        value={value}
        {...props}
      />
    </div>
  );
}
