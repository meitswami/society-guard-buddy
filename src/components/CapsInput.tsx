import { forwardRef, type ChangeEvent, type ComponentPropsWithoutRef } from 'react';
import { useStore } from '@/store/useStore';
import { normalizeEntryValue } from '@/lib/entryCaps';
import { cn } from '@/lib/utils';

type CapsFieldProps = {
  /** Set false to keep natural casing for this field (e.g. password). */
  caps?: boolean;
  field?: string;
};

export const CapsInput = forwardRef<
  HTMLInputElement,
  ComponentPropsWithoutRef<'input'> & CapsFieldProps
>(function CapsInput({ caps, field, className, onChange, type, ...props }, ref) {
  const entryCapsMode = useStore((s) => s.entryCapsMode);

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const next = normalizeEntryValue(e.target.value, {
      type: e.target.type || type,
      field,
      caps,
      datasetCaps: e.target.dataset.caps,
    });
    if (next !== e.target.value) {
      e.target.value = next;
    }
    onChange?.(e);
  };

  return (
    <input
      ref={ref}
      type={type}
      className={cn('input-field', entryCapsMode && caps !== false && 'uppercase', className)}
      onChange={handleChange}
      {...props}
    />
  );
});

export const CapsTextarea = forwardRef<
  HTMLTextAreaElement,
  ComponentPropsWithoutRef<'textarea'> & CapsFieldProps
>(function CapsTextarea({ caps, field, className, onChange, ...props }, ref) {
  const entryCapsMode = useStore((s) => s.entryCapsMode);

  const handleChange = (e: ChangeEvent<HTMLTextAreaElement>) => {
    const next = normalizeEntryValue(e.target.value, { field, caps, datasetCaps: e.target.dataset.caps });
    if (next !== e.target.value) {
      e.target.value = next;
    }
    onChange?.(e);
  };

  return (
    <textarea
      ref={ref}
      className={cn('input-field', entryCapsMode && caps !== false && 'uppercase', className)}
      onChange={handleChange}
      {...props}
    />
  );
});
