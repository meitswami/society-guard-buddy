import { useState, useEffect } from 'react';
import { Shield, Eye, EyeOff, Fingerprint } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useBiometric } from '@/hooks/useBiometric';

interface Props {
  onLogin: (admin: { id: string; name: string; adminId: string }) => void;
  onBack?: () => void;
}

const AdminLoginPage = ({ onLogin, onBack }: Props) => {
  const { t } = useLanguage();
  const [adminId, setAdminId] = useState('');
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
    if (!adminId || !password) { setError(t('login.enterBoth')); return; }
    setLoading(true);
    const { data } = await supabase.from('admins').select('*').eq('admin_id', adminId.toUpperCase()).eq('password', password).single();
    setLoading(false);
    if (data) onLogin({ id: data.id, name: data.name, adminId: data.admin_id });
    else setError(t('login.invalidCredentials'));
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('admin');
    if (!result) { setError(t('biometric.notRegistered')); return; }
    const { data } = await supabase.from('admins').select('*').eq('id', result.userId).single();
    if (!data) { setError(t('login.invalidCredentials')); return; }
    onLogin({ id: data.id, name: data.name, adminId: data.admin_id });
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background relative">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-10">
          <div className="w-20 h-20 rounded-2xl bg-destructive/10 flex items-center justify-center mb-4">
            <Shield className="w-10 h-10 text-destructive" />
          </div>
          <h1 className="page-title text-2xl">{t('admin.login')}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t('admin.loginSubtitle')}</p>
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
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('admin.adminId')}</label>
            <input className="input-field font-mono uppercase" placeholder="ADMIN"
              value={adminId} onChange={e => setAdminId(e.target.value)} />
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
            {loading ? t('login.loggingIn') : t('admin.loginButton')}
          </button>
          {onBack && (
            <button type="button" className="text-xs text-muted-foreground text-center mt-2 underline" onClick={onBack}>
              ← {t('admin.backToMain')}
            </button>
          )}
          <p className="text-xs text-muted-foreground text-center mt-4">{t('admin.demo')}</p>
        </form>
      </div>
      <p className="absolute bottom-4 left-0 right-0 text-center text-[10px] text-muted-foreground">{t('app.footer')}</p>
    </div>
  );
};

export default AdminLoginPage;
