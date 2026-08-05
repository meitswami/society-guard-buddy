import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { cn } from '@/lib/utils';

type Size = 'xs' | 'sm' | 'md' | 'lg';

const SIZE_CLASS: Record<Size, string> = {
  xs: 'h-7 w-7 text-[10px]',
  sm: 'h-9 w-9 text-xs',
  md: 'h-10 w-10 text-sm',
  lg: 'h-14 w-14 text-base',
};

/** Circular face photo with initial fallback — use wherever a person name is shown. */
export function PersonAvatar({
  name,
  photo,
  size = 'md',
  className,
}: {
  name: string;
  photo?: string | null;
  size?: Size;
  className?: string;
}) {
  const initial = (name || '?').trim().charAt(0).toUpperCase() || '?';
  const src = typeof photo === 'string' && photo.trim() ? photo.trim() : undefined;
  return (
    <Avatar className={cn(SIZE_CLASS[size], 'border border-border/70 shrink-0', className)}>
      {src ? <AvatarImage src={src} alt={name} className="object-cover" /> : null}
      <AvatarFallback className="bg-primary/10 text-primary font-semibold">{initial}</AvatarFallback>
    </Avatar>
  );
}
