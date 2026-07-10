import { supabase } from '@/integrations/supabase/client';

/** Haversine distance in meters between two WGS84 points. */
export function getDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export type GeofencePolicy = 'strict' | 'permissive';

export type GeofenceCheckResult =
  | { ok: true }
  | { ok: false; reason: 'no_geolocation' | 'position_unavailable' | 'outside'; distanceM?: number };

type GeofenceRow = { latitude: number; longitude: number; radius_meters: number };

async function fetchActiveGeofence(societyId: string): Promise<GeofenceRow | null> {
  const { data } = await supabase
    .from('geofence_settings')
    .select('latitude, longitude, radius_meters')
    .eq('society_id', societyId)
    .order('created_at', { ascending: false })
    .limit(1);
  return data?.[0] ?? null;
}

function getCurrentPosition(): Promise<GeolocationPosition> {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('no_geolocation'));
      return;
    }
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: true,
      timeout: 10000,
    });
  });
}

/**
 * Check whether the device is within the society geofence.
 * - strict: missing geolocation or position errors block login (guard LoginPage).
 * - permissive: missing geolocation or position errors allow login (UnifiedLoginPage).
 */
export async function checkSocietyGeofence(
  societyId: string,
  policy: GeofencePolicy,
): Promise<GeofenceCheckResult> {
  if (!societyId) return { ok: true };
  const geo = await fetchActiveGeofence(societyId);
  if (!geo) return { ok: true };

  try {
    const pos = await getCurrentPosition();
    const distanceM = getDistanceMeters(
      pos.coords.latitude,
      pos.coords.longitude,
      geo.latitude,
      geo.longitude,
    );
    if (distanceM <= geo.radius_meters) return { ok: true };
    return { ok: false, reason: 'outside', distanceM };
  } catch {
    if (policy === 'strict') {
      return { ok: false, reason: navigator.geolocation ? 'position_unavailable' : 'no_geolocation' };
    }
    return { ok: true };
  }
}
