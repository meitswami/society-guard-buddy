import type { ReactNode } from 'react';
import { Info } from 'lucide-react';
import { HoverInfoTip } from '@/components/HoverInfoTip';
import { cn } from '@/lib/utils';

export type DescriptiveStatCardProps = {
  title: string;
  value: ReactNode;
  caption?: string;
  description: string;
  howCalculated?: string;
  icon?: ReactNode;
  onNavigate?: () => void;
  navigateLabel?: string;
  className?: string;
  valueClassName?: string;
  variant?: 'card' | 'stat';
  contentAlign?: 'start' | 'center';
  children?: ReactNode;
};

export function DescriptiveStatCard({
  title,
  value,
  caption,
  description,
  howCalculated,
  icon,
  onNavigate,
  className,
  valueClassName,
  variant = 'card',
  contentAlign = 'start',
  children,
}: DescriptiveStatCardProps) {
  const shell =
    variant === 'stat'
      ? 'stat-card flex flex-col gap-1 text-left w-full'
      : 'card-section p-4 text-left w-full';

  const valueNode = onNavigate ? (
    <button
      type="button"
      onClick={onNavigate}
      className={cn(
        'text-left hover:underline underline-offset-2',
        variant === 'stat' ? cn('text-lg font-bold font-mono block', valueClassName) : cn('text-2xl font-bold tabular-nums', valueClassName),
      )}
    >
      {value}
    </button>
  ) : variant === 'stat' ? (
    <span className={cn('text-lg font-bold font-mono block', valueClassName)}>{value}</span>
  ) : (
    <p className={cn('text-2xl font-bold tabular-nums', valueClassName)}>{value}</p>
  );

  return (
    <HoverInfoTip title={title} description={description} howCalculated={howCalculated} className={cn('w-full', shell, contentAlign === 'center' && 'items-center text-center', className)}>
      {icon ? <div className={variant === 'stat' ? 'mb-0' : 'mb-2'}>{icon}</div> : null}
      <div
        className={cn(
          'flex gap-2 w-full',
          contentAlign === 'center' ? 'flex-col items-center' : 'items-start justify-between',
        )}
      >
        <div className={cn('min-w-0', contentAlign === 'center' ? 'flex flex-col items-center' : 'flex-1')}>
          {variant === 'stat' ? (
            <>
              <span className="text-[10px] text-muted-foreground uppercase">{caption ?? title}</span>
              {valueNode}
            </>
          ) : (
            <>
              {valueNode}
              <p className="text-xs text-muted-foreground">{caption ?? title}</p>
            </>
          )}
          {children}
        </div>
        <Info className="w-3.5 h-3.5 text-muted-foreground shrink-0 mt-0.5 opacity-60" aria-hidden />
      </div>
    </HoverInfoTip>
  );
}

/** Calculated value with hover insight — no click dialog. */
export function DescriptiveValueButton({
  title,
  value,
  description,
  howCalculated,
  className,
  valueClassName,
}: {
  title: string;
  value: ReactNode;
  description: string;
  howCalculated?: string;
  className?: string;
  valueClassName?: string;
}) {
  return (
    <HoverInfoTip title={title} description={description} howCalculated={howCalculated} className={cn('inline-flex', className)}>
      <span className={cn('inline-flex items-center gap-1 rounded-md px-1.5 py-0.5', className)}>
        <span className={cn('font-bold tabular-nums', valueClassName)}>{value}</span>
        <Info className="w-3 h-3 text-muted-foreground shrink-0 opacity-60" aria-hidden />
      </span>
    </HoverInfoTip>
  );
}

/** Inline summary line — hover for description. */
export function DescriptiveStatSummary({
  label,
  description,
  howCalculated,
  className,
}: {
  label: ReactNode;
  description: string;
  howCalculated?: string;
  className?: string;
}) {
  return (
    <HoverInfoTip description={description} howCalculated={howCalculated} className={cn('text-[10px] text-muted-foreground mb-2 w-full rounded-lg px-2 py-1.5', className)}>
      <span className="inline-flex items-center gap-1.5">
        <Info className="w-3 h-3 shrink-0 opacity-60" />
        {label}
      </span>
    </HoverInfoTip>
  );
}

/** Table cell or inline sum with hover insight. */
export function TableSumInsight({
  title,
  value,
  description,
  howCalculated,
  valueClassName,
  className,
  cellClassName,
  as = 'td',
}: {
  title: string;
  value: ReactNode;
  description: string;
  howCalculated?: string;
  valueClassName?: string;
  className?: string;
  cellClassName?: string;
  as?: 'td' | 'span';
}) {
  const button = (
    <DescriptiveValueButton
      title={title}
      value={value}
      description={description}
      howCalculated={howCalculated}
      className={cn('justify-end w-full max-w-full', className)}
      valueClassName={valueClassName}
    />
  );
  if (as === 'span') return button;
  return <td className={cn('text-right', cellClassName)}>{button}</td>;
}
