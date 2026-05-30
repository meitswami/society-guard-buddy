import { fmtIsoDateToDisplay } from '@/lib/dateFormat';

interface DateInputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type'> {
  /** Show dd-MM-yyyy formatted hint below the input */
  showHint?: boolean;
}

/**
 * Wrapper around <input type="date"> that shows the selected date
 * in dd-MM-yyyy format below the native input (which may render in
 * the browser's locale, e.g. mm/dd/yyyy on US-locale systems).
 */
export function DateInput({ showHint = true, value, className, ...props }: DateInputProps) {
  const displayValue = typeof value === 'string' && value ? fmtIsoDateToDisplay(value) : '';

  return (
    <div className="flex flex-col gap-0.5">
      <input type="date" className={className} value={value} {...props} />
      {showHint && displayValue && (
        <span className="text-[10px] text-muted-foreground">{displayValue}</span>
      )}
    </div>
  );
}
