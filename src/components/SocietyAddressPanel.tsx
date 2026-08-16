import { useCallback, useEffect, useMemo, useState } from 'react';
import { MapPin } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import { CapsInput, CapsTextarea } from '@/components/CapsInput';
import { letterheadAddressLine } from '@/lib/pdfLetterhead';

type AddressDraft = {
  address: string;
  city: string;
  state: string;
  pincode: string;
};

const emptyDraft = (): AddressDraft => ({
  address: '',
  city: '',
  state: '',
  pincode: '',
});

/**
 * Admin → Settings: edit the registered society address used on letterheads and reports.
 */
export default function SocietyAddressPanel() {
  const societyId = useStore((s) => s.societyId);
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [societyName, setSocietyName] = useState('');
  const [draft, setDraft] = useState<AddressDraft>(emptyDraft);

  const reload = useCallback(async () => {
    if (!societyId) {
      setSocietyName('');
      setDraft(emptyDraft());
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from('societies')
      .select('name, address, city, state, pincode')
      .eq('id', societyId)
      .maybeSingle();
    setLoading(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    setSocietyName(data?.name ?? '');
    setDraft({
      address: data?.address ?? '',
      city: data?.city ?? '',
      state: data?.state ?? '',
      pincode: data?.pincode ?? '',
    });
  }, [societyId]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const preview = useMemo(
    () => letterheadAddressLine(draft),
    [draft],
  );

  const onSave = async () => {
    if (!societyId) return;
    setSaving(true);
    const { error } = await supabase
      .from('societies')
      .update({
        address: draft.address.trim() || null,
        city: draft.city.trim() || null,
        state: draft.state.trim() || null,
        pincode: draft.pincode.trim() || null,
      })
      .eq('id', societyId);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success(t('settings.societyAddressSaved'));
    await reload();
  };

  if (!societyId) return null;

  return (
    <div className="card-section mb-4">
      <h2 className="text-sm font-semibold mb-1 flex items-center gap-1.5">
        <MapPin className="w-4 h-4 text-primary" />
        {t('settings.societyAddress')}
      </h2>
      <p className="text-[10px] text-muted-foreground mb-3 leading-relaxed">{t('settings.societyAddressHint')}</p>

      {loading ? (
        <p className="text-xs text-muted-foreground">…</p>
      ) : (
        <div className="space-y-3">
          {societyName ? (
            <p className="text-xs font-medium text-foreground">{societyName}</p>
          ) : null}

          <label className="block space-y-1">
            <span className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">
              {t('superadmin.address')}
            </span>
            <CapsTextarea
              className="min-h-[4.5rem] resize-y"
              rows={3}
              value={draft.address}
              onChange={(e) => setDraft((p) => ({ ...p, address: e.target.value }))}
              placeholder={t('settings.addressPlaceholder')}
              autoComplete="street-address"
            />
          </label>

          <div className="grid grid-cols-2 gap-2">
            <label className="block space-y-1">
              <span className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">
                {t('superadmin.city')}
              </span>
              <CapsInput
                value={draft.city}
                onChange={(e) => setDraft((p) => ({ ...p, city: e.target.value }))}
                placeholder={t('superadmin.city')}
                autoComplete="address-level2"
              />
            </label>
            <label className="block space-y-1">
              <span className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">
                {t('superadmin.state')}
              </span>
              <CapsInput
                value={draft.state}
                onChange={(e) => setDraft((p) => ({ ...p, state: e.target.value }))}
                placeholder={t('superadmin.state')}
                autoComplete="address-level1"
              />
            </label>
          </div>

          <label className="block space-y-1">
            <span className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">
              {t('superadmin.pincode')}
            </span>
            <CapsInput
              caps={false}
              inputMode="numeric"
              maxLength={10}
              value={draft.pincode}
              onChange={(e) => setDraft((p) => ({ ...p, pincode: e.target.value }))}
              placeholder={t('superadmin.pincode')}
              autoComplete="postal-code"
            />
          </label>

          {preview ? (
            <p className="text-[11px] text-muted-foreground leading-snug rounded-lg border border-border bg-secondary/30 px-3 py-2">
              {preview}
            </p>
          ) : (
            <p className="text-[11px] text-muted-foreground">{t('settings.societyAddressEmpty')}</p>
          )}

          <button
            type="button"
            className="btn-primary text-sm w-full"
            disabled={saving}
            onClick={() => void onSave()}
          >
            {saving ? '…' : t('settings.saveSocietyAddress')}
          </button>
        </div>
      )}
    </div>
  );
}
