import type { ReactNode } from 'react';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

type Props = {
  title?: string;
  description: string;
  howCalculated?: string;
  children: ReactNode;
  className?: string;
  side?: 'top' | 'right' | 'bottom' | 'left';
};

/** Explanatory copy shown on hover — keeps labels compact until the cursor rests on them. */
export function HoverInfoTip({ title, description, howCalculated, children, className, side = 'top' }: Props) {
  return (
    <Tooltip delayDuration={200}>
      <TooltipTrigger asChild>
        <span className={cn('inline-flex items-center gap-1 cursor-help', className)}>{children}</span>
      </TooltipTrigger>
      <TooltipContent side={side} className="max-w-xs p-3 text-xs leading-relaxed space-y-1.5">
        {title ? <p className="font-semibold text-foreground">{title}</p> : null}
        <p>{description}</p>
        {howCalculated ? (
          <p className="text-[10px] text-muted-foreground border-t border-border/60 pt-1.5">{howCalculated}</p>
        ) : null}
      </TooltipContent>
    </Tooltip>
  );
}
