import { useCallback, useEffect, useMemo, useState } from 'react';
import { Languages, Save, RotateCcw } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import translations from '@/i18n/translations';
import {
  CONTENT_TRANSLATION_GROUPS,
  ALL_EDITABLE_CONTENT_KEYS,
} from '@/lib/contentTranslationCatalog';
import { confirmAction } from '@/lib/swal';

type DraftRow = { en: string; hi: string };

const SocietyContentEditor = () => {
  const societyId = useStore((s) => s.societyId);
  const { t, reloadContentOverrides, lang } = useLanguage();
  const [drafts, setDrafts] = useState<Record<string, DraftRow>>({});
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [openGroup, setOpenGroup] = useState<string>(CONTENT_TRANSLATION_GROUPS[0]?.id ?? '');

  const defaultsFor = useCallback((key: string): DraftRow => {
    const row = translations[key];
    return { en: row?.en ?? '', hi: row?.hi ?? '' };
  }, []);

  const load = useCallback(async () => {
    if (!societyId) {
      setDrafts({});
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from('society_content_translations')
      .select('content_key, text_en, text_hi')
      .eq('society_id', societyId);
    setLoading(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    const map: Record<string, DraftRow> = {};
    for (const key of ALL_EDITABLE_CONTENT_KEYS) {
      map[key] = defaultsFor(key);
    }
    for (const row of data || []) {
      if (!ALL_EDITABLE_CONTENT_KEYS.includes(row.content_key)) continue;
      map[row.content_key] = {
        en: row.text_en ?? '',
        hi: row.text_hi ?? '',
      };
    }
    setDrafts(map);
  }, [societyId, defaultsFor]);

  useEffect(() => {
    void load();
  }, [load]);

  const setField = (key: string, langKey: 'en' | 'hi', value: string) => {
    setDrafts((prev) => ({
      ...prev,
      [key]: { ...(prev[key] || defaultsFor(key)), [langKey]: value },
    }));
  };

  const save = async () => {
    if (!societyId) {
      toast.error('Select a society first');
      return;
    }
    setSaving(true);
    const rows = ALL_EDITABLE_CONTENT_KEYS.map((content_key) => {
      const d = drafts[content_key] || defaultsFor(content_key);
      return {
        society_id: societyId,
        content_key,
        text_en: d.en.trim(),
        text_hi: d.hi.trim(),
        updated_by: 'admin',
      };
    });
    const { error } = await supabase.from('society_content_translations').upsert(rows, {
      onConflict: 'society_id,content_key',
    });
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    await reloadContentOverrides();
    toast.success(t('contentEditor.saved'));
  };

  const resetDefaults = async () => {
    if (!societyId) return;
    const ok = await confirmAction(
      t('contentEditor.resetDefaults'),
      lang === 'hi'
        ? 'सोसाइटी के सभी अनुकूलित अनुवाद हटाकर ऐप की मूल भाषा वापस आ जाएगी।'
        : 'This removes custom society translations and restores app defaults.',
      t('swal.yes'),
      t('swal.no'),
    );
    if (!ok) return;
    const { error } = await supabase
      .from('society_content_translations')
      .delete()
      .eq('society_id', societyId)
      .in('content_key', ALL_EDITABLE_CONTENT_KEYS);
    if (error) {
      toast.error(error.message);
      return;
    }
    const map: Record<string, DraftRow> = {};
    for (const key of ALL_EDITABLE_CONTENT_KEYS) map[key] = defaultsFor(key);
    setDrafts(map);
    await reloadContentOverrides();
    toast.success(t('contentEditor.saved'));
  };

  const groups = useMemo(() => CONTENT_TRANSLATION_GROUPS, []);
  const activeGroupId = groups.some((g) => g.id === openGroup) ? openGroup : (groups[0]?.id ?? '');

  if (!societyId) {
    return (
      <div className="card-section mb-4 p-4">
        <p className="text-xs text-muted-foreground">Select a society to edit member translations.</p>
      </div>
    );
  }

  return (
    <div className="card-section mb-4">
      <div className="flex items-start gap-2 mb-3">
        <div className="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
          <Languages className="w-4 h-4 text-primary" />
        </div>
        <div className="min-w-0 flex-1">
          <h2 className="text-sm font-semibold">{t('contentEditor.title')}</h2>
          <p className="text-[10px] text-muted-foreground mt-0.5 leading-relaxed">
            {t('contentEditor.subtitle')}
          </p>
        </div>
      </div>

      {groups.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-3">
          {groups.map((g) => (
            <button
              key={g.id}
              type="button"
              onClick={() => setOpenGroup(g.id)}
              className={`px-2.5 py-1 rounded-lg text-[10px] font-semibold transition-colors ${
                g.id === activeGroupId
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-secondary text-secondary-foreground hover:bg-accent'
              }`}
            >
              {g.title}
            </button>
          ))}
        </div>
      )}

      {loading ? (
        <p className="text-xs text-muted-foreground py-4">{t('app.loading')}</p>
      ) : (
        groups
          .filter((g) => g.id === activeGroupId)
          .map((g) => (
            <div key={g.id} className="space-y-3">
              <p className="text-[10px] text-muted-foreground leading-relaxed">{g.description}</p>
              {g.fields.map((field) => {
                const draft = drafts[field.key] || defaultsFor(field.key);
                return (
                  <div key={field.key} className="rounded-lg border border-border/70 p-2.5 space-y-2">
                    <p className="text-[10px] font-semibold text-foreground">{field.label}</p>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                      <label className="block space-y-1">
                        <span className="text-[9px] uppercase tracking-wider text-muted-foreground">
                          {t('contentEditor.english')}
                        </span>
                        {field.multiline ? (
                          <textarea
                            className="input-field text-xs w-full min-h-[4.5rem] resize-y"
                            value={draft.en}
                            onChange={(e) => setField(field.key, 'en', e.target.value)}
                          />
                        ) : (
                          <input
                            className="input-field text-xs w-full"
                            value={draft.en}
                            onChange={(e) => setField(field.key, 'en', e.target.value)}
                          />
                        )}
                      </label>
                      <label className="block space-y-1">
                        <span className="text-[9px] uppercase tracking-wider text-muted-foreground">
                          {t('contentEditor.hindi')}
                        </span>
                        {field.multiline ? (
                          <textarea
                            className="input-field text-xs w-full min-h-[4.5rem] resize-y"
                            value={draft.hi}
                            onChange={(e) => setField(field.key, 'hi', e.target.value)}
                          />
                        ) : (
                          <input
                            className="input-field text-xs w-full"
                            value={draft.hi}
                            onChange={(e) => setField(field.key, 'hi', e.target.value)}
                          />
                        )}
                      </label>
                    </div>
                    <p className="text-[9px] text-muted-foreground/80 font-mono truncate">
                      {t('contentEditor.defaultHint')}: {defaultsFor(field.key)[lang] || defaultsFor(field.key).en}
                    </p>
                  </div>
                );
              })}
            </div>
          ))
      )}

      <div className="flex flex-wrap gap-2 mt-4">
        <button type="button" className="btn-primary text-xs inline-flex items-center gap-1.5" disabled={saving} onClick={() => void save()}>
          <Save className="w-3.5 h-3.5" />
          {saving ? t('app.loading') : t('contentEditor.save')}
        </button>
        <button type="button" className="btn-secondary text-xs inline-flex items-center gap-1.5" onClick={() => void resetDefaults()}>
          <RotateCcw className="w-3.5 h-3.5" />
          {t('contentEditor.resetDefaults')}
        </button>
      </div>
    </div>
  );
};

export default SocietyContentEditor;
