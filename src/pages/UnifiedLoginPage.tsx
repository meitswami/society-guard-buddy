import { useState, useEffect } from 'react';
import { Shield, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';
import PasswordResetFlow from '@/components/PasswordResetFlow';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import { LoginFooter } from '@/components/LoginFooter';

interface Props {
  onGuardLogin: () => void;
  onResidentLogin: (resident: { id: string; name: string; phone: string; flatId: string; flatNumber: string }) => void;
  onAdminLogin: (admin: { id: string; name: string; adminId: string; societyId: string | null }) => void;
  onSuperadminLogin: (sa: { id: string; name: string; username: string }) => void;
}

function getDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const UnifiedLoginPage = ({ onGuardLogin, onResidentLogin, onAdminLogin, onSuperadminLogin }: Props) => {
  const { t } = useLanguage();
  const { login, setSocietyId, loadGuards } = useStore();
  const [loginMode, setLoginMode] = useState<'credentials' | 'otp'>('otp');
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showResetFlow, setShowResetFlow] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => { isAvailable().then(setBioAvailable); }, []);

  const setSocietyFromFlat = async (flatId: string) => {
    const { data: flat } = await supabase.from('flats').select('society_id').eq('id', flatId).single();
    if (flat?.society_id) setSocietyId(flat.society_id);
  };

  const checkGeofence = (): Promise<boolean> => {
    return new Promise(async (resolve) => {
      const { data: geoData } = await supabase.from('geofence_settings').select('*').order('created_at', { ascending: false }).limit(1);
      if (!geoData || geoData.length === 0) { resolve(true); return; }
      const geo = geoData[0];
      if (!navigator.geolocation) { resolve(true); return; }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const dist = getDistanceMeters(pos.coords.latitude, pos.coords.longitude, geo.latitude, geo.longitude);
          resolve(dist <= geo.radius_meters);
        },
        () => resolve(true),
        { enableHighAccuracy: true, timeout: 10000 }
      );
    });
  };

  // OTP verified - lookup resident or guard by phone
  const handleOtpVerified = async (phone: string) => {
    // Try resident first
    const { data: resident } = await supabase.from('resident_users').select('*').eq('phone', phone).single();
    if (resident) {
      auditLoginSuccess('resident', resident.id, resident.name);
      registerOneSignalUser({ userType: 'resident', userId: resident.id, userName: resident.name, flatNumber: resident.flat_number });
      promptPushPermission();
      await setSocietyFromFlat(resident.flat_id);
      onResidentLogin({ id: resident.id, name: resident.name, phone: resident.phone, flatId: resident.flat_id, flatNumber: resident.flat_number });
      return;
    }

    // Try guard with OTP auth mode
    const { data: guard } = await supabase.from('guards').select('*').eq('phone', phone).eq('auth_mode', 'otp').single();
    if (guard) {
      const withinFence = await checkGeofence();
      if (!withinFence) { setError(t('admin.geofenceBlocked')); return; }
      if (guard.society_id) setSocietyId(guard.society_id);
      await loadGuards();
      const success = await login(guard.guard_id, guard.password);
      if (success) {
        auditLoginSuccess('guard', guard.guard_id, guard.name);
        registerOneSignalUser({ userType: 'guard', userId: guard.guard_id, userName: guard.name });
        promptPushPermission();
        onGuardLogin();
      }
      return;
    }

    setError('No account found for this phone number. Contact your admin.');
  };

  const handleCredentialLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!identifier || !password) { setError(t('login.enterBoth')); return; }
    setLoading(true);

    const id = identifier.trim();

    // 1. Superadmin
    const { data: sa } = await supabase.from('super_admins').select('*').eq('username', id).eq('password', password).single();
    if (sa) {
      auditLoginSuccess('superadmin', sa.id, sa.name);
      setLoading(false);
      onSuperadminLogin({ id: sa.id, name: sa.name, username: sa.username });
      return;
    }

    // 2. Admin
    const { data: admin } = await supabase.from('admins').select('*').eq('admin_id', id.toUpperCase()).eq('password', password).single();
    if (admin) {
      auditLoginSuccess('admin', admin.id, admin.name);
      if (admin.society_id) setSocietyId(admin.society_id);
      setLoading(false);
      onAdminLogin({ id: admin.id, name: admin.name, adminId: admin.admin_id, societyId: admin.society_id });
      return;
    }

    // 3. Guard (password mode)
    const { data: guard } = await supabase.from('guards').select('*').eq('guard_id', id.toUpperCase()).eq('password', password).single();
    if (guard) {
      const withinFence = await checkGeofence();
      if (!withinFence) { setError(t('admin.geofenceBlocked')); setLoading(false); return; }
      if (guard.society_id) setSocietyId(guard.society_id);
      await loadGuards();
      const success = await login(guard.guard_id, guard.password);
      setLoading(false);
      if (success) {
        auditLoginSuccess('guard', guard.guard_id, guard.name);
        registerOneSignalUser({ userType: 'guard', userId: guard.guard_id, userName: guard.name });
        promptPushPermission();
        onGuardLogin();
      } else {
        setError(t('login.invalidCredentials'));
      }
      return;
    }

    // 4. Resident (password)
    const { data: resident } = await supabase.from('resident_users').select('*').eq('phone', id).eq('password', password).single();
    if (resident) {
      auditLoginSuccess('resident', resident.id, resident.name);
      registerOneSignalUser({ userType: 'resident', userId: resident.id, userName: resident.name, flatNumber: resident.flat_number });
      promptPushPermission();
      await setSocietyFromFlat(resident.flat_id);
      setLoading(false);
      onResidentLogin({ id: resident.id, name: resident.name, phone: resident.phone, flatId: resident.flat_id, flatNumber: resident.flat_number });
      return;
    }

    auditLoginFailed('guard', id);
    setError(t('login.invalidCredentials'));
    setLoading(false);
  };

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-3">
            <Shield className="w-8 h-8 text-primary" />
          </div>
          <h1 className="page-title text-xl">{t('app.name')}</h1>
          <p className="text-muted-foreground text-xs mt-1">{t('app.subtitle')}</p>
        </div>

        {/* Mode Toggle */}
        <div className="flex gap-1 p-1 bg-muted rounded-xl mb-4">
          <button
            onClick={() => { setLoginMode('otp'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'otp' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <Phone className="w-3.5 h-3.5" /> OTP Login
          </button>
          <button
            onClick={() => { setLoginMode('credentials'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'credentials' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <Shield className="w-3.5 h-3.5" /> ID & Password
          </button>
        </div>

        {loginMode === 'otp' ? (
          <OTPLoginFlow
            onVerified={handleOtpVerified}
            title="Login with OTP"
            subtitle="Residents & OTP-enabled guards"
          />
        ) : (
          <>
            {bioAvailable && (
              <button onClick={async () => {
                setError('');
                const result = await authenticate('guard');
                if (!result) {
                  const resResult = await authenticate('resident');
                  if (!resResult) { setError(t('biometric.notRegistered')); return; }
                  const { data } = await supabase.from('resident_users').select('*').eq('id', resResult.userId).single();
                  if (!data) { setError(t('login.invalidCredentials')); return; }
                  await setSocietyFromFlat(data.flat_id);
                  onResidentLogin({ id: data.id, name: data.name, phone: data.phone, flatId: data.flat_id, flatNumber: data.flat_number });
                  return;
                }
                const { data } = await supabase.from('guards').select('*').eq('id', result.userId).single();
                if (!data) { setError(t('login.invalidCredentials')); return; }
                if (data.society_id) setSocietyId(data.society_id);
                await loadGuards();
                const withinFence = await checkGeofence();
                if (!withinFence) { setError(t('admin.geofenceBlocked')); return; }
                const success = await login(data.guard_id, data.password);
                if (success) onGuardLogin();
              }} disabled={bioLoading}
                className="w-full mb-4 py-3 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-1 hover:bg-primary/10 transition-colors">
                <Fingerprint className="w-7 h-7 text-primary" />
                <span className="text-xs font-medium text-primary">{t('biometric.loginButton')}</span>
              </button>
            )}

            <form onSubmit={handleCredentialLogin} className="flex flex-col gap-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">
                  ID / Phone / Username
                </label>
                <input className="input-field font-mono" placeholder="Guard ID, Admin ID, Phone..."
                  value={identifier} onChange={e => setIdentifier(e.target.value)} />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">{t('login.password')}</label>
                <div className="relative">
                  <input className="input-field pr-10" type={showPassword ? 'text' : 'password'}
                    placeholder={t('login.passwordPlaceholder')} value={password} onChange={e => setPassword(e.target.value)} />
                  <button type="button" className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                    onClick={() => setShowPassword(!showPassword)}>
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>
              <p className="text-[10px] text-muted-foreground text-center">
                Guards, Admins & Superadmins
              </p>
              {error && <p className="text-destructive text-sm text-center">{error}</p>}
              <button type="submit" className="btn-primary mt-1" disabled={loading}>
                {loading ? t('login.loggingIn') : 'Login'}
              </button>
              <button type="button" className="text-xs text-primary text-center mt-1 underline" onClick={() => setShowResetFlow(true)}>
                Forgot Password?
              </button>
            </form>
          </>
        )}

        {loginMode === 'otp' && error && <p className="text-destructive text-sm text-center mt-2">{error}</p>}
      </div>
      <LoginFooter />
      {showResetFlow && (
        <div className="fixed inset-0 z-50 bg-background">
          <PasswordResetFlow userType="resident" onBack={() => setShowResetFlow(false)} />
        </div>
      )}
    </div>
  );
};

export default UnifiedLoginPage;
