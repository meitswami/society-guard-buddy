import { useEffect } from 'react';
import { useStore } from '@/store/useStore';

/** Keeps `data-entry-caps` on document.body in sync with the setting (for global CSS). */
export function EntryCapsBodySync() {
  const entryCapsMode = useStore((s) => s.entryCapsMode);

  useEffect(() => {
    document.body.dataset.entryCaps = entryCapsMode ? 'on' : 'off';
  }, [entryCapsMode]);

  return null;
}
