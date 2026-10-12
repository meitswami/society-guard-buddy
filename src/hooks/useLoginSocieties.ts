import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchActiveSocietiesWithRetry, type LoginSocietyRow } from '@/lib/societiesLogin';

/**
 * Society list for the login screens. Retries on failure, and reloads when the
 * device comes back online or the app returns to the foreground with an empty list.
 */
export function useLoginSocieties() {
  const [societies, setSocieties] = useState<LoginSocietyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const inFlight = useRef(false);
  const mounted = useRef(true);
  const countRef = useRef(0);

  const reload = useCallback(async () => {
    if (inFlight.current) return;
    inFlight.current = true;
    setLoading(true);
    setError(null);
    try {
      const rows = await fetchActiveSocietiesWithRetry();
      if (!mounted.current) return;
      countRef.current = rows.length;
      setSocieties(rows);
    } catch (e) {
      if (!mounted.current) return;
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      inFlight.current = false;
      if (mounted.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    void reload();
    const retryIfEmpty = () => {
      if (countRef.current === 0) void reload();
    };
    const onVisible = () => {
      if (document.visibilityState === 'visible') retryIfEmpty();
    };
    window.addEventListener('online', retryIfEmpty);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      mounted.current = false;
      window.removeEventListener('online', retryIfEmpty);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [reload]);

  return { societies, loading, error, reload };
}
