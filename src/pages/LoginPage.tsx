import { useState, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { Shield, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import { LoginFooter } from '@/components/LoginFooter';

interface Props {
  societyId: string;
  onSwitchToResident?: () => void;
}

function getDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const LoginPage = ({ societyId, onSwitchToResident }: Props) => {
  const { t } = useLanguage();
  const [loginMode, setLoginMode] = useState<'password' | 'otp'>('password');
  const [guardId, setGuardId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const { login, setSocietyId, loadGuards } = useStore();
  const [loading, setLoading] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => { isAvailable().then(setBioAvailable); }, []);

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

  const handleOtpVerified = async (phone: string) => {
    const { data: guard } = await supabase
      .from('guards')
      .select('*')
      .eq('phone', phone)
      .eq('auth_mode', 'otp')
      .eq('society_id', societyId)
      .maybeSingle();
    if (!guard) { setError(t('login.invalidCredentials')); return; }

    setLoading(true);
    setError(t('admin.gettingLocation'));
    const withinFence = await checkGeofence();
    if (!withinFence) { setLoading(false); return; }
    setError('');

    setSocietyId(societyId);
    await loadGuards();
    const success = await login(guard.guard_id, guard.password);
    setLoading(false);
    if (success) {
      auditLoginSuccess('guard', guard.guard_id, guard.name);
      registerOneSignalUser({ userType: 'guard', userId: guard.guard_id, userName: guard.name, societyId });
      promptPushPermission();
    } else {
      setError(t('login.invalidCredentials'));
    }
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

    const { data: guardData } = await supabase
      .from('guards')
      .select('*')
      .eq('guard_id', guardId.toUpperCase())
      .eq('password', password)
      .eq('society_id', societyId)
      .maybeSingle();
    if (!guardData) {
      auditLoginFailed('guard', guardId.toUpperCase());
      setError(t('login.invalidCredentials'));
      setLoading(false);
      return;
    }

    setSocietyId(societyId);
    await loadGuards();

    const success = await login(guardData.guard_id, guardData.password);
    setLoading(false);
    if (success) {
      auditLoginSuccess('guard', guardData.guard_id, guardData.name);
      registerOneSignalUser({ userType: 'guard', userId: guardData.guard_id, userName: guardData.name, societyId });
      promptPushPermission();
    } else {
      auditLoginFailed('guard', guardId.toUpperCase());
      setError(t('login.invalidCredentials'));
    }
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('guard');
    if (!result) { setError(t('biometric.notRegistered')); return; }
    const { data } = await supabase.from('guards').select('*').eq('id', result.userId).single();
    if (!data || data.society_id !== societyId) { setError(t('login.invalidCredentials')); return; }

    setSocietyId(societyId);
    await loadGuards();

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
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-8">
          <div className="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
            <Shield className="w-10 h-10 text-primary" />
          </div>
          <h1 className="page-title text-2xl text-center">{t('app.name')}</h1>
          <p className="text-muted-foreground text-xs mt-1 text-center">{t('app.subtitle')}</p>
          <p className="text-muted-foreground/80 text-[11px] mt-0.5 text-center">{t('app.tagline')}</p>
          <h2 className="page-title text-lg mt-4">{t('login.guardLogin')}</h2>
        </div>

        {/* Mode Toggle */}
        <div className="flex gap-1 p-1 bg-muted rounded-xl mb-4">
          <button onClick={() => { setLoginMode('password'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'password' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}>
            <Shield className="w-3.5 h-3.5" /> Password
          </button>
          <button onClick={() => { setLoginMode('otp'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'otp' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}>
            <Phone className="w-3.5 h-3.5" /> OTP
          </button>
        </div>

        {loginMode === 'otp' ? (
          <>
            <OTPLoginFlow
              embedded
              onVerified={handleOtpVerified}
              title="Guard OTP Login"
              subtitle="Enter your registered phone number"
            />
            {error && <p className="text-destructive text-sm text-center mt-2">{error}</p>}
          </>
        ) : (
          <>
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
            </form>
          </>
        )}

        {onSwitchToResident && (
          <button type="button" className="w-full text-xs text-muted-foreground text-center mt-4 underline" onClick={onSwitchToResident}>
            {t('login.switchToResident')}
          </button>
        )}
      </div>
      <LoginFooter />
    </div>
  );
};

export default LoginPage;
