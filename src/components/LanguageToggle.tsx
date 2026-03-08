import { useLanguage } from '@/i18n/LanguageContext';

const LanguageToggle = () => {
  const { lang, setLang } = useLanguage();

  return (
    <button
      onClick={() => setLang(lang === 'en' ? 'hi' : 'en')}
      className="px-2 py-1 rounded-lg bg-secondary text-secondary-foreground text-xs font-semibold transition-all hover:bg-accent min-w-[2.5rem]"
    >
      {lang === 'en' ? 'हिं' : 'EN'}
    </button>
  );
};

export default LanguageToggle;
