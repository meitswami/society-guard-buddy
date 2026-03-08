import { useState, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { Shield, Eye, EyeOff, Fingerprint } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';

interface Props {
  onSwitchToResident?: () => void;
}

function getDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const LoginPage = ({ onSwitchToResident }: Props) => {
  const { t } = useLanguage();
  const [guardId, setGuardId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const login = useStore(s => s.login);
  const [loading, setLoading] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => {
    isAvailable().then(setBioAvailable);
  }, []);

  const checkGeofence = (): Promise<boolean> => {
    return new Promise(async (resolve) => {
      const { data: geoData } = await supabase.from('geofence_settings').select('*').order('created_at', { ascending: false }).limit(1);
      if (!geoData || geoData.length === 0) { resolve(true); return; }
      const geo = geoData[0];
      if (!navigator.geolocation) { setError(t('admin.geofenceBlocked')); resolve(false); return; }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const dist = getDistanceMeters(pos.coords.latitude, pos.coords.longitude, geo.latitude, geo.longitude);
          if (dist <= geo.radius_meters) resolve(true);
          else { setError(`${t('admin.geofenceBlocked')} (${Math.round(dist)}m away)`); resolve(false); }
        },
        () => { setError(t('admin.geofenceBlocked')); resolve(false); },
        { enableHighAccuracy: true, timeout: 10000 }
      );
    });
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!guardId || !password) { setError(t('login.enterBoth')); return; }
    setLoading(true);
    setError(t('admin.gettingLocation'));
    const withinFence = await checkGeofence();
    if (!withinFence) { setLoading(false); return; }
    setError('');
    const success = await login(guardId.toUpperCase(), password);
    setLoading(false);
    if (success) {
      auditLoginSuccess('guard', guardId.toUpperCase(), guardId.toUpperCase());
    } else {
      auditLoginFailed('guard', guardId.toUpperCase());
      setError(t('login.invalidCredentials'));
    }
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('guard');
    if (!result) { setError(t('biometric.notRegistered')); return; }
    // Look up guard by UUID
    const { data } = await supabase.from('guards').select('*').eq('id', result.userId).single();
    if (!data) { setError(t('login.invalidCredentials')); return; }
    setLoading(true);
    setError(t('admin.gettingLocation'));
    const withinFence = await checkGeofence();
    if (!withinFence) { setLoading(false); return; }
    setError('');
    const success = await login(data.guard_id, data.password);
    setLoading(false);
    if (success) {
      auditBiometricLogin('guard', data.id, data.name);
    } else {
      auditLoginFailed('guard', data.guard_id, 'biometric_lookup_failed');
      setError(t('login.invalidCredentials'));
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background relative">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-10">
          <div className="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
            <Shield className="w-10 h-10 text-primary" />
          </div>
          <h1 className="page-title text-2xl">{t('app.name')}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t('login.guardLogin')}</p>
        </div>

        {bioAvailable && (
          <button onClick={handleBiometricLogin} disabled={bioLoading}
            className="w-full mb-4 py-4 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-2 hover:bg-primary/10 transition-colors">
            <Fingerprint className="w-8 h-8 text-primary" />
            <span className="text-sm font-medium text-primary">{t('biometric.loginButton')}</span>
          </button>
        )}

        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('login.guardId')}</label>
            <input className="input-field font-mono uppercase" placeholder={t('login.guardIdPlaceholder')}
              value={guardId} onChange={e => setGuardId(e.target.value)} />
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('login.password')}</label>
            <div className="relative">
              <input className="input-field pr-10" type={showPassword ? 'text' : 'password'}
                placeholder={t('login.passwordPlaceholder')} value={password} onChange={e => setPassword(e.target.value)} />
              <button type="button" className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                onClick={() => setShowPassword(!showPassword)}>
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary mt-2" disabled={loading}>
            {loading ? t('login.loggingIn') : t('login.startShift')}
          </button>
          {onSwitchToResident && (
            <button type="button" className="text-xs text-muted-foreground text-center mt-2 underline" onClick={onSwitchToResident}>
              {t('login.switchToResident')}
            </button>
          )}
          <p className="text-xs text-muted-foreground text-center mt-4">{t('login.demo')}</p>
        </form>
      </div>
      <p className="absolute bottom-4 left-0 right-0 text-center text-[10px] text-muted-foreground">{t('app.footer')}</p>
    </div>
  );
};

export default LoginPage;
