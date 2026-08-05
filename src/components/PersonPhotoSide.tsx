import type { ReactNode } from 'react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { cn } from '@/lib/utils';

type Size = 'sm' | 'md' | 'lg';

const SIZE_CLASS: Record<Size, string> = {
  sm: 'h-9 w-9',
  md: 'h-11 w-11',
  lg: 'h-14 w-14',
};

/** Circular photo seated to the side of a name/detail block (nominee / elected rows). */
export function PersonPhotoSide({
  name,
  photo,
  size = 'md',
  children,
  className,
}: {
  name: string;
  photo?: string | null;
  size?: Size;
  children: ReactNode;
  className?: string;
}) {
  const initial = (name || '?').trim().charAt(0).toUpperCase() || '?';
  return (
    <div className={cn('flex items-start gap-2.5 min-w-0', className)}>
      <Avatar className={cn(SIZE_CLASS[size], 'border border-border/70 shrink-0')}>
        {photo ? <AvatarImage src={photo} alt={name} className="object-cover" /> : null}
        <AvatarFallback className="bg-primary/10 text-primary text-sm font-semibold">{initial}</AvatarFallback>
      </Avatar>
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}
