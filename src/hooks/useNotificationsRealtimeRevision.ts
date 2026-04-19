import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';

/**
 * Subscribes to new `notifications` rows while the dashboard is mounted so the
 * Alerts / Notify tab can refresh even when that tab is not open (step 4).
 */
export function useNotificationsRealtimeRevision(enabled: boolean, channelSuffix: string) {
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    if (!enabled || !channelSuffix) return;

    const channel = supabase
      .channel(`notifications-dashboard-${channelSuffix}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications' },
        () => setRevision((r) => r + 1),
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [enabled, channelSuffix]);

  return revision;
}
