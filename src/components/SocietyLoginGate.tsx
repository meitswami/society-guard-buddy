import { useState, useEffect } from 'react';
import { ArrowRight, Building2, Shield, Sparkles } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { LoginFooter } from '@/components/LoginFooter';
import { fetchActiveSocietiesByName, type LoginSocietyRow } from '@/lib/societiesLogin';
import { Link } from 'react-router-dom';

interface Props {
  onContinue: (society: LoginSocietyRow) => void;
  /** Omitted on phones/tablets so superadmin entry is desktop-only. */
  onSuperadmin?: () => void;
}

const SocietyLoginGate = ({ onContinue, onSuperadmin }: Props) => {
  const { t } = useLanguage();
  const [societies, setSocieties] = useState<LoginSocietyRow[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      const list = await fetchActiveSocietiesByName();
      if (!cancelled) {
        setSocieties(list);
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const selected = societies.find((s) => s.id === selectedId);

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-3">
            <Shield className="w-8 h-8 text-primary" />
          </div>
          <h1 className="page-title text-2xl text-center">{t('app.name')}</h1>
          <p className="text-muted-foreground text-sm mt-1 text-center">{t('app.subtitle')}</p>
          <p className="text-muted-foreground/80 text-xs mt-1 text-center">{t('app.tagline')}</p>
        </div>

        <div className="flex flex-col gap-3">
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
            {t('login.selectSociety')}
          </label>
          <div className="relative">
            <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground pointer-events-none" />
            <select
              className="input-field pl-10 w-full appearance-none"
              value={selectedId}
              disabled={loading}
              onChange={(e) => setSelectedId(e.target.value)}
            >
              <option value="">{loading ? t('app.loading') : t('login.societyPlaceholder')}</option>
              {societies.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>
          <button
            type="button"
            className="btn-primary mt-1"
            disabled={!selected}
            onClick={() => selected && onContinue(selected)}
          >
            {t('login.continueToLogin')}
          </button>
          <Link
            to="/society-signup"
            className="group relative mt-2 flex w-full items-center justify-center gap-2 overflow-hidden rounded-xl bg-gradient-to-r from-primary via-amber-500 to-primary bg-[length:200%_100%] py-3.5 pl-4 pr-3 text-sm font-semibold text-primary-foreground shadow-lg shadow-primary/30 ring-1 ring-primary/40 transition motion-safe:hover:bg-[position:100%_0] motion-safe:duration-500 active:scale-[0.98] dark:ring-primary/25"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/25 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100 dark:via-white/10" aria-hidden />
            <Building2 className="relative h-5 w-5 shrink-0" aria-hidden />
            <span className="relative flex-1 text-center">{t('login.registerNewSociety')}</span>
            <Sparkles className="relative h-4 w-4 shrink-0 opacity-95" aria-hidden />
            <ArrowRight className="relative h-4 w-4 shrink-0 opacity-90 transition group-hover:translate-x-0.5" aria-hidden />
          </Link>
          <p className="text-[10px] text-muted-foreground text-center leading-snug px-1">{t('login.createSocietyCta')}</p>
          {onSuperadmin && (
          <button
            type="button"
            className="text-xs text-muted-foreground text-center mt-2 underline"
            onClick={onSuperadmin}
          >
            {t('login.superadminPlatform')}
          </button>
          )}
        </div>
      </div>
      <LoginFooter />
    </div>
  );
};

export default SocietyLoginGate;
