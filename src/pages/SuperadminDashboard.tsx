import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Crown, Building2, Users, Tag, LogOut, Plus, Trash2, Mail, Phone, User, Image, Download, AlertTriangle, Database, Shield } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import BiometricSetup from '@/components/BiometricSetup';

interface Props {
  superadmin: { id: string; name: string; username: string };
  onLogout: () => void;
}

interface Society {
  id: string; name: string; address: string | null; city: string | null;
  state: string | null; pincode: string | null; is_active: boolean;
  logo_url: string | null; contact_person: string | null;
  contact_email: string | null; contact_phone: string | null;
}
interface SocietyRole { id: string; society_id: string; role_name: string; }
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
  const [sf, setSf] = useState({ name: '', address: '', city: '', state: '', pincode: '', contact_person: '', contact_email: '', contact_phone: '', logo_url: '' });

  const [newRole, setNewRole] = useState('');

  const [showAdminForm, setShowAdminForm] = useState(false);
  const [af, setAf] = useState({ name: '', admin_id: '', password: '', society_id: '', role_id: '', email: '' });

  useEffect(() => { loadAll(); }, []);

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

  const addSociety = async () => {
    if (!sf.name.trim()) return;
    await supabase.from('societies').insert({
      name: sf.name, address: sf.address || null, city: sf.city || null,
      state: sf.state || null, pincode: sf.pincode || null,
      contact_person: sf.contact_person || null, contact_email: sf.contact_email || null,
      contact_phone: sf.contact_phone || null, logo_url: sf.logo_url || null,
    });
    setSf({ name: '', address: '', city: '', state: '', pincode: '', contact_person: '', contact_email: '', contact_phone: '', logo_url: '' });
    setShowSocietyForm(false);
    toast.success(t('superadmin.societyAdded'));
    loadAll();
  };

  const deleteSociety = async (id: string) => {
    const ok = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (!ok) return;
    await supabase.from('societies').delete().eq('id', id);
    showSuccess(t('swal.success'), 'Society deleted');
    loadAll();
  };

  const addRole = async () => {
    if (!newRole.trim() || !selectedSociety) return;
    await supabase.from('society_roles').insert({ society_id: selectedSociety, role_name: newRole.trim() });
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
              <button onClick={() => setShowSocietyForm(!showSocietyForm)}
                className="p-2 rounded-lg bg-primary/10 text-primary"><Plus className="w-4 h-4" /></button>
            </div>
            {showSocietyForm && (
              <div className="card-section p-4 mb-4 flex flex-col gap-3">
                <input className="input-field" placeholder={t('superadmin.societyName')} value={sf.name} onChange={e => setSf({...sf, name: e.target.value})} />
                <input className="input-field" placeholder={t('superadmin.address')} value={sf.address} onChange={e => setSf({...sf, address: e.target.value})} />
                <div className="grid grid-cols-2 gap-2">
                  <input className="input-field" placeholder={t('superadmin.city')} value={sf.city} onChange={e => setSf({...sf, city: e.target.value})} />
                  <input className="input-field" placeholder={t('superadmin.state')} value={sf.state} onChange={e => setSf({...sf, state: e.target.value})} />
                </div>
                <input className="input-field" placeholder={t('superadmin.pincode')} value={sf.pincode} onChange={e => setSf({...sf, pincode: e.target.value})} />
                <div className="border-t border-border pt-3 mt-1">
                  <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('superadmin.branding')}</p>
                  <div className="flex flex-col gap-2">
                    <div className="flex items-center gap-2">
                      <User className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.contactPerson')} value={sf.contact_person} onChange={e => setSf({...sf, contact_person: e.target.value})} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Mail className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" type="email" placeholder={t('superadmin.contactEmail')} value={sf.contact_email} onChange={e => setSf({...sf, contact_email: e.target.value})} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Phone className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.contactPhone')} value={sf.contact_phone} onChange={e => setSf({...sf, contact_phone: e.target.value})} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Image className="w-4 h-4 text-muted-foreground shrink-0" />
                      <input className="input-field" placeholder={t('superadmin.logoUrl')} value={sf.logo_url} onChange={e => setSf({...sf, logo_url: e.target.value})} />
                    </div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button onClick={addSociety} className="btn-primary flex-1">{t('common.save')}</button>
                  <button onClick={() => setShowSocietyForm(false)} className="btn-secondary flex-1">{t('common.cancel')}</button>
                </div>
              </div>
            )}
            {societies.map(s => (
              <div key={s.id} className="card-section p-4 mb-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    {s.logo_url && <img src={s.logo_url} alt="" className="w-10 h-10 rounded-lg object-cover" />}
                    <div>
                      <p className="font-medium">{s.name}</p>
                      <p className="text-xs text-muted-foreground">{[s.address, s.city, s.state].filter(Boolean).join(', ')}</p>
                      {s.contact_person && <p className="text-xs text-muted-foreground mt-0.5">👤 {s.contact_person} {s.contact_phone && `• ${s.contact_phone}`}</p>}
                    </div>
                  </div>
                  <button onClick={() => deleteSociety(s.id)} className="p-2 text-destructive"><Trash2 className="w-4 h-4" /></button>
                </div>
              </div>
            ))}
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
                  <button onClick={addRole} className="btn-primary px-4">{t('common.add')}</button>
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
