import type { ReactNode } from 'react';
import { PersonAvatar } from '@/components/PersonAvatar';
import { cn } from '@/lib/utils';

type Size = 'sm' | 'md' | 'lg';

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
  return (
    <div className={cn('flex items-start gap-2.5 min-w-0', className)}>
      <PersonAvatar name={name} photo={photo} size={size} />
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}
