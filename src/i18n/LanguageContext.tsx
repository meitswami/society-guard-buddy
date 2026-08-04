import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from 'react';
import translations, { type Lang } from './translations';
import { applyVars, type ContentOverrideMap } from '@/lib/contentTranslationCatalog';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';

interface LanguageContextType {
  lang: Lang;
  setLang: (lang: Lang) => void;
  /** Resolve UI / member copy. Optional vars replace `{name}` placeholders. Society overrides win over static defaults. */
  t: (key: string, vars?: Record<string, string | number>) => string;
  /** Reload society content overrides (e.g. after admin save). */
  reloadContentOverrides: () => Promise<void>;
}

const LanguageContext = createContext<LanguageContextType>({
  lang: 'hi',
  setLang: () => {},
  t: (key) => key,
  reloadContentOverrides: async () => {},
});

const readStoredLang = (): Lang => {
  const stored = localStorage.getItem('app-lang');
  if (stored === 'en' || stored === 'hi') return stored;
  localStorage.setItem('app-lang', 'hi');
  return 'hi';
};

export const LanguageProvider = ({ children }: { children: ReactNode }) => {
  const societyId = useStore((s) => s.societyId);
  const [lang, setLangState] = useState<Lang>(readStoredLang);
  const [overrides, setOverrides] = useState<ContentOverrideMap>({});

  const setLang = useCallback((l: Lang) => {
    localStorage.setItem('app-lang', l);
    setLangState(l);
  }, []);

  const reloadContentOverrides = useCallback(async () => {
    if (!societyId) {
      setOverrides({});
      return;
    }
    const { data, error } = await supabase
      .from('society_content_translations')
      .select('content_key, text_en, text_hi')
      .eq('society_id', societyId);
    if (error) {
      console.warn('society_content_translations load failed', error.message);
      return;
    }
    const next: ContentOverrideMap = {};
    for (const row of data || []) {
      next[row.content_key] = {
        en: row.text_en || '',
        hi: row.text_hi || '',
      };
    }
    setOverrides(next);
  }, [societyId]);

  useEffect(() => {
    void reloadContentOverrides();
  }, [reloadContentOverrides]);

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => {
      const override = overrides[key];
      // Prefer active language override, then static translation for that language,
      // then the other language — never let empty Hindi override fall back to English override
      // before the static Hindi string.
      const fromOverrideLang = override?.[lang]?.trim();
      const fromStaticLang = translations[key]?.[lang]?.trim();
      const fromOverrideEn = lang !== 'en' ? override?.en?.trim() : '';
      const fromStaticEn = lang !== 'en' ? translations[key]?.en?.trim() : '';
      const fromOverrideHi = lang !== 'hi' ? override?.hi?.trim() : '';
      const fromStaticHi = lang !== 'hi' ? translations[key]?.hi?.trim() : '';
      const raw =
        fromOverrideLang ||
        fromStaticLang ||
        fromOverrideEn ||
        fromStaticEn ||
        fromOverrideHi ||
        fromStaticHi ||
        key;
      return applyVars(raw, vars);
    },
    [lang, overrides],
  );

  return (
    <LanguageContext.Provider value={{ lang, setLang, t, reloadContentOverrides }}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => useContext(LanguageContext);
