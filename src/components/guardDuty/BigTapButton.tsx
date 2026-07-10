import { cn } from '@/lib/utils';

type Props = {
  label: string;
  subLabel?: string;
  icon?: string;
  selected: boolean;
  variant?: 'success' | 'warning' | 'danger' | 'muted' | 'default';
  onClick: () => void;
  disabled?: boolean;
};

const variantClass: Record<NonNullable<Props['variant']>, string> = {
  success: 'border-success bg-success/15 text-[hsl(var(--success))]',
  warning: 'border-warning bg-warning/15 text-[hsl(var(--warning))]',
  danger: 'border-destructive bg-destructive/15 text-destructive',
  muted: 'border-border bg-muted/40 text-muted-foreground',
  default: 'border-primary bg-primary/15 text-primary',
};

export function BigTapButton({
  label,
  subLabel,
  icon,
  selected,
  variant = 'default',
  onClick,
  disabled,
}: Props) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        'flex flex-col items-center justify-center gap-1 rounded-xl border-2 p-3 min-h-[4.5rem] active:scale-[0.97] transition-all text-center',
        selected ? variantClass[variant] : 'border-border bg-card text-foreground',
        disabled && 'opacity-50 pointer-events-none',
      )}
    >
      {icon && <span className="text-2xl leading-none">{icon}</span>}
      <span className="text-sm font-semibold leading-tight">{label}</span>
      {subLabel && <span className="text-[10px] text-muted-foreground leading-tight">{subLabel}</span>}
    </button>
  );
}
