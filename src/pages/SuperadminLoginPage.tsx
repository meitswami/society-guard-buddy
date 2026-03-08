import { useState, useEffect } from 'react';
import { Crown, Eye, EyeOff, Fingerprint } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';

interface Props {
  onLogin: (sa: { id: string; name: string; username: string }) => void;
  onBack?: () => void;
}

const SuperadminLoginPage = ({ onLogin, onBack }: Props) => {
  const { t } = useLanguage();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => { isAvailable().then(setBioAvailable); }, []);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!username || !password) { setError(t('login.enterBoth')); return; }
    setLoading(true);
    const { data } = await supabase.from('super_admins').select('*').eq('username', username.toUpperCase()).eq('password', password).single();
    setLoading(false);
    if (data) {
      auditLoginSuccess('superadmin', data.id, data.name);
      onLogin({ id: data.id, name: data.name, username: data.username });
    } else {
      auditLoginFailed('superadmin', username.toUpperCase());
      setError(t('login.invalidCredentials'));
    }
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('superadmin');
    if (!result) { setError(t('biometric.notRegistered')); return; }
    const { data } = await supabase.from('super_admins').select('*').eq('id', result.userId).single();
    if (!data) { auditLoginFailed('superadmin', result.userId, 'biometric_user_not_found'); setError(t('login.invalidCredentials')); return; }
    auditBiometricLogin('superadmin', data.id, data.name);
    onLogin({ id: data.id, name: data.name, username: data.username });
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background relative">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-10">
          <div className="w-20 h-20 rounded-2xl bg-amber-500/10 flex items-center justify-center mb-4">
            <Crown className="w-10 h-10 text-amber-500" />
          </div>
          <h1 className="page-title text-2xl">{t('superadmin.login')}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t('superadmin.loginSubtitle')}</p>
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
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('superadmin.username')}</label>
            <input className="input-field font-mono uppercase" placeholder="SUPERADMIN"
              value={username} onChange={e => setUsername(e.target.value)} />
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
            {loading ? t('login.loggingIn') : t('superadmin.loginButton')}
          </button>
          {onBack && (
            <button type="button" className="text-xs text-muted-foreground text-center mt-2 underline" onClick={onBack}>
              ← {t('admin.backToMain')}
            </button>
          )}
          <p className="text-xs text-muted-foreground text-center mt-4">{t('superadmin.demo')}</p>
        </form>
      </div>
      <p className="absolute bottom-4 left-0 right-0 text-center text-[10px] text-muted-foreground">{t('app.footer')}</p>
    </div>
  );
};

export default SuperadminLoginPage;
