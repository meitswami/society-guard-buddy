import { useState, useEffect } from 'react';
import { Home, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';
import PasswordResetFlow from '@/components/PasswordResetFlow';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';
import { useStore } from '@/store/useStore';
import { LoginFooter } from '@/components/LoginFooter';

interface Props {
  onLogin: (resident: { id: string; name: string; phone: string; flatId: string; flatNumber: string }) => void;
  onSwitchToGuard: () => void;
}

const ResidentLoginPage = ({ onLogin, onSwitchToGuard }: Props) => {
  const { t } = useLanguage();
  const { setSocietyId } = useStore();
  const [loginMode, setLoginMode] = useState<'otp' | 'password'>('otp');
  const [showResetFlow, setShowResetFlow] = useState(false);
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => { isAvailable().then(setBioAvailable); }, []);

  const setSocietyFromFlat = async (flatId: string) => {
    const { data: flat } = await supabase.from('flats').select('society_id').eq('id', flatId).single();
    if (flat?.society_id) setSocietyId(flat.society_id);
  };

  const handleOtpVerified = async (verifiedPhone: string) => {
    const { data } = await supabase.from('resident_users').select('*').eq('phone', verifiedPhone).single();
    if (!data) { setError('No resident account found for this phone. Contact your admin.'); return; }
    auditLoginSuccess('resident', data.id, data.name);
    registerOneSignalUser({ userType: 'resident', userId: data.id, userName: data.name, flatNumber: data.flat_number });
    promptPushPermission();
    await setSocietyFromFlat(data.flat_id);
    onLogin({ id: data.id, name: data.name, phone: data.phone, flatId: data.flat_id, flatNumber: data.flat_number });
  };

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!phone || !password) { setError(t('resident.enterBoth')); return; }
    setLoading(true);
    const { data, error: err } = await supabase.from('resident_users').select('*').eq('phone', phone).eq('password', password).single();
    setLoading(false);
    if (err || !data) { auditLoginFailed('resident', phone); setError(t('login.invalidCredentials')); return; }
    auditLoginSuccess('resident', data.id, data.name);
    registerOneSignalUser({ userType: 'resident', userId: data.id, userName: data.name, flatNumber: data.flat_number });
    promptPushPermission();
    await setSocietyFromFlat(data.flat_id);
    onLogin({ id: data.id, name: data.name, phone: data.phone, flatId: data.flat_id, flatNumber: data.flat_number });
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('resident');
    if (!result) { setError(t('biometric.notRegistered')); return; }
    const { data } = await supabase.from('resident_users').select('*').eq('id', result.userId).single();
    if (!data) { auditLoginFailed('resident', result.userId, 'biometric_user_not_found'); setError(t('login.invalidCredentials')); return; }
    auditBiometricLogin('resident', data.id, data.name);
    await setSocietyFromFlat(data.flat_id);
    onLogin({ id: data.id, name: data.name, phone: data.phone, flatId: data.flat_id, flatNumber: data.flat_number });
  };

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-8">
          <div className="w-20 h-20 rounded-2xl bg-accent/20 flex items-center justify-center mb-4">
            <Home className="w-10 h-10 text-accent-foreground" />
          </div>
          <h1 className="page-title text-2xl">{t('resident.loginTitle')}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t('resident.loginSubtitle')}</p>
        </div>

        {/* Mode Toggle */}
        <div className="flex gap-1 p-1 bg-muted rounded-xl mb-4">
          <button onClick={() => { setLoginMode('otp'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'otp' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}>
            <Phone className="w-3.5 h-3.5" /> OTP Login
          </button>
          <button onClick={() => { setLoginMode('password'); setError(''); }}
            className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
              loginMode === 'password' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
            }`}>
            <Eye className="w-3.5 h-3.5" /> Password
          </button>
        </div>

        {loginMode === 'otp' ? (
          <OTPLoginFlow
            onVerified={handleOtpVerified}
            title={t('resident.loginTitle')}
            subtitle="Enter your registered phone number"
          />
        ) : (
          <>
            {bioAvailable && (
              <button onClick={handleBiometricLogin} disabled={bioLoading}
                className="w-full mb-4 py-4 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-2 hover:bg-primary/10 transition-colors">
                <Fingerprint className="w-8 h-8 text-primary" />
                <span className="text-sm font-medium text-primary">{t('biometric.loginButton')}</span>
              </button>
            )}

            <form onSubmit={handlePasswordLogin} className="flex flex-col gap-4">
              <div>
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('common.phone')}</label>
                <input className="input-field font-mono" placeholder="10-digit number" type="tel" maxLength={10}
                  value={phone} onChange={e => setPhone(e.target.value.replace(/\D/g, ''))} />
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
                {loading ? t('login.loggingIn') : t('resident.login')}
              </button>
            </form>
          </>
        )}

        {loginMode === 'otp' && error && <p className="text-destructive text-sm text-center mt-2">{error}</p>}

        <button type="button" className="w-full text-xs text-muted-foreground text-center mt-4 underline" onClick={onSwitchToGuard}>
          {t('resident.switchToGuard')}
        </button>
        <button type="button" className="w-full text-xs text-primary text-center mt-1 underline" onClick={() => setShowResetFlow(true)}>
          Forgot Password?
        </button>
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

export default ResidentLoginPage;
