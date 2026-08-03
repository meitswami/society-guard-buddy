import { createContext, useContext, useState, useCallback, type ReactNode } from 'react';
import translations, { type Lang } from './translations';

interface LanguageContextType {
  lang: Lang;
  setLang: (lang: Lang) => void;
  t: (key: string) => string;
}

const LanguageContext = createContext<LanguageContextType>({
  lang: 'hi',
  setLang: () => {},
  t: (key) => key,
});

const readStoredLang = (): Lang => {
  const stored = localStorage.getItem('app-lang');
  if (stored === 'en' || stored === 'hi') return stored;
  localStorage.setItem('app-lang', 'hi');
  return 'hi';
};

export const LanguageProvider = ({ children }: { children: ReactNode }) => {
  const [lang, setLangState] = useState<Lang>(readStoredLang);

  const setLang = useCallback((l: Lang) => {
    localStorage.setItem('app-lang', l);
    setLangState(l);
  }, []);

  const t = useCallback((key: string) => {
    return translations[key]?.[lang] || translations[key]?.['en'] || key;
  }, [lang]);

  return (
    <LanguageContext.Provider value={{ lang, setLang, t }}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => useContext(LanguageContext);
