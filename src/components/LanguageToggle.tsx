import { useLanguage } from '@/i18n/LanguageContext';
import type { Lang } from '@/i18n/translations';

const OPTIONS: { id: Lang; label: string }[] = [
  { id: 'hi', label: 'हिंदी' },
  { id: 'en', label: 'English' },
];

const LanguageToggle = () => {
  const { lang, setLang } = useLanguage();

  return (
    <div
      className="inline-flex rounded-lg bg-secondary p-0.5 gap-0.5"
      role="group"
      aria-label="Language"
    >
      {OPTIONS.map((opt) => {
        const active = lang === opt.id;
        return (
          <button
            key={opt.id}
            type="button"
            onClick={() => setLang(opt.id)}
            aria-pressed={active}
            className={`px-2.5 py-1 rounded-md text-xs font-semibold transition-all min-w-[3.25rem] ${
              active
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'text-secondary-foreground hover:bg-accent/60'
            }`}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
};

export default LanguageToggle;
