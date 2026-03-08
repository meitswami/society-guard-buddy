import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { MapPin, Navigation, Save, Trash2 } from 'lucide-react';
import { showSuccess } from '@/lib/swal';

interface Props {
  adminName: string;
}

const GeofenceSetup = ({ adminName }: Props) => {
  const { t } = useLanguage();
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [radius, setRadius] = useState(500);
  const [loading, setLoading] = useState(false);
  const [capturing, setCapturing] = useState(false);
  const [existing, setExisting] = useState<{ id: string; latitude: number; longitude: number; radius_meters: number } | null>(null);

  useEffect(() => {
    loadExisting();
  }, []);

  const loadExisting = async () => {
    const { data } = await supabase.from('geofence_settings').select('*').order('created_at', { ascending: false }).limit(1);
    if (data && data.length > 0) {
      const g = data[0];
      setExisting(g);
      setLatitude(g.latitude);
      setLongitude(g.longitude);
      setRadius(g.radius_meters);
    }
  };

  const captureLocation = () => {
    if (!navigator.geolocation) {
      alert('Geolocation not supported');
      return;
    }
    setCapturing(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLatitude(pos.coords.latitude);
        setLongitude(pos.coords.longitude);
        setCapturing(false);
      },
      (err) => {
        alert(`${t('admin.locationError')}: ${err.message}`);
        setCapturing(false);
      },
      { enableHighAccuracy: true, timeout: 15000 }
    );
  };

  const saveGeofence = async () => {
    if (latitude === null || longitude === null) return;
    setLoading(true);
    if (existing) {
      await supabase.from('geofence_settings').update({
        latitude, longitude, radius_meters: radius, set_by: adminName, updated_at: new Date().toISOString(),
      }).eq('id', existing.id);
    } else {
      await supabase.from('geofence_settings').insert({
        latitude, longitude, radius_meters: radius, set_by: adminName,
      });
    }
    setLoading(false);
    await loadExisting();
    showSuccess(t('swal.success'), t('admin.geofenceSaved'));
  };

  const clearGeofence = async () => {
    if (existing) {
      await supabase.from('geofence_settings').delete().eq('id', existing.id);
      setExisting(null);
      setLatitude(null);
      setLongitude(null);
      setRadius(500);
    }
  };

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <MapPin className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">{t('admin.geofence')}</h1>
          <p className="text-xs text-muted-foreground">{t('admin.geofenceSubtitle')}</p>
        </div>
      </div>

      <div className="card-section mb-4 p-4">
        <h2 className="text-sm font-semibold mb-3">{t('admin.currentLocation')}</h2>
        {existing ? (
          <div className="space-y-2">
            <p className="text-xs text-muted-foreground">📍 Lat: {existing.latitude.toFixed(6)}, Lng: {existing.longitude.toFixed(6)}</p>
            <p className="text-xs text-muted-foreground">📐 {t('admin.radius')}: {existing.radius_meters}m</p>
            <div className="w-full h-2 bg-green-500/20 rounded-full">
              <div className="h-2 bg-green-500 rounded-full w-full" />
            </div>
            <p className="text-xs text-green-600 font-medium">✅ {t('admin.geofenceActive')}</p>
          </div>
        ) : (
          <p className="text-xs text-muted-foreground">⚠️ {t('admin.noGeofence')}</p>
        )}
      </div>

      <div className="card-section p-4 space-y-4">
        <button onClick={captureLocation} disabled={capturing}
          className="btn-primary w-full flex items-center justify-center gap-2">
          <Navigation className="w-4 h-4" />
          {capturing ? t('admin.capturing') : t('admin.captureLocation')}
        </button>

        {latitude !== null && longitude !== null && (
          <>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-muted-foreground block mb-1">Latitude</label>
                <input className="input-field text-sm" type="number" step="any" value={latitude}
                  onChange={e => setLatitude(parseFloat(e.target.value))} />
              </div>
              <div>
                <label className="text-xs text-muted-foreground block mb-1">Longitude</label>
                <input className="input-field text-sm" type="number" step="any" value={longitude}
                  onChange={e => setLongitude(parseFloat(e.target.value))} />
              </div>
            </div>

            <div>
              <label className="text-xs text-muted-foreground block mb-1">{t('admin.radius')} ({radius}m)</label>
              <input type="range" min={50} max={2000} step={50} value={radius}
                onChange={e => setRadius(parseInt(e.target.value))}
                className="w-full accent-primary" />
              <div className="flex justify-between text-[10px] text-muted-foreground">
                <span>50m</span><span>2000m</span>
              </div>
            </div>

            <div className="flex gap-2">
              <button onClick={saveGeofence} disabled={loading}
                className="btn-primary flex-1 flex items-center justify-center gap-2">
                <Save className="w-4 h-4" />
                {loading ? '...' : t('common.save')}
              </button>
              {existing && (
                <button onClick={clearGeofence}
                  className="p-3 rounded-xl bg-destructive/10 text-destructive">
                  <Trash2 className="w-4 h-4" />
                </button>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default GeofenceSetup;
