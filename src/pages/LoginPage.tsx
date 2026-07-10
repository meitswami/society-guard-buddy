import { useState, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { Shield, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';
import { completeLoginSession } from '@/lib/loginSession';
import { checkSocietyGeofence } from '@/lib/geofenceUtils';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import PasswordResetFlow from '@/components/PasswordResetFlow';
import { LoginFooter } from '@/components/LoginFooter';
import { findGuardForOtpLogin } from '@/lib/guardOtpLogin';
import GuardLoginPreview from '@/components/GuardLoginPreview';

interface Props {
  societyId: string;
  onSwitchToResident?: () => void;
}

const LoginPage = ({ societyId, onSwitchToResident }: Props) => {
  const { t } = useLanguage();
  const [loginMode, setLoginMode] = useState<'password' | 'otp'>('password');
  const [guardId, setGuardId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const { login, establishGuardSession, setSocietyId, loadGuards } = useStore();
  const [loading, setLoading] = useState(false);
  const [showResetFlow, setShowResetFlow] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => {
    setSocietyId(societyId);
    isAvailable().then(setBioAvailable);
  }, [isAvailable, setSocietyId, societyId]);

  const checkGeofence = async (): Promise<boolean> => {
    const result = await checkSocietyGeofence(societyId, 'strict');
    if (result.ok) return true;
    if (result.reason === 'outside') {
      setError(`${t('admin.geofenceBlocked')} (${Math.round(result.distanceM!)}m away)`);
    } else {
      setError(t('admin.geofenceBlocked'));
    }
    return false;
  };

  const handleOtpVerified = async (phone: string) => {
    setError('');
    const lookup = await findGuardForOtpLogin(phone, societyId);
    if (!lookup.ok) {
      if (lookup.reason === 'password_mode') {
        setError(t('login.guardOtpPasswordMode'));
      } else {
        setError(t('login.guardOtpPhoneNotRegistered'));
      }
      return;
    }
    const guard = lookup.guard;

    setLoading(true);
    setError(t('admin.gettingLocation'));
    const withinFence = await checkGeofence();
    if (!withinFence) {
      setLoading(false);
      return;
    }
    setError('');

    setSocietyId(societyId);
    const success = await establishGuardSession({
      guard_id: guard.guard_id,
      name: guard.name,
      password: guard.password,
    });
    setLoading(false);
    if (success) {
      completeLoginSession({ userType: 'guard', userId: guard.guard_id, userName: guard.name, societyId, method: 'otp' });
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
      completeLoginSession({ userType: 'guard', userId: guardData.guard_id, userName: guardData.name, societyId });
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

        <GuardLoginPreview variant="inline" />

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
              <button
                type="button"
                className="text-xs text-primary text-center mt-1 underline"
                onClick={() => setShowResetFlow(true)}
              >
                {t('login.forgotPassword')}
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
      {showResetFlow && (
        <div className="fixed inset-0 z-50 bg-background">
          <PasswordResetFlow userType="guard" societyId={societyId} onBack={() => setShowResetFlow(false)} />
        </div>
      )}
    </div>
  );
};

export default LoginPage;
