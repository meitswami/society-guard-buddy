import { useState } from 'react';
import { useStore } from '@/store/useStore';
import type { BlacklistEntry } from '@/types';
import { ShieldAlert, Plus, Trash2, Search, User, Car } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { confirmAction, showSuccess } from '@/lib/swal';

const BlacklistPage = () => {
  const { blacklist, addToBlacklist, removeFromBlacklist, currentGuard } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ type: 'visitor' as 'visitor' | 'vehicle', name: '', phone: '', vehicleNumber: '', reason: '' });

  const filtered = blacklist.filter(e => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (e.name && e.name.toLowerCase().includes(q)) || (e.phone && e.phone.includes(q)) ||
      (e.vehicleNumber && e.vehicleNumber.toLowerCase().includes(q)) || e.reason.toLowerCase().includes(q);
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.reason) return;
    if (form.type === 'visitor' && !form.phone) return;
    if (form.type === 'vehicle' && !form.vehicleNumber) return;
    const entry: BlacklistEntry = {
      id: `BL${Date.now()}`, type: form.type, name: form.name || undefined,
      phone: form.type === 'visitor' ? form.phone : undefined,
      vehicleNumber: form.type === 'vehicle' ? form.vehicleNumber : undefined,
      reason: form.reason, addedAt: new Date().toISOString(), addedBy: currentGuard?.name || 'Unknown',
    };
    await addToBlacklist(entry);
    setForm({ type: 'visitor', name: '', phone: '', vehicleNumber: '', reason: '' });
    setShowForm(false);
    showSuccess(t('swal.success'), t('blacklist.addedSuccess'));
  };

  const handleRemove = async (id: string) => {
    const confirmed = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (confirmed) await removeFromBlacklist(id);
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-destructive/10 flex items-center justify-center">
            <ShieldAlert className="w-5 h-5 text-destructive" />
          </div>
          <div>
            <h1 className="page-title">{t('blacklist.title')}</h1>
            <p className="text-xs text-muted-foreground">{blacklist.length} {t('blacklist.flagged')}</p>
          </div>
        </div>
        <button onClick={() => setShowForm(!showForm)} className="btn-primary text-xs px-3 py-2 flex items-center gap-1">
          <Plus className="w-3.5 h-3.5" /> {t('common.add')}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="card-section border-destructive/30 mb-4 flex flex-col gap-3">
          <div className="flex gap-2">
            <button type="button" className={`flex-1 py-2 rounded-lg text-xs font-medium transition-all ${form.type === 'visitor' ? 'bg-destructive text-destructive-foreground' : 'bg-secondary text-secondary-foreground'}`}
              onClick={() => setForm(f => ({ ...f, type: 'visitor' }))}>
              <User className="w-3.5 h-3.5 inline mr-1" /> {t('blacklist.visitor')}
            </button>
            <button type="button" className={`flex-1 py-2 rounded-lg text-xs font-medium transition-all ${form.type === 'vehicle' ? 'bg-destructive text-destructive-foreground' : 'bg-secondary text-secondary-foreground'}`}
              onClick={() => setForm(f => ({ ...f, type: 'vehicle' }))}>
              <Car className="w-3.5 h-3.5 inline mr-1" /> {t('blacklist.vehicle')}
            </button>
          </div>
          {form.type === 'visitor' && (
            <>
              <input className="input-field" placeholder={t('common.name')} value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
              <input className="input-field font-mono" placeholder={`${t('common.phone')} *`} type="tel" maxLength={10} value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value.replace(/\D/g, '') }))} />
            </>
          )}
          {form.type === 'vehicle' && (
            <input className="input-field font-mono uppercase" placeholder={`${t('visitor.vehicleNumber')} *`} value={form.vehicleNumber} onChange={e => setForm(f => ({ ...f, vehicleNumber: e.target.value.toUpperCase() }))} />
          )}
          <input className="input-field" placeholder={`${t('blacklist.reason')} *`} value={form.reason} onChange={e => setForm(f => ({ ...f, reason: e.target.value }))} />
          <div className="flex gap-2">
            <button type="submit" className="btn-primary flex-1 text-xs">{t('blacklist.addToBlacklist')}</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary flex-1 text-xs">{t('common.cancel')}</button>
          </div>
        </form>
      )}

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('blacklist.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-12">{search ? t('blacklist.noMatch') : t('blacklist.empty')}</p>
      ) : (
        <div className="flex flex-col gap-2">
          {filtered.map(e => (
            <div key={e.id} className="card-section border-destructive/20 flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-destructive/20 flex items-center justify-center flex-shrink-0">
                {e.type === 'visitor' ? <User className="w-4 h-4 text-destructive" /> : <Car className="w-4 h-4 text-destructive" />}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold truncate">{e.type === 'visitor' ? (e.name || e.phone) : e.vehicleNumber}</p>
                {e.type === 'visitor' && e.phone && <p className="text-xs font-mono text-muted-foreground">{e.phone}</p>}
                <p className="text-xs text-destructive mt-0.5">{e.reason}</p>
                <p className="text-[10px] text-muted-foreground">by {e.addedBy}</p>
              </div>
              <button onClick={() => handleRemove(e.id)} className="p-2 rounded-lg bg-secondary text-muted-foreground flex-shrink-0">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default BlacklistPage;
