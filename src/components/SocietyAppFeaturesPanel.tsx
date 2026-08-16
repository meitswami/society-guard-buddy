import { useCallback, useEffect, useState } from 'react';
import { Music2, ShieldCheck, Volume2 } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import { Switch } from '@/components/ui/switch';
import { playNotificationAlert } from '@/lib/notificationSounds';
import { sanitizeStorageFileName, uploadToNotificationMedia } from '@/lib/notificationMediaStorage';

/**
 * Admin → Settings → App features: society-level toggles that were only buried
 * in Residents / Notifications.
 */
export default function SocietyAppFeaturesPanel() {
  const societyId = useStore((s) => s.societyId);
  const { t } = useLanguage();
  const [selfIdEnabled, setSelfIdEnabled] = useState(false);
  const [selfIdSaving, setSelfIdSaving] = useState(false);
  const [soundUrl, setSoundUrl] = useState<string | null>(null);
  const [uploadingSound, setUploadingSound] = useState(false);

  const reload = useCallback(async () => {
    if (!societyId) {
      setSelfIdEnabled(false);
      setSoundUrl(null);
      return;
    }
    const { data, error } = await supabase
      .from('societies')
      .select('resident_self_id_upload_enabled, admin_push_sound_url')
      .eq('id', societyId)
      .maybeSingle();
    if (error) {
      toast.error(error.message);
      return;
    }
    setSelfIdEnabled(!!data?.resident_self_id_upload_enabled);
    setSoundUrl(data?.admin_push_sound_url?.trim() || null);
  }, [societyId]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const toggleSelfId = async (on: boolean) => {
    if (!societyId) return;
    setSelfIdSaving(true);
    const { error } = await supabase
      .from('societies')
      .update({ resident_self_id_upload_enabled: on })
      .eq('id', societyId);
    setSelfIdSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    setSelfIdEnabled(on);
    toast.success(on ? t('settings.selfIdOn') : t('settings.selfIdOff'));
  };

  const onUploadSound = async (file: File | null) => {
    if (!file || !societyId) return;
    if (!file.type.startsWith('audio/')) {
      toast.error(t('settings.signatureTuneInvalid'));
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      toast.error(t('settings.signatureTuneTooLarge'));
      return;
    }
    setUploadingSound(true);
    const safe = sanitizeStorageFileName(file.name);
    const path = `admin-sounds/${societyId}/${Date.now()}_${safe}`;
    const url = await uploadToNotificationMedia(path, file, {
      upsert: true,
      onError: (m) => toast.error(m),
    });
    if (!url) {
      setUploadingSound(false);
      return;
    }
    const { error } = await supabase.from('societies').update({ admin_push_sound_url: url }).eq('id', societyId);
    setUploadingSound(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    setSoundUrl(url);
    playNotificationAlert('custom', url);
    toast.success(t('settings.signatureTuneSaved'));
  };

  const clearSound = async () => {
    if (!societyId) return;
    const { error } = await supabase.from('societies').update({ admin_push_sound_url: null }).eq('id', societyId);
    if (error) {
      toast.error(error.message);
      return;
    }
    setSoundUrl(null);
    toast.success(t('settings.signatureTuneRemoved'));
  };

  if (!societyId) return null;

  return (
    <div className="card-section mb-4">
      <h2 className="text-sm font-semibold mb-1">{t('settings.appFeatures')}</h2>
      <p className="text-[10px] text-muted-foreground mb-3 leading-relaxed">{t('settings.appFeaturesHint')}</p>

      <div className="flex items-center justify-between gap-3 rounded-lg border border-border bg-card/50 px-3 py-2.5 mb-3">
        <div className="min-w-0 flex items-start gap-2">
          <ShieldCheck className="w-4 h-4 text-primary shrink-0 mt-0.5" />
          <div>
            <p className="text-xs font-medium">{t('settings.selfId')}</p>
            <p className="text-[10px] text-muted-foreground leading-snug">{t('settings.selfIdHint')}</p>
          </div>
        </div>
        <Switch
          checked={selfIdEnabled}
          disabled={selfIdSaving}
          onCheckedChange={(on) => void toggleSelfId(on)}
          aria-label={t('settings.selfId')}
        />
      </div>

      <div className="rounded-lg border border-border bg-card/50 px-3 py-2.5 space-y-2">
        <div className="flex items-start gap-2">
          <Music2 className="w-4 h-4 text-primary shrink-0 mt-0.5" />
          <div className="min-w-0">
            <p className="text-xs font-medium">{t('settings.signatureTune')}</p>
            <p className="text-[10px] text-muted-foreground leading-snug">{t('settings.signatureTuneHint')}</p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-border bg-background/80 px-3 py-2 text-[11px] font-medium hover:bg-muted/60">
            {uploadingSound ? t('settings.bannerUploading') : t('settings.signatureTuneUpload')}
            <input
              type="file"
              accept="audio/*"
              className="hidden"
              disabled={uploadingSound}
              onChange={(e) => {
                void onUploadSound(e.target.files?.[0] ?? null);
                e.target.value = '';
              }}
            />
          </label>
          {soundUrl && (
            <>
              <button
                type="button"
                className="btn-secondary text-[11px] py-1.5 px-2.5 inline-flex items-center gap-1"
                onClick={() => playNotificationAlert('custom', soundUrl)}
              >
                <Volume2 className="w-3.5 h-3.5" /> {t('settings.signatureTunePreview')}
              </button>
              <button type="button" className="text-[11px] text-destructive" onClick={() => void clearSound()}>
                {t('settings.signatureTuneRemove')}
              </button>
            </>
          )}
        </div>
        {soundUrl ? (
          <p className="text-[10px] text-muted-foreground break-all">{soundUrl.slice(-56)}</p>
        ) : (
          <p className="text-[10px] text-muted-foreground">{t('settings.signatureTuneEmpty')}</p>
        )}
      </div>
    </div>
  );
}
