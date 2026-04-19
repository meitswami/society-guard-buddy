import { useEffect, useRef, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';

type RealtimeOptions = {
  /** Called on every INSERT into `notifications` (e.g. resident toast on any tab). */
  onNotificationInsert?: (row: Record<string, unknown>) => void;
};

/**
 * Subscribes to new `notifications` rows while the dashboard is mounted so the
 * Alerts / Notify tab can refresh even when that tab is not open; optional callback
 * runs on every insert for instant in-app alerts.
 */
export function useNotificationsRealtimeRevision(
  enabled: boolean,
  channelSuffix: string,
  options?: RealtimeOptions,
) {
  const [revision, setRevision] = useState(0);
  const onInsertRef = useRef(options?.onNotificationInsert);
  onInsertRef.current = options?.onNotificationInsert;

  useEffect(() => {
    if (!enabled || !channelSuffix) return;

    const channel = supabase
      .channel(`notifications-dashboard-${channelSuffix}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications' },
        (payload) => {
          const row = (payload.new ?? {}) as Record<string, unknown>;
          setRevision((r) => r + 1);
          onInsertRef.current?.(row);
        },
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [enabled, channelSuffix]);

  return revision;
}
