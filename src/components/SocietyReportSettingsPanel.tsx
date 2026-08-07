import { useCallback, useEffect, useState } from 'react';
import { FileImage, Trash2, Upload, AlertTriangle } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import {
  fetchSocietyLetterhead,
  type ReportPdfMode,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import { LETTERHEAD_NOT_CONFIGURED_WARNING } from '@/lib/letterheadReportEngine';

type LayoutDraft = {
  top: string;
  bottom: string;
  left: string;
  right: string;
};

async function uploadLetterheadToSocietyDocuments(
  societyId: string,
  file: File,
): Promise<{ path: string; signedUrl: string } | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `${societyId}/letterhead/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('society-documents').upload(path, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type || undefined,
  });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data, error: signErr } = await supabase.storage.from('society-documents').createSignedUrl(path, 3600);
  if (signErr || !data?.signedUrl) {
    toast.error(signErr?.message || 'Could not create letterhead URL');
    return null;
  }
  return { path, signedUrl: data.signedUrl };
}

/**
 * Admin → Settings → Report Settings: society letterhead upload + default PDF format.
 * Scoped strictly to the currently selected society.
 */
export default function SocietyReportSettingsPanel() {
  const societyId = useStore((s) => s.societyId);
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [lh, setLh] = useState<SocietyLetterhead | null>(null);
  const [defaultFormat, setDefaultFormat] = useState<ReportPdfMode>('letterhead');
  const [layout, setLayout] = useState<LayoutDraft>({
    top: '45',
    bottom: '22',
    left: '19.05',
    right: '19.05',
  });
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!societyId) {
      setLh(null);
      setPreviewUrl(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    const data = await fetchSocietyLetterhead(societyId);
    setLh(data);
    setDefaultFormat(data?.defaultReportFormat === 'plain' ? 'plain' : 'letterhead');
    setLayout({
      top: String(data?.letterheadTopMm ?? 45),
      bottom: String(data?.letterheadBottomMm ?? 22),
      left: String(data?.letterheadLeftMm ?? 19.05),
      right: String(data?.letterheadRightMm ?? 19.05),
    });
    setPreviewUrl(data?.letterheadDataUrl || data?.letterheadUrl || null);
    setLoading(false);
  }, [societyId]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const persist = async (patch: Record<string, unknown>) => {
    if (!societyId) return false;
    setSaving(true);
    const { error } = await supabase.from('societies').update(patch).eq('id', societyId);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return false;
    }
    return true;
  };

  const onUpload = async (file: File | null) => {
    if (!societyId || !file) return;
    if (!file.type.startsWith('image/')) {
      toast.error(t('settings.letterheadInvalidType'));
      return;
    }
    setSaving(true);
    const uploaded = await uploadLetterheadToSocietyDocuments(societyId, file);
    if (!uploaded) {
      setSaving(false);
      return;
    }
    // Preview immediately from the just-uploaded signed URL; DB stores only the storage path.
    setPreviewUrl(uploaded.signedUrl);
    // Remove previous private object when replacing (best-effort).
    if (lh?.letterheadStoragePath && lh.letterheadStoragePath !== uploaded.path) {
      await supabase.storage.from('society-documents').remove([lh.letterheadStoragePath]);
    }
    const ok = await persist({
      letterhead_storage_path: uploaded.path,
      letterhead_url: null,
      letterhead_mode: 'image',
      default_report_format: defaultFormat,
    });
    setSaving(false);
    if (ok) {
      toast.success(t('settings.letterheadSaved'));
      await reload();
    }
  };

  const onRemove = async () => {
    if (!societyId) return;
    setSaving(true);
    if (lh?.letterheadStoragePath) {
      await supabase.storage.from('society-documents').remove([lh.letterheadStoragePath]);
    }
    const ok = await persist({
      letterhead_storage_path: null,
      letterhead_url: null,
      letterhead_mode: 'auto',
    });
    setSaving(false);
    if (ok) {
      toast.success(t('settings.letterheadRemoved'));
      await reload();
    }
  };

  const onSaveSettings = async () => {
    const top = Number(layout.top);
    const bottom = Number(layout.bottom);
    const left = Number(layout.left);
    const right = Number(layout.right);
    const ok = await persist({
      default_report_format: defaultFormat,
      letterhead_top_mm: Number.isFinite(top) && top > 0 ? top : 45,
      letterhead_bottom_mm: Number.isFinite(bottom) && bottom > 0 ? bottom : 22,
      letterhead_left_mm: Number.isFinite(left) && left > 0 ? left : 19.05,
      letterhead_right_mm: Number.isFinite(right) && right > 0 ? right : 19.05,
      letterhead_mode: lh?.letterheadUrl || lh?.letterheadStoragePath ? 'image' : lh?.letterheadMode || 'auto',
    });
    if (ok) {
      toast.success(t('settings.reportSettingsSaved'));
      await reload();
    }
  };

  if (!societyId) return null;

  const hasLetterhead = !!(lh?.letterheadUrl || lh?.letterheadStoragePath || lh?.letterheadDataUrl);

  return (
    <div className="card-section mb-4">
      <h2 className="text-sm font-semibold mb-1">{t('settings.reportSettings')}</h2>
      <p className="text-[10px] text-muted-foreground mb-3 leading-relaxed">{t('settings.reportSettingsHint')}</p>

      {loading ? (
        <p className="text-xs text-muted-foreground">…</p>
      ) : (
        <div className="space-y-4">
          {!hasLetterhead && (
            <div className="flex items-start gap-2 rounded-lg border border-amber-500/40 bg-amber-500/10 px-3 py-2">
              <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
              <p className="text-xs text-amber-900 dark:text-amber-100">{LETTERHEAD_NOT_CONFIGURED_WARNING}</p>
            </div>
          )}

          <div>
            <p className="text-xs font-medium mb-2">{t('settings.societyLetterhead')}</p>
            {previewUrl ? (
              <div className="mb-2 rounded-lg border border-border overflow-hidden bg-secondary/20">
                <img src={previewUrl} alt="" className="w-full max-h-48 object-contain bg-white" />
              </div>
            ) : (
              <div className="mb-2 flex h-28 items-center justify-center rounded-lg border border-dashed border-border bg-secondary/20">
                <FileImage className="w-6 h-6 text-muted-foreground" />
              </div>
            )}
            <div className="flex flex-wrap gap-2">
              <label className="btn-secondary inline-flex items-center gap-1.5 text-xs py-2 px-3 cursor-pointer">
                <Upload className="w-3.5 h-3.5" />
                {hasLetterhead ? t('settings.replaceLetterhead') : t('settings.uploadLetterhead')}
                <input
                  type="file"
                  accept="image/png,image/jpeg,image/jpg,image/webp"
                  className="hidden"
                  disabled={saving}
                  onChange={(e) => {
                    const file = e.target.files?.[0] ?? null;
                    void onUpload(file);
                    e.target.value = '';
                  }}
                />
              </label>
              {hasLetterhead && (
                <button
                  type="button"
                  className="btn-secondary inline-flex items-center gap-1.5 text-xs py-2 px-3 text-destructive"
                  disabled={saving}
                  onClick={() => void onRemove()}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  {t('settings.removeLetterhead')}
                </button>
              )}
            </div>
            <p className="text-[10px] text-muted-foreground mt-1.5">{t('settings.letterheadUploadHint')}</p>
          </div>

          <div>
            <p className="text-xs font-medium mb-2">{t('settings.defaultReportFormat')}</p>
            <div className="space-y-1.5">
              <label className="flex items-center gap-2 text-xs cursor-pointer">
                <input
                  type="radio"
                  name="default_report_format"
                  checked={defaultFormat === 'letterhead'}
                  onChange={() => setDefaultFormat('letterhead')}
                />
                {t('settings.formatOfficialLetterhead')}
              </label>
              <label className="flex items-center gap-2 text-xs cursor-pointer">
                <input
                  type="radio"
                  name="default_report_format"
                  checked={defaultFormat === 'plain'}
                  onChange={() => setDefaultFormat('plain')}
                />
                {t('settings.formatPlainPdf')}
              </label>
            </div>
          </div>

          <div>
            <p className="text-xs font-medium mb-2">{t('settings.safeContentArea')}</p>
            <div className="grid grid-cols-2 gap-2">
              {(
                [
                  ['top', t('settings.layoutTop')],
                  ['bottom', t('settings.layoutBottom')],
                  ['left', t('settings.layoutLeft')],
                  ['right', t('settings.layoutRight')],
                ] as const
              ).map(([key, label]) => (
                <label key={key} className="text-[10px] text-muted-foreground space-y-1">
                  <span>{label}</span>
                  <input
                    className="input-field"
                    type="number"
                    min={8}
                    max={90}
                    step={0.5}
                    value={layout[key]}
                    onChange={(e) => setLayout((prev) => ({ ...prev, [key]: e.target.value }))}
                  />
                </label>
              ))}
            </div>
          </div>

          <button type="button" className="btn-primary text-sm w-full" disabled={saving} onClick={() => void onSaveSettings()}>
            {saving ? '…' : t('settings.saveReportSettings')}
          </button>
        </div>
      )}
    </div>
  );
}
