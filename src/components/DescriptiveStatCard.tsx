import { useState, type ReactNode } from 'react';
import { Info } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
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
  navigateLabel = 'Open related screen',
  className,
  valueClassName,
  variant = 'card',
  contentAlign = 'start',
  children,
}: DescriptiveStatCardProps) {
  const [open, setOpen] = useState(false);

  const shell =
    variant === 'stat'
      ? 'stat-card flex flex-col gap-1 text-left cursor-pointer hover:ring-2 hover:ring-primary/25 transition-all w-full'
      : 'card-section p-4 text-left cursor-pointer hover:ring-2 hover:ring-primary/30 transition-all w-full';

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(shell, contentAlign === 'center' && 'items-center text-center', className)}
        aria-label={`${title}: view description`}
      >
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
                <span className={cn('text-lg font-bold font-mono block', valueClassName)}>{value}</span>
              </>
            ) : (
              <>
                <p className={cn('text-2xl font-bold tabular-nums', valueClassName)}>{value}</p>
                <p className="text-xs text-muted-foreground">{caption ?? title}</p>
              </>
            )}
            {children}
          </div>
          <Info className="w-3.5 h-3.5 text-muted-foreground shrink-0 mt-0.5" aria-hidden />
        </div>
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{title}</DialogTitle>
            <DialogDescription asChild>
              <div className="space-y-3 text-sm text-muted-foreground pt-1">
                <p className="text-foreground font-semibold text-base tabular-nums">{value}</p>
                <p>{description}</p>
                {howCalculated ? (
                  <div className="rounded-lg border border-border bg-muted/30 p-3 space-y-1">
                    <p className="text-[10px] font-medium uppercase text-foreground">How this is calculated</p>
                    <p className="text-xs leading-relaxed">{howCalculated}</p>
                  </div>
                ) : null}
              </div>
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="flex-col sm:flex-row gap-2">
            {onNavigate ? (
              <button
                type="button"
                className="btn-primary w-full sm:w-auto"
                onClick={() => {
                  setOpen(false);
                  onNavigate();
                }}
              >
                {navigateLabel}
              </button>
            ) : null}
            <button type="button" className="btn-secondary w-full sm:w-auto" onClick={() => setOpen(false)}>
              Close
            </button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Inline summary line (counts · totals) — tap opens the same descriptive dialog. */
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
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          'text-[10px] text-muted-foreground mb-2 text-left w-full rounded-lg border border-transparent hover:border-border hover:bg-muted/20 px-2 py-1.5 transition-colors',
          className,
        )}
      >
        <span className="inline-flex items-center gap-1.5">
          <Info className="w-3 h-3 shrink-0" />
          {label}
        </span>
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Summary</DialogTitle>
            <DialogDescription asChild>
              <div className="space-y-2 text-sm text-muted-foreground pt-1">
                <div className="text-foreground text-xs">{label}</div>
                <p>{description}</p>
                {howCalculated ? (
                  <p className="text-xs rounded-lg border border-border bg-muted/30 p-3">{howCalculated}</p>
                ) : null}
              </div>
            </DialogDescription>
          </DialogHeader>
        </DialogContent>
      </Dialog>
    </>
  );
}
