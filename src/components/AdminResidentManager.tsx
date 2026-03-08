import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { Plus, Trash2, Edit2, Search, Users } from 'lucide-react';
import { confirmAction } from '@/lib/swal';
import { toast } from 'sonner';

interface ResidentUser {
  id: string; name: string; phone: string; flat_id: string;
  flat_number: string; password: string;
}

const AdminResidentManager = () => {
  const { t } = useLanguage();
  const [residents, setResidents] = useState<ResidentUser[]>([]);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', phone: '', flat_number: '', password: '' });
  const [flats, setFlats] = useState<{ id: string; flat_number: string }[]>([]);

  useEffect(() => { load(); loadFlats(); }, []);

  const load = async () => {
    const { data } = await supabase.from('resident_users').select('*').order('name');
    if (data) setResidents(data);
  };

  const loadFlats = async () => {
    const { data } = await supabase.from('flats').select('id, flat_number').order('flat_number');
    if (data) setFlats(data);
  };

  const save = async () => {
    if (!form.name || !form.phone || !form.flat_number || !form.password) return;
    const flat = flats.find(f => f.flat_number === form.flat_number);
    if (!flat) { toast.error('Flat not found'); return; }

    if (editing) {
      await supabase.from('resident_users').update({
        name: form.name, phone: form.phone, flat_id: flat.id,
        flat_number: form.flat_number, password: form.password,
      }).eq('id', editing);
      toast.success(t('superadmin.updated'));
    } else {
      await supabase.from('resident_users').insert({
        name: form.name, phone: form.phone, flat_id: flat.id,
        flat_number: form.flat_number, password: form.password,
      });
      toast.success(t('superadmin.added'));
    }
    setForm({ name: '', phone: '', flat_number: '', password: '' });
    setShowForm(false); setEditing(null);
    load();
  };

  const edit = (r: ResidentUser) => {
    setForm({ name: r.name, phone: r.phone, flat_number: r.flat_number, password: r.password });
    setEditing(r.id); setShowForm(true);
  };

  const remove = async (id: string) => {
    const ok = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (!ok) return;
    await supabase.from('resident_users').delete().eq('id', id);
    load();
  };

  const filtered = residents.filter(r =>
    r.name.toLowerCase().includes(search.toLowerCase()) ||
    r.phone.includes(search) || r.flat_number.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Users className="w-5 h-5 text-primary" />
          <h2 className="font-semibold">{t('admin.manageResidents')}</h2>
        </div>
        <button onClick={() => { setShowForm(!showForm); setEditing(null); setForm({ name: '', phone: '', flat_number: '', password: '' }); }}
          className="p-2 rounded-lg bg-primary/10 text-primary"><Plus className="w-4 h-4" /></button>
      </div>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder={t('common.name')} value={form.name} onChange={e => setForm({...form, name: e.target.value})} />
          <input className="input-field" placeholder={t('common.phone')} value={form.phone} onChange={e => setForm({...form, phone: e.target.value})} />
          <select className="input-field" value={form.flat_number} onChange={e => setForm({...form, flat_number: e.target.value})}>
            <option value="">{t('common.flat')}</option>
            {flats.map(f => <option key={f.id} value={f.flat_number}>{f.flat_number}</option>)}
          </select>
          <input className="input-field" placeholder={t('login.password')} value={form.password} onChange={e => setForm({...form, password: e.target.value})} />
          <div className="flex gap-2">
            <button onClick={save} className="btn-primary flex-1">{editing ? t('common.save') : t('common.add')}</button>
            <button onClick={() => { setShowForm(false); setEditing(null); }} className="btn-secondary flex-1">{t('common.cancel')}</button>
          </div>
        </div>
      )}

      <div className="relative mb-4">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('common.search')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {filtered.map(r => (
        <div key={r.id} className="card-section p-4 mb-2 flex items-center justify-between">
          <div>
            <p className="font-medium text-sm">{r.name}</p>
            <p className="text-xs text-muted-foreground">{r.phone} • {r.flat_number}</p>
          </div>
          <div className="flex gap-1">
            <button onClick={() => edit(r)} className="p-2 text-primary"><Edit2 className="w-4 h-4" /></button>
            <button onClick={() => remove(r.id)} className="p-2 text-destructive"><Trash2 className="w-4 h-4" /></button>
          </div>
        </div>
      ))}
      {filtered.length === 0 && <p className="text-sm text-muted-foreground text-center py-8">{t('admin.noResidents')}</p>}
    </div>
  );
};

export default AdminResidentManager;
