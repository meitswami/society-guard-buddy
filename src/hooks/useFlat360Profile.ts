import { useCallback, useEffect, useState } from 'react';
import type { Flat360FetchParams, Flat360Profile } from '@/lib/flat360Types';
import { fetchFlat360Profile } from '@/services/flat360/flat360Service';

export function useFlat360Profile(params: Flat360FetchParams | null) {
  const [profile, setProfile] = useState<Flat360Profile | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!params?.societyId || !params?.flatId) {
      setProfile(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await fetchFlat360Profile(params);
      setProfile(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load flat profile');
      setProfile(null);
    } finally {
      setLoading(false);
    }
  }, [
    params?.societyId,
    params?.flatId,
    params?.flatNumber,
    params?.monthsBack,
    params?.timelineLimit,
    params?.includeVisitors,
    params?.residentContext?.id,
    params?.residentContext?.name,
  ]);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { profile, loading, error, reload };
}
