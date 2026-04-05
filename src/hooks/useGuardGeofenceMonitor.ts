import { useEffect, useRef } from 'react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { logAuditEvent } from '@/lib/auditLogger';
import { getDistanceMeters } from '@/lib/geofenceUtils';
import type { Guard } from '@/types';
import { useLanguage } from '@/i18n/LanguageContext';

/**
 * While a guard shift is active, watches device location against the latest geofence.
 * Alerts the guard and writes an audit log when they leave the zone or location is lost/disabled,
 * after we have seen at least one fix inside the fence (avoids noisy GPS on startup).
 */
export function useGuardGeofenceMonitor(currentGuard: Guard | null) {
  const { t } = useLanguage();
  const tRef = useRef(t);
  tRef.current = t;

  useEffect(() => {
    if (!currentGuard || typeof navigator === 'undefined' || !navigator.geolocation) return;

    const session = { cancelled: false, watchId: undefined as number | undefined };

    const breachActiveRef = { current: false };
    const armedRef = { current: false };

    const notifyBreach = async (
      reason: 'outside_radius' | 'location_disabled',
      extra?: Record<string, unknown>
    ) => {
      if (breachActiveRef.current) return;
      breachActiveRef.current = true;
      const message =
        reason === 'outside_radius'
          ? tRef.current('guard.geofenceLeftZone')
          : tRef.current('guard.geofenceLocationOff');
      toast.error(message, { duration: 10_000 });
      await logAuditEvent({
        event_type: 'geofence_violation',
        user_type: 'guard',
        user_id: currentGuard.id,
        user_name: currentGuard.name,
        details: { reason, ...extra },
        severity: 'warning',
      });
    };

    (async () => {
      const { data: geoData } = await supabase
        .from('geofence_settings')
        .select('latitude, longitude, radius_meters')
        .order('created_at', { ascending: false })
        .limit(1);

      if (session.cancelled || !geoData?.length) return;

      const geo = geoData[0];
      const centerLat = geo.latitude;
      const centerLon = geo.longitude;
      const radiusM = geo.radius_meters;

      if (session.cancelled) return;

      session.watchId = navigator.geolocation.watchPosition(
        (pos) => {
          if (session.cancelled) return;
          const dist = getDistanceMeters(
            pos.coords.latitude,
            pos.coords.longitude,
            centerLat,
            centerLon
          );
          const inside = dist <= radiusM;

          if (inside) {
            armedRef.current = true;
            breachActiveRef.current = false;
            return;
          }

          if (armedRef.current) {
            void notifyBreach('outside_radius', { distance_meters: Math.round(dist) });
          }
        },
        (err) => {
          if (session.cancelled || !armedRef.current) return;
          void notifyBreach('location_disabled', {
            error_code: err.code,
            message: err.message,
          });
        },
        { enableHighAccuracy: true, maximumAge: 15_000, timeout: 25_000 }
      );
    })();

    return () => {
      session.cancelled = true;
      if (session.watchId !== undefined) {
        navigator.geolocation.clearWatch(session.watchId);
        session.watchId = undefined;
      }
    };
  }, [currentGuard?.id, currentGuard?.name]);
}
