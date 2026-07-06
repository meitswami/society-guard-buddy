import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { todayRecordingDate } from '@/lib/financeDates';

type Props = {
  className?: string;
};

/**
 * Shows today’s recording date (when the admin is entering data).
 * Not used in period or month financial reports — those use billing/transaction dates.
 */
export function RecordingDateBanner({ className = '' }: Props) {
  const today = todayRecordingDate();
  return (
    <div
      className={`rounded-lg border border-primary/25 bg-primary/5 px-3 py-2 flex flex-wrap items-center justify-between gap-2 ${className}`}
    >
      <div>
        <p className="text-[10px] font-medium uppercase text-muted-foreground tracking-wide">Recording date</p>
        <p className="text-sm font-semibold tabular-nums">{fmtIsoDateToDisplay(today)}</p>
      </div>
      <p className="text-[10px] text-muted-foreground max-w-md leading-snug">
        System entry date when you save (defaults to today). For receipts and payments, set the billing /
        transaction date in the form — that date drives period reports.
      </p>
    </div>
  );
}
