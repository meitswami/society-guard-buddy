import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Crown, Building2, Users, Tag, LogOut, Plus, Trash2, Mail, Phone, User, Image, Download, AlertTriangle, Database, Shield, Pencil, X } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import BiometricSetup from '@/components/BiometricSetup';
import { trimSocietyFlatsToConfiguredRange } from '@/lib/societyFlatRangeTrim';
import { NEW_CUSTOM_ROLE_PERMISSIONS } from '@/lib/adminPermissions';

interface Props {
  superadmin: { id: string; name: string; username: string };
  onLogout: () => void;
}

type TriState = '' | 'yes' | 'no';

interface Society {
  id: string; name: string; address: string | null; city: string | null;
  state: string | null; pincode: string | null; is_active: boolean;
  logo_url: string | null; contact_person: string | null;
  contact_email: string | null; contact_phone: string | null;
  photo_urls?: string[] | null;
  total_flats?: number | null;
  total_floors?: number | null;
  block_names?: string[] | null;
  terrace_accessible?: boolean | null;
  has_basement?: boolean | null;
  basement_usable_for_residents?: boolean | null;
  flats_per_floor?: number | null;
  flat_series_start?: string | null;
  flat_series_end?: string | null;
}

interface SocietyFormState {
  name: string;
  address: string;
  city: string;
  state: string;
  pincode: string;
  contact_person: string;
  contact_email: string;
  contact_phone: string;
  logo_url: string;
  total_flats: string;
  total_floors: string;
  blocks_csv: string;
  terrace: TriState;
  basement: TriState;
  basement_usable: TriState;
  flats_per_floor: string;
  flat_series_from: string;
  flat_series_to: string;
  existingPhotoUrls: string[];
}

const MAX_SOCIETY_PHOTOS = 12;
const MAX_SOCIETY_PHOTO_BYTES = 8 * 1024 * 1024;

function emptySocietyForm(): SocietyFormState {
  return {
    name: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    contact_person: '',
    contact_email: '',
    contact_phone: '',
    logo_url: '',
    total_flats: '',
    total_floors: '',
    blocks_csv: '',
    terrace: '',
    basement: '',
    basement_usable: '',
    flats_per_floor: '',
    flat_series_from: '',
    flat_series_to: '',
    existingPhotoUrls: [],
  };
}

function boolToTri(v: boolean | null | undefined): TriState {
  if (v === null || v === undefined) return '';
  return v ? 'yes' : 'no';
}

function societyToForm(s: Society): SocietyFormState {
  return {
    name: s.name,
    address: s.address ?? '',
    city: s.city ?? '',
    state: s.state ?? '',
    pincode: s.pincode ?? '',
    contact_person: s.contact_person ?? '',
    contact_email: s.contact_email ?? '',
    contact_phone: s.contact_phone ?? '',
    logo_url: s.logo_url ?? '',
    total_flats: s.total_flats != null ? String(s.total_flats) : '',
    total_floors: s.total_floors != null ? String(s.total_floors) : '',
    blocks_csv: (s.block_names ?? []).join(', '),
    terrace: boolToTri(s.terrace_accessible),
    basement: boolToTri(s.has_basement),
    basement_usable: boolToTri(s.basement_usable_for_residents),
    flats_per_floor: s.flats_per_floor != null ? String(s.flats_per_floor) : '',
    flat_series_from: s.flat_series_start ?? '',
    flat_series_to: s.flat_series_end ?? '',
    existingPhotoUrls: [...(s.photo_urls ?? [])],
  };
}

async function uploadSocietyPhotos(societyId: string, files: File[]): Promise<string[]> {
  const urls: string[] = [];
  for (const file of files) {
    if (!file.type.startsWith('image/')) {
      toast.error(`Not an image: ${file.name}`);
      continue;
    }
    if (file.size > MAX_SOCIETY_PHOTO_BYTES) {
      toast.error(`Image too large (max 8 MB): ${file.name}`);
      continue;
    }
    const safe = file.name.replace(/[^\w.-]/g, '_');
    const path = `${societyId}/${crypto.randomUUID()}_${safe}`;
    const { error } = await supabase.storage.from('society-photos').upload(path, file, {
      cacheControl: '3600',
      upsert: false,
    });
    if (error) {
      toast.error(`Upload failed: ${file.name}`);
      continue;
    }
    const { data } = supabase.storage.from('society-photos').getPublicUrl(path);
    urls.push(data.publicUrl);
  }
  return urls;
}
interface SocietyRole {
  id: string;
  society_id: string;
  role_name: string;
  slug?: string | null;
  permissions?: unknown;
}
interface Admin {
  id: string; name: string; admin_id: string; password: string;
  society_id: string | null; role_id: string | null; email: string | null;
}

type Tab = 'societies' | 'admins' | 'roles' | 'maintenance' | 'settings';

const SuperadminDashboard = ({ superadmin, onLogout }: Props) => {
  const { t } = useLanguage();
  const { clearAllData } = useStore();
  const [tab, setTab] = useState<Tab>('societies');
  const [societies, setSocieties] = useState<Society[]>([]);
  const [roles, setRoles] = useState<SocietyRole[]>([]);
  const [admins, setAdmins] = useState<Admin[]>([]);
  const [selectedSociety, setSelectedSociety] = useState<string>('');
  const [exporting, setExporting] = useState(false);

  const [showSocietyForm, setShowSocietyForm] = useState(false);
  const [editingSocietyId, setEditingSocietyId] = useState<string | null>(null);
  const [sf, setSf] = useState<SocietyFormState>(() => emptySocietyForm());
  const [pendingPhotoFiles, setPendingPhotoFiles] = useState<File[]>([]);
  const [societySaving, setSocietySaving] = useState(false);

  const [newRole, setNewRole] = useState('');

  const [showAdminForm, setShowAdminForm] = useState(false);
  const [af, setAf] = useState({ name: '', admin_id: '', password: '', society_id: '', role_id: '', email: '' });
  const [recoveryEmail, setRecoveryEmail] = useState('');
  const [recoverySaving, setRecoverySaving] = useState(false);

  useEffect(() => { loadAll(); }, []);

  useEffect(() => {
    if (tab !== 'settings') return;
    void supabase
      .from('super_admins')
      .select('recovery_email')
      .eq('id', superadmin.id)
      .maybeSingle()
      .then(({ data }) => setRecoveryEmail(data?.recovery_email?.trim() ?? ''));
  }, [tab, superadmin.id]);

  const loadAll = async () => {
    const [s, r, a] = await Promise.all([
      supabase.from('societies').select('*').order('name'),
      supabase.from('society_roles').select('*').order('role_name'),
      supabase.from('admins').select('*').order('name'),
    ]);
    if (s.data) setSocieties(s.data as Society[]);
    if (r.data) setRoles(r.data as SocietyRole[]);
    if (a.data) setAdmins(a.data as Admin[]);
    if (s.data && s.data.length > 0 && !selectedSociety) setSelectedSociety(s.data[0].id);
  };

  const closeSocietyForm = () => {
    setShowSocietyForm(false);
    setEditingSocietyId(null);
    setSf(emptySocietyForm());
    setPendingPhotoFiles([]);
  };

  const openNewSocietyForm = () => {
    setEditingSocietyId(null);
    setSf(emptySocietyForm());
    setPendingPhotoFiles([]);
    setShowSocietyForm(true);
  };

  const openEditSociety = (s: Society) => {
    setEditingSocietyId(s.id);
    setSf(societyToForm(s));
    setPendingPhotoFiles([]);
    setShowSocietyForm(true);
  };

  const triToBool = (v: TriState): boolean | null => (v === '' ? null : v === 'yes');

  const saveSociety = async () => {
    if (!sf.name.trim()) return;
    const blockParts = sf.blocks_csv.split(/[,;]+/).map((x) => x.trim()).filter(Boolean);
    const block_names = blockParts.length ? blockParts : null;

    const parseIntOrNull = (v: string) => {
      const trimmed = v.trim();
      if (!trimmed) return null;
      const n = parseInt(trimmed, 10);
      return Number.isFinite(n) ? n : null;
    };

    const hasBasement = sf.basement === 'yes';
    const baseRow = {
      name: sf.name.trim(),
      address: sf.address.trim() || null,
      city: sf.city.trim() || null,
      state: sf.state.trim() || null,
      pincode: sf.pincode.trim() || null,
      contact_person: sf.contact_person.trim() || null,
      contact_email: sf.contact_email.trim() || null,
      contact_phone: sf.contact_phone.trim() || null,
      logo_url: sf.logo_url.trim() || null,
      total_flats: parseIntOrNull(sf.total_flats),
      total_floors: parseIntOrNull(sf.total_floors),
      block_names,
      terrace_accessible: triToBool(sf.terrace),
      has_basement: triToBool(sf.basement),
      basement_usable_for_residents: hasBasement ? triToBool(sf.basement_usable) : null,
      flats_per_floor: parseIntOrNull(sf.flats_per_floor),
      flat_series_start: sf.flat_series_from.trim() || null,
      flat_series_end: sf.flat_series_to.trim() || null,
    };

    const totalPhotoCount = sf.existingPhotoUrls.length + pendingPhotoFiles.length;
    if (totalPhotoCount > MAX_SOCIETY_PHOTOS) {
      toast.error(t('superadmin.societyPhotosLimit'));
      return;
    }

    setSocietySaving(true);
    try {
      let societyIdForTrim: string;

      if (editingSocietyId) {
        societyIdForTrim = editingSocietyId;
        let photo_urls = [...sf.existingPhotoUrls];
        if (pendingPhotoFiles.length) {
          const uploaded = await uploadSocietyPhotos(editingSocietyId, pendingPhotoFiles);
          photo_urls = [...photo_urls, ...uploaded];
        }
        const { error } = await supabase
          .from('societies')
          .update({ ...baseRow, photo_urls })
          .eq('id', editingSocietyId);
        if (error) throw error;
        toast.success(t('superadmin.societyUpdated'));
      } else {
        const { data, error } = await supabase
          .from('societies')
          .insert({ ...baseRow, photo_urls: [] })
          .select('id')
          .single();
        if (error) throw error;
        societyIdForTrim = data.id;
        let photo_urls = [...sf.existingPhotoUrls];
        if (pendingPhotoFiles.length) {
          const uploaded = await uploadSocietyPhotos(societyIdForTrim, pendingPhotoFiles);
          photo_urls = [...photo_urls, ...uploaded];
        }
        if (photo_urls.length) {
          const { error: uerr } = await supabase.from('societies').update({ photo_urls }).eq('id', societyIdForTrim);
          if (uerr) throw uerr;
        }
        toast.success(t('superadmin.societyAdded'));
      }

      const trimmed = await trimSocietyFlatsToConfiguredRange(supabase, societyIdForTrim, {
        total_floors: baseRow.total_floors,
        flat_series_start: baseRow.flat_series_start,
        flat_series_end: baseRow.flat_series_end,
        block_names,
      });
      if (trimmed > 0) {
        toast.info(t('superadmin.flatsTrimmed').replace('{count}', String(trimmed)));
      }

      closeSocietyForm();
      loadAll();
    } catch (e) {
      console.error(e);
      toast.error(t('superadmin.societySaveFailed'));
    }
    setSocietySaving(false);
  };

  const onPickSocietyPhotos = (files: FileList | null) => {
    if (!files?.length) return;
    const next: File[] = [...pendingPhotoFiles];
    for (let i = 0; i < files.length; i++) {
      const f = files[i];
      if (next.length + sf.existingPhotoUrls.length >= MAX_SOCIETY_PHOTOS) {
        toast.error(t('superadmin.societyPhotosLimit'));
        break;
      }
      next.push(f);
    }
    setPendingPhotoFiles(next);
  };

  const deleteSociety = async (id: string) => {
    const ok = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (!ok) return;
    await supabase.from('societies').delete().eq('id', id);
    showSuccess(t('swal.success'), 'Society deleted');
    loadAll();
  };

  const addRole = async () => {
    const name = newRole.trim();
    if (!name) {
      toast.error(t('superadmin.roleNameRequired'));
      return;
    }
    if (!selectedSociety) {
      toast.error(t('superadmin.selectSocietyFirst'));
      return;
    }
    const { error } = await supabase.from('society_roles').insert({
      society_id: selectedSociety,
      role_name: name,
      permissions: NEW_CUSTOM_ROLE_PERMISSIONS as unknown as Record<string, boolean>,
    });
    if (error) {
      if (error.code === '23505') toast.error(t('superadmin.roleDuplicate'));
      else toast.error(error.message || t('superadmin.roleAddFailed'));
      return;
    }
    setNewRole('');
    toast.success(t('superadmin.roleAdded'));
    loadAll();
  };

  const deleteRole = async (id: string) => {
    const ok = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (!ok) return;
    await supabase.from('society_roles').delete().eq('id', id);
    showSuccess(t('swal.success'), 'Role deleted');
    loadAll();
  };

  const addAdmin = async () => {
    if (!af.name || !af.admin_id || !af.password || !af.society_id) return;
    await supabase.from('admins').insert({
      name: af.name, admin_id: af.admin_id.toUpperCase(), password: af.password,
      society_id: af.society_id, role_id: af.role_id || null, email: af.email || null,
    });
    setAf({ name: '', admin_id: '', password: '', society_id: '', role_id: '', email: '' });
    setShowAdminForm(false);
    toast.success(t('superadmin.adminAdded'));
    loadAll();
  };

  const deleteAdmin = async (id: string) => {
    const ok = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (!ok) return;
    await supabase.from('admins').delete().eq('id', id);
    showSuccess(t('swal.success'), 'Admin deleted');
    loadAll();
  };

  const handleLogout = async () => {
    const ok = await confirmAction(t('swal.confirmLogout'), t('swal.confirmLogoutText'), t('swal.yes'), t('swal.no'));
    if (ok) onLogout();
  };

  const handleClearAll = async () => {
    const confirmed = await confirmAction(
      '⚠️ Clear All Data?',
      'This will permanently delete ALL visitors, flats, members, vehicles, blacklist entries, and shift logs. This cannot be undone!',
      'Yes, clear everything',
      t('swal.no')
    );
    if (confirmed) {
      await clearAllData();
      showSuccess(t('swal.success'), 'All dummy data has been cleared. Ready for production!');
    }
  };

  const handleExportBackup = async (societyId?: string) => {
    setExporting(true);
    try {
      const { data, error } = await supabase.functions.invoke('backup-export', {
        body: { society_id: societyId || null },
      });
      if (error) throw error;

      // Download the JSON
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      const socName = societies.find(s => s.id === societyId)?.name || 'AllSocieties';
      a.download = `backup_${socName.replace(/[^a-zA-Z0-9]/g, '_')}_${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success('Backup exported successfully!');
    } catch (e) {
      toast.error('Backup export failed');
      console.error(e);
    }
    setExporting(false);
  };

  const filteredRoles = roles.filter(r => r.society_id === selectedSociety);
  const filteredAdmins = selectedSociety ? admins.filter(a => a.society_id === selectedSociety) : admins;

  const tabs: { id: Tab; label: string; icon: React.ElementType }[] = [
    { id: 'societies', label: t('superadmin.societies'), icon: Building2 },
    { id: 'roles', label: t('superadmin.roles'), icon: Tag },
    { id: 'admins', label: t('superadmin.admins'), icon: Users },
    { id: 'maintenance', label: 'Maintenance', icon: Database },
    { id: 'settings', label: t('nav.settings'), icon: Crown },
  ];

  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="page-container">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 flex items-center justify-center">
              <Crown className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <h1 className="page-title">{t('superadmin.panel')}</h1>
              <p className="text-xs text-muted-foreground">{superadmin.name}</p>
            </div>
          </div>
          <button onClick={handleLogout} className="p-2 rounded-lg bg-destructive/10 text-destructive">
            <LogOut className="w-5 h-5" />
          </button>
        </div>

        {societies.length > 0 && (
          <div className="mb-4">
            <select className="input-field text-sm" value={selectedSociety}
              onChange={e => setSelectedSociety(e.target.value)}>
              {societies.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
        )}

        {tab === 'societies' && (
          <div>
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-semibold">{t('superadmin.societies')}</h2>
              <button
                type="button"
                onClick={() => (showSocietyForm ? closeSocietyForm() : openNewSocietyForm())}
                className="p-2 rounded-lg bg-primary/10 text-primary"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>
            {showSocietyForm && (
              <div className="card-section p-4 mb-4 flex flex-col gap-3">
                <p className="text-sm font-medium">
                  {editingSocietyId ? t('superadmin.editSociety') : t('superadmin.newSociety')}
                </p>
                <input className="input-field" placeholder={t('superadmin.societyName')} value={sf.name} onChange={e => setSf({ ...sf, name: e.target.value })} />
                <input className="input-field" placeholder={t('superadmin.address')} value={sf.address} onChange={e => setSf({ ...sf, address: e.target.value })} />
                <div className="grid grid-cols-2 gap-2">
                  <input className="input-field" placeholder={t('superadmin.city')} value={sf.city} onChange={e => setSf({ ...sf, city: e.target.value })} />
                  <input className="input-field" placeholder={t('superadmin.state')} value={sf.state} onChange={e => setSf({ ...sf, state: e.target.value })} />
                </div>
                <input className="input-field" placeholder={t('superadmin.pincode')} value={sf.pincode} onChange={e => setSf({ ...sf, pincode: e.target.value })} />

                <div className="border-t border-border pt-3 mt-1">
                  <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('superadmin.societyBuilding')}</p>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      className="input-field"
                      inputMode="numeric"
                      placeholder={t('superadmin.totalFlats')}
                      value={sf.total_flats}
                      onChange={e => setSf({ ...sf, total_flats: e.target.value })}
                    />
                    <input
                      className="input-field"
                      inputMode="numeric"
                      placeholder={t('superadmin.totalFloors')}
                      value={sf.total_floors}
                      onChange={e => setSf({ ...sf, total_floors: e.target.value })}
                    />
                  </div>
                  <input
                    className="input-field mt-2"
                    placeholder={t('superadmin.blocksPlaceholder')}
                    value={sf.blocks_csv}
                    onChange={e => setSf({ ...sf, blocks_csv: e.target.value })}
                  />
                  <p className="text-[10px] text-muted-foreground mt-1">{t('superadmin.blocksHint')}</p>
                  <div className="grid grid-cols-1 gap-2 mt-2">
                    <label className="text-xs text-muted-foreground flex flex-col gap-1">
                      <span>{t('superadmin.terraceAccessible')}</span>
                      <select
                        className="input-field"
                        value={sf.terrace}
                        onChange={e => setSf({ ...sf, terrace: e.target.value as TriState })}
                      >
                        <option value="">{t('superadmin.notSpecified')}</option>
                        <option value="yes">{t('swal.yes')}</option>
                        <option value="no">{t('swal.no')}</option>
                      </select>
                    </label>
                    <label className="text-xs text-muted-foreground flex flex-col gap-1">
                      <span>{t('superadmin.basement')}</span>
                      <select
                        className="input-field"
                        value={sf.basement}
                        onChange={e => setSf({ ...sf, basement: e.target.value as TriState, basement_usable: e.target.value !== 'yes' ? '' : sf.basement_usable })}
                      >
                        <option value="">{t('superadmin.notSpecified')}</option>
                        <option value="yes">{t('swal.yes')}</option>
                        <option value="no">{t('swal.no')}</option>
                      </select>
                    </label>
                    {sf.basement === 'yes' && (
                      <label className="text-xs text-muted-foreground flex flex-col gap-1">
                        <span>{t('superadmin.basementUsable')}</span>
                        <select
                          className="input-field"
                          value={sf.basement_usable}
                          onChange={e => setSf({ ...sf, basement_usable: e.target.value as TriState })}
                        >
                          <option value="">{t('superadmin.notSpecified')}</option>
                          <option value="yes">{t('swal.yes')}</option>
                          <option value="no">{t('swal.no')}</option>
                        </select>
                      </label>
                    )}
                  </div>
                </div>

                <div className="border-t border-border pt-3 mt-1">
                  <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('superadmin.flatNumbering')}</p>
                  <input
                    className="input-field"
                    inputMode="numeric"
                    placeholder={t('superadmin.flatsPerFloor')}
                    value={sf.flats_per_floor}
                    onChange={e => setSf({ ...sf, flats_per_floor: e.target.value })}
                  />
                  <div className="grid grid-cols-2 gap-2 mt-2">
                    <input
                      className="input-field"
                      placeholder={t('superadmin.flatSeriesFrom')}
                      value={sf.flat_series_from}
                      onChange={e => setSf({ ...sf, flat_series_from: e.target.value })}
                    />
                    <input
                      className="input-field"
                      placeholder={t('superadmin.flatSeriesTo')}
                      value={sf.flat_series_to}
                      onChange={e => setSf({ ...sf, flat_series_to: e.target.value })}
                    />
                  </div>
                  <p className="text-[10px] text-muted-foreground mt-1">{t('superadmin.flatSeriesHelp')}</p>
                  <p className="text-[10px] text-muted-foreground mt-1.5 border-l-2 border-primary/30 pl-2">{t('superadmin.flatTrimHint')}</p>
                </div>

                <div className="border-t border-border pt-3 mt-1">
                  <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('superadmin.societyPhotos')}</p>
                  <p className="text-[10px] text-muted-foreground mb-2">{t('superadmin.societyPhotosHint')}</p>
                  <div className="flex flex-wrap gap-2 mb-2">
                    {sf.existingPhotoUrls.map((url) => (
                      <div key={url} className="relative w-16 h-16 rounded-lg overflow-hidden border border-border shrink-0">
                        <img src={url} alt="" className="w-full h-full object-cover" />
                        <button
                          type="button"
                          className="absolute top-0.5 right-0.5 p-0.5 rounded bg-background/90 text-destructive"
                          onClick={() => setSf({ ...sf, existingPhotoUrls: sf.existingPhotoUrls.filter((u) => u !== url) })}
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </div>
                    ))}
                  </div>
                  {pendingPhotoFiles.length > 0 && (
                    <ul className="text-[10px] text-muted-foreground mb-2 space-y-0.5">
                      {pendingPhotoFiles.map((f, i) => (
                        <li key={`${f.name}-${i}`} className="flex items-center justify-between gap-2">
                          <span className="truncate">{f.name}</span>
                          <button
                            type="button"
                            className="text-destructive shrink-0"
                            onClick={() => setPendingPhotoFiles(pendingPhotoFiles.filter((_, j) => j !== i))}
                          >
                            <X className="w-3 h-3" />
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                  <label className="btn-secondary inline-flex items-center justify-center gap-2 cursor-pointer text-sm py-2 px-3">
                    <Image className="w-4 h-4" />
                    {t('superadmin.addSocietyPhotos')}
                    <input
                      type="file"
                      accept="image/*"
                      multiple
                      className="hidden"
                      onChange={(e) => {
                        onPickSocietyPhotos(e.target.files);
                        e.target.value = '';
                      }}
                    />
                  </label>
                </div>

                <div className="border-t border-border pt-3 mt-1">
                  <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('superadmin.branding')}</p>
                  <div className="flex flex-col gap-2">
                    <div className="flex items-center gap-2">
                      <User className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.contactPerson')} value={sf.contact_person} onChange={e => setSf({ ...sf, contact_person: e.target.value })} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Mail className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" type="email" placeholder={t('superadmin.contactEmail')} value={sf.contact_email} onChange={e => setSf({ ...sf, contact_email: e.target.value })} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Phone className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.contactPhone')} value={sf.contact_phone} onChange={e => setSf({ ...sf, contact_phone: e.target.value })} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Image className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.logoUrl')} value={sf.logo_url} onChange={e => setSf({ ...sf, logo_url: e.target.value })} />
                    </div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={saveSociety} disabled={societySaving} className="btn-primary flex-1">
                    {societySaving ? '…' : t('common.save')}
                  </button>
                  <button type="button" onClick={closeSocietyForm} className="btn-secondary flex-1">{t('common.cancel')}</button>
                </div>
              </div>
            )}
            {societies.map(s => {
              const photos = s.photo_urls ?? [];
              const thumb = s.logo_url || photos[0];
              return (
                <div key={s.id} className="card-section p-4 mb-2">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-start gap-3 min-w-0">
                      {thumb && <img src={thumb} alt="" className="w-10 h-10 rounded-lg object-cover shrink-0" />}
                      <div className="min-w-0">
                        <p className="font-medium">{s.name}</p>
                        <p className="text-xs text-muted-foreground">{[s.address, s.city, s.state].filter(Boolean).join(', ')}</p>
                        {s.contact_person && <p className="text-xs text-muted-foreground mt-0.5">👤 {s.contact_person} {s.contact_phone && `• ${s.contact_phone}`}</p>}
                        <div className="flex flex-wrap gap-x-2 gap-y-0.5 mt-1 text-[10px] text-muted-foreground">
                          {s.total_flats != null && <span>{t('superadmin.totalFlats')}: {s.total_flats}</span>}
                          {s.total_floors != null && <span>{t('superadmin.totalFloors')}: {s.total_floors}</span>}
                          {(s.block_names?.length ?? 0) > 0 && <span>{(s.block_names ?? []).join(', ')}</span>}
                          {s.flats_per_floor != null && s.flat_series_start && s.flat_series_end && (
                            <span className="w-full">
                              {s.flats_per_floor} {t('superadmin.flatsPerFloorShort')} · {s.flat_series_start}–{s.flat_series_end}
                            </span>
                          )}
                        </div>
                        {photos.length > 1 && (
                          <div className="flex gap-1 mt-2 overflow-x-auto pb-1">
                            {photos.slice(0, 6).map((u) => (
                              <img key={u} src={u} alt="" className="w-8 h-8 rounded object-cover shrink-0 border border-border" />
                            ))}
                            {photos.length > 6 && <span className="text-[10px] self-center text-muted-foreground">+{photos.length - 6}</span>}
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="flex shrink-0 gap-1">
                      <button type="button" onClick={() => openEditSociety(s)} className="p-2 text-primary">
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button type="button" onClick={() => deleteSociety(s.id)} className="p-2 text-destructive">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
            {societies.length === 0 && <p className="text-sm text-muted-foreground text-center py-8">{t('superadmin.noSocieties')}</p>}
          </div>
        )}

        {tab === 'roles' && (
          <div>
            <h2 className="font-semibold mb-4">{t('superadmin.roles')}</h2>
            {!selectedSociety && <p className="text-sm text-muted-foreground">{t('superadmin.selectSociety')}</p>}
            {selectedSociety && (
              <>
                <div className="flex gap-2 mb-4">
                  <input className="input-field flex-1" placeholder={t('superadmin.roleName')}
                    value={newRole} onChange={e => setNewRole(e.target.value)} />
                  <button type="button" onClick={() => void addRole()} className="btn-primary px-4">
                    {t('common.add')}
                  </button>
                </div>
                {filteredRoles.map(r => (
                  <div key={r.id} className="card-section p-3 mb-2 flex items-center justify-between">
                    <span className="text-sm font-medium">{r.role_name}</span>
                    <button onClick={() => deleteRole(r.id)} className="p-1 text-destructive"><Trash2 className="w-4 h-4" /></button>
                  </div>
                ))}
                {filteredRoles.length === 0 && <p className="text-xs text-muted-foreground text-center py-4">{t('superadmin.noRoles')}</p>}
              </>
            )}
          </div>
        )}

        {tab === 'admins' && (
          <div>
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-semibold">{t('superadmin.admins')}</h2>
              <button onClick={() => { setShowAdminForm(!showAdminForm); setAf({...af, society_id: selectedSociety}); }}
                className="p-2 rounded-lg bg-primary/10 text-primary"><Plus className="w-4 h-4" /></button>
            </div>
            {showAdminForm && (
              <div className="card-section p-4 mb-4 flex flex-col gap-3">
                <input className="input-field" placeholder={t('common.name')} value={af.name} onChange={e => setAf({...af, name: e.target.value})} />
                <input className="input-field font-mono uppercase" placeholder={t('admin.adminId')}
                  value={af.admin_id} onChange={e => setAf({...af, admin_id: e.target.value})} />
                <input className="input-field" type="email" placeholder={t('superadmin.adminEmail')} value={af.email} onChange={e => setAf({...af, email: e.target.value})} />
                <input className="input-field" placeholder={t('login.password')} value={af.password} onChange={e => setAf({...af, password: e.target.value})} />
                <select className="input-field" value={af.society_id} onChange={e => setAf({...af, society_id: e.target.value})}>
                  <option value="">{t('superadmin.selectSociety')}</option>
                  {societies.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
                <select className="input-field" value={af.role_id} onChange={e => setAf({...af, role_id: e.target.value})}>
                  <option value="">{t('superadmin.noRole')}</option>
                  {roles.filter(r => r.society_id === af.society_id).map(r => (
                    <option key={r.id} value={r.id}>{r.role_name}</option>
                  ))}
                </select>
                <div className="flex gap-2">
                  <button onClick={addAdmin} className="btn-primary flex-1">{t('common.save')}</button>
                  <button onClick={() => setShowAdminForm(false)} className="btn-secondary flex-1">{t('common.cancel')}</button>
                </div>
              </div>
            )}
            {filteredAdmins.map(a => {
              const role = roles.find(r => r.id === a.role_id);
              const society = societies.find(s => s.id === a.society_id);
              return (
                <div key={a.id} className="card-section p-4 mb-2 flex items-center justify-between">
                  <div>
                    <p className="font-medium">{a.name}</p>
                    <p className="text-xs text-muted-foreground font-mono">{a.admin_id}</p>
                    {a.email && <p className="text-xs text-muted-foreground">{a.email}</p>}
                    <div className="flex gap-2 mt-1">
                      {role && <span className="text-[10px] px-2 py-0.5 bg-primary/10 text-primary rounded-full">{role.role_name}</span>}
                      {society && <span className="text-[10px] px-2 py-0.5 bg-muted text-muted-foreground rounded-full">{society.name}</span>}
                    </div>
                  </div>
                  <button onClick={() => deleteAdmin(a.id)} className="p-2 text-destructive"><Trash2 className="w-4 h-4" /></button>
                </div>
              );
            })}
            {filteredAdmins.length === 0 && <p className="text-xs text-muted-foreground text-center py-4">{t('superadmin.noAdmins')}</p>}
          </div>
        )}

        {tab === 'maintenance' && (
          <div className="space-y-4">
            <h2 className="font-semibold flex items-center gap-2">
              <Database className="w-4 h-4 text-primary" /> Data Maintenance
            </h2>

            {/* Backup Export */}
            <div className="card-section p-4">
              <h3 className="text-sm font-semibold mb-2 flex items-center gap-1.5">
                <Download className="w-4 h-4 text-primary" /> Backup Export
              </h3>
              <p className="text-xs text-muted-foreground mb-3">
                Download a complete JSON backup of all data. Auto-backup runs every 15 days and is emailed to meit10swami@gmail.com.
              </p>
              <div className="flex flex-col gap-2">
                <button onClick={() => handleExportBackup()} disabled={exporting}
                  className="btn-primary w-full flex items-center justify-center gap-2">
                  <Download className="w-4 h-4" />
                  {exporting ? 'Exporting...' : 'Export All Societies Backup'}
                </button>
                {selectedSociety && (
                  <button onClick={() => handleExportBackup(selectedSociety)} disabled={exporting}
                    className="btn-secondary w-full flex items-center justify-center gap-2">
                    <Download className="w-4 h-4" />
                    Export {societies.find(s => s.id === selectedSociety)?.name || 'Selected'} Only
                  </button>
                )}
              </div>
              <div className="mt-3 p-2 bg-muted/50 rounded-lg">
                <p className="text-[10px] text-muted-foreground flex items-center gap-1">
                  <Shield className="w-3 h-3" />
                  Auto-backup: Every 15 days → meit10swami@gmail.com
                </p>
              </div>
            </div>

            {/* Danger Zone - Clear All Data */}
            <div className="card-section border-destructive/30 p-4">
              <h3 className="text-sm font-semibold mb-2 flex items-center gap-1.5 text-destructive">
                <AlertTriangle className="w-4 h-4" /> Danger Zone
              </h3>
              <p className="text-xs text-muted-foreground mb-4">
                Clear all dummy/test data to start fresh with real production data. This will delete all visitors, flats, members, vehicles, blacklist entries, and guard shift logs. This cannot be undone!
              </p>
              <button onClick={handleClearAll} className="w-full py-2.5 rounded-lg bg-destructive text-destructive-foreground text-sm font-medium flex items-center justify-center gap-2">
                <Trash2 className="w-4 h-4" /> Clear All Data & Go Production
              </button>
            </div>
          </div>
        )}

        {tab === 'settings' && (
          <div className="space-y-4">
            <h2 className="font-semibold">{t('nav.settings')}</h2>
            <div className="card-section p-4 space-y-3">
              <h3 className="text-sm font-semibold flex items-center gap-2">
                <Mail className="w-4 h-4 text-primary" /> {t('superadmin.recoveryEmailSettings')}
              </h3>
              <p className="text-xs text-muted-foreground">{t('superadmin.recoveryEmailStepHelp')}</p>
              <input
                type="email"
                className="input-field"
                value={recoveryEmail}
                onChange={(e) => setRecoveryEmail(e.target.value)}
                placeholder="you@example.com"
              />
              <button
                type="button"
                className="btn-primary w-full"
                disabled={recoverySaving}
                onClick={async () => {
                  const em = recoveryEmail.trim().toLowerCase();
                  if (!em || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(em)) {
                    toast.error(t('superadmin.invalidRecoveryEmail'));
                    return;
                  }
                  setRecoverySaving(true);
                  const { error } = await supabase.from('super_admins').update({ recovery_email: em }).eq('id', superadmin.id);
                  setRecoverySaving(false);
                  if (error) toast.error(t('superadmin.couldNotSaveRecovery'));
                  else toast.success(t('superadmin.recoveryEmailSaved'));
                }}
              >
                {recoverySaving ? '…' : t('superadmin.saveRecoveryEmail')}
              </button>
            </div>
            <BiometricSetup userType="superadmin" userId={superadmin.id} userName={superadmin.name} />
          </div>
        )}
      </div>

      <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
        <div className="max-w-lg mx-auto flex items-center gap-0 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-4">
          {tabs.map(t => {
            const Icon = t.icon;
            const isActive = tab === t.id;
            return (
              <button key={t.id} onClick={() => setTab(t.id)}
                className={`${isActive ? 'nav-item-active' : 'nav-item'} flex-1`}>
                <Icon className="w-4 h-4" />
                <span className="text-[10px] font-medium">{t.label}</span>
              </button>
            );
          })}
        </div>
        <p className="text-center text-[8px] text-muted-foreground pb-1">{t('app.footer')}</p>
      </nav>
    </div>
  );
};

export default SuperadminDashboard;
