import { useStore } from '@/store/useStore';
import { Settings, Shield, ImagePlus, Trash2, ChevronLeft, ChevronRight } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import SocietyContentEditor from '@/components/SocietyContentEditor';
import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { ADMIN_HOME_METRICS } from '@/lib/descriptiveMetricCopy';
import SocietyReportSettingsPanel from '@/components/SocietyReportSettingsPanel';

const SettingsPage = ({ allowContentEdit = false }: { allowContentEdit?: boolean } = {}) => {
  const { visitors, flats, members, residentVehicles, blacklist, societyId, entryCapsMode, setEntryCapsMode } = useStore();
  const { t } = useLanguage();
  const [banners, setBanners] = useState<any[]>([]);
  const [adding, setAdding] = useState(false);
  const [newTitle, setNewTitle] = useState('');

  const canManageSociety = !!societyId;

  const loadBanners = async () => {
    if (!societyId) {
      setBanners([]);
      return;
    }
    const { data } = await supabase
      .from('society_dashboard_banners')
      .select('*')
      .eq('society_id', societyId)
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });
    setBanners(data || []);
  };

  useEffect(() => {
    void loadBanners();
  }, [societyId]);

  const pickBannerImage = async () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onloadend = async () => {
        const url = String(reader.result ?? '');
        if (!societyId || !url) return;
        setAdding(true);
        const maxSort = (banners || []).reduce((m, b) => Math.max(m, Number(b.sort_order || 0)), 0);
        const { error } = await supabase.from('society_dashboard_banners').insert({
          society_id: societyId,
          image_url: url,
          title: newTitle.trim() || null,
          is_active: true,
          sort_order: maxSort + 1,
        });
        setAdding(false);
        if (error) toast.error(error.message);
        else {
          toast.success(t('settings.bannerAdded'));
          setNewTitle('');
          loadBanners();
        }
      };
      reader.readAsDataURL(file);
    };
    input.click();
  };

  const removeBanner = async (id: string) => {
    if (!societyId) return;
    const { error } = await supabase.from('society_dashboard_banners').delete().eq('id', id).eq('society_id', societyId);
    if (error) toast.error(error.message);
    else {
      toast.success(t('settings.bannerRemoved'));
      loadBanners();
    }
  };

  const saveBannerTitle = async (id: string, title: string) => {
    if (!societyId) return;
    const { error } = await supabase
      .from('society_dashboard_banners')
      .update({ title: title.trim() || null })
      .eq('id', id)
      .eq('society_id', societyId);
    if (error) toast.error(error.message);
    else {
      toast.success(t('settings.bannerTitleSaved'));
      loadBanners();
    }
  };

  const toggleActive = async (id: string, on: boolean) => {
    if (!societyId) return;
    const { error } = await supabase
      .from('society_dashboard_banners')
      .update({ is_active: on })
      .eq('id', id)
      .eq('society_id', societyId);
    if (error) toast.error(error.message);
    else loadBanners();
  };

  const moveBanner = async (id: string, dir: -1 | 1) => {
    const idx = banners.findIndex((b) => b.id === id);
    if (idx < 0) return;
    const otherIdx = idx + dir;
    if (otherIdx < 0 || otherIdx >= banners.length) return;
    const a = banners[idx];
    const b = banners[otherIdx];
    await supabase.from('society_dashboard_banners').update({ sort_order: b.sort_order }).eq('id', a.id);
    await supabase.from('society_dashboard_banners').update({ sort_order: a.sort_order }).eq('id', b.id);
    loadBanners();
  };

  const activeCount = useMemo(() => banners.filter((b) => b.is_active).length, [banners]);

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Settings className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">{t('settings.title')}</h1>
          <p className="text-xs text-muted-foreground">{t('settings.subtitle')}</p>
        </div>
      </div>

      {/* Appearance */}
      <div className="card-section mb-4">
        <h2 className="text-sm font-semibold mb-3">{t('settings.appearance')}</h2>
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground">{t('settings.theme')}</span>
          <ThemeToggle />
        </div>
        <div className="flex items-center justify-between mt-3">
          <span className="text-xs text-muted-foreground">{t('settings.language')}</span>
          <LanguageToggle />
        </div>
        <div className="flex items-center justify-between mt-3">
          <div>
            <span className="text-xs text-muted-foreground">{t('settings.autoCaps')}</span>
            <p className="text-[10px] text-muted-foreground/80 mt-0.5">{t('settings.autoCapsHint')}</p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={entryCapsMode}
            onClick={() => setEntryCapsMode(!entryCapsMode)}
            className={`w-11 h-6 rounded-full transition-colors relative shrink-0 ${entryCapsMode ? 'bg-primary' : 'bg-secondary'}`}
          >
            <span
              className={`absolute top-1 w-4 h-4 rounded-full bg-foreground transition-all ${entryCapsMode ? 'left-6' : 'left-1'}`}
            />
          </button>
        </div>
      </div>

      {allowContentEdit && canManageSociety && <SocietyContentEditor />}

      {canManageSociety && <SocietyReportSettingsPanel />}

      {/* Data summary */}
      <div className="card-section mb-4">
        <h2 className="text-sm font-semibold mb-3 flex items-center gap-1.5">
          <Shield className="w-4 h-4 text-primary" /> {t('settings.dataSummary')}
        </h2>
        <div className="grid grid-cols-2 gap-2">
          <DescriptiveStatCard
            {...ADMIN_HOME_METRICS.flats}
            variant="stat"
            value={flats.length}
            className="!p-2.5"
          />
          <DescriptiveStatCard
            {...ADMIN_HOME_METRICS.members}
            variant="stat"
            value={members.length}
            className="!p-2.5"
          />
          <DescriptiveStatCard
            {...ADMIN_HOME_METRICS.vehicles}
            variant="stat"
            value={residentVehicles.length}
            className="!p-2.5"
          />
          <DescriptiveStatCard
            {...ADMIN_HOME_METRICS.visitors}
            variant="stat"
            value={visitors.length}
            className="!p-2.5"
          />
          <DescriptiveStatCard
            {...ADMIN_HOME_METRICS.blacklist}
            variant="stat"
            value={blacklist.length}
            className="!p-2.5 col-span-2"
          />
        </div>
      </div>

      {/* Admin society banner settings */}
      {canManageSociety && (
        <div className="card-section mb-4">
          <h2 className="text-sm font-semibold mb-2">{t('settings.banners')}</h2>
          <p className="text-[10px] text-muted-foreground mb-3 leading-relaxed">
            {t('settings.bannersHint')}
          </p>
          <div className="flex gap-2 items-center mb-3">
            <input
              className="input-field text-sm flex-1"
              placeholder={t('settings.bannerTitlePlaceholder')}
              value={newTitle}
              onChange={(e) => setNewTitle(e.target.value)}
            />
            <button
              type="button"
              onClick={pickBannerImage}
              disabled={adding}
              className="btn-primary text-sm flex items-center gap-2"
            >
              <ImagePlus className="w-4 h-4" /> {adding ? t('settings.bannerUploading') : t('settings.bannerAdd')}
            </button>
          </div>
          <p className="text-[10px] text-muted-foreground mb-2">
            {t('settings.bannersActiveCount', { active: activeCount, total: banners.length })}
          </p>
          {banners.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('settings.bannersEmpty')}</p>
          ) : (
            <div className="space-y-2">
              {banners.map((b) => (
                <div key={b.id} className="rounded-xl border border-border bg-secondary/30 p-2">
                  <div className="flex items-start gap-2">
                    <img src={b.image_url} alt="" className="h-14 w-24 object-cover rounded-lg border border-border bg-background" />
                    <div className="flex-1 min-w-0 space-y-1.5">
                      <input
                        className="input-field text-xs w-full py-1.5"
                        defaultValue={b.title || ''}
                        key={`${b.id}-${b.title || ''}`}
                        placeholder={t('settings.bannerTitlePlaceholder')}
                        onBlur={(e) => {
                          const next = e.target.value.trim();
                          const prev = (b.title || '').trim();
                          if (next !== prev) void saveBannerTitle(b.id, next);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            (e.target as HTMLInputElement).blur();
                          }
                        }}
                      />
                      <p className="text-[10px] text-muted-foreground">Order: {b.sort_order ?? 0}</p>
                      <div className="flex items-center gap-2 mt-1">
                        <label className="text-[10px] text-muted-foreground flex items-center gap-1">
                          <input
                            type="checkbox"
                            checked={!!b.is_active}
                            onChange={(e) => toggleActive(b.id, e.target.checked)}
                          />
                          {t('settings.bannerActive')}
                        </label>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1">
                      <button type="button" className="p-1 text-muted-foreground hover:text-foreground" onClick={() => moveBanner(b.id, -1)} title="Move up">
                        <ChevronLeft className="w-4 h-4" />
                      </button>
                      <button type="button" className="p-1 text-muted-foreground hover:text-foreground" onClick={() => moveBanner(b.id, 1)} title="Move down">
                        <ChevronRight className="w-4 h-4" />
                      </button>
                      <button type="button" className="p-1 text-muted-foreground hover:text-destructive" onClick={() => removeBanner(b.id)} title="Remove">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <p className="text-center text-[10px] text-muted-foreground mt-6">{t('app.footer')}</p>
    </div>
  );
};

export default SettingsPage;
