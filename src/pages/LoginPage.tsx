import { useState } from 'react';
import { useStore } from '@/store/useStore';
import { Shield, Eye, EyeOff } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';

const LoginPage = () => {
  const { t } = useLanguage();
  const [guardId, setGuardId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const login = useStore(s => s.login);
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!guardId || !password) {
      setError(t('login.enterBoth'));
      return;
    }
    setLoading(true);
    const success = await login(guardId.toUpperCase(), password);
    setLoading(false);
    if (!success) setError(t('login.invalidCredentials'));
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
          <p className="text-muted-foreground text-sm mt-1">{t('app.subtitle')}</p>
        </div>

        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('login.guardId')}</label>
            <input
              className="input-field font-mono uppercase"
              placeholder={t('login.guardIdPlaceholder')}
              value={guardId}
              onChange={e => setGuardId(e.target.value)}
            />
          </div>

          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('login.password')}</label>
            <div className="relative">
              <input
                className="input-field pr-10"
                type={showPassword ? 'text' : 'password'}
                placeholder={t('login.passwordPlaceholder')}
                value={password}
                onChange={e => setPassword(e.target.value)}
              />
              <button
                type="button"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {error && <p className="text-destructive text-sm text-center">{error}</p>}

          <button type="submit" className="btn-primary mt-2" disabled={loading}>
            {loading ? t('login.loggingIn') : t('login.startShift')}
          </button>

          <p className="text-xs text-muted-foreground text-center mt-4">{t('login.demo')}</p>
        </form>
      </div>
      <p className="absolute bottom-4 left-0 right-0 text-center text-[10px] text-muted-foreground">
        {t('app.footer')}
      </p>
    </div>
  );
};

export default LoginPage;
