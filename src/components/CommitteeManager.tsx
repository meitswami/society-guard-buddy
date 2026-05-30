import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Camera, Edit2, Plus, Trash2, UserCircle, Phone, Users } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';

const POSITION_PRESETS = [
  'President',
  'Vice-President',
  'Secretary',
  'Treasurer',
  'Committee Member',
] as const;

type CommitteeRow = {
  id: string;
  society_id: string;
  name: string;
  position: string;
  phone: string | null;
  gender: string | null;
  photo: string | null;
  show_representative: boolean;
  rep_name: string | null;
  rep_phone: string | null;
  rep_photo: string | null;
  sort_order: number;
  is_active: boolean;
};

type FormState = {
  name: string;
  position: string;
  phone: string;
  gender: string;
  photo: string;
  showRepresentative: boolean;
  repName: string;
  repPhone: string;
  repPhoto: string;
  sortOrder: number;
};

const emptyForm = (): FormState => ({
  name: '',
  position: 'Committee Member',
  phone: '',
  gender: '',
  photo: '',
  showRepresentative: false,
  repName: '',
  repPhone: '',
  repPhoto: '',
  sortOrder: 0,
});

interface Props {
  isResident?: boolean;
}

const pickImage = (onPick: (dataUrl: string) => void) => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onloadend = () => onPick(String(reader.result ?? ''));
    reader.readAsDataURL(file);
  };
  input.click();
};

const Avatar = ({ photo, name, size = 'md' }: { photo?: string | null; name: string; size?: 'sm' | 'md' | 'lg' }) => {
  const cls =
    size === 'lg'
      ? 'w-16 h-16 text-lg'
      : size === 'sm'
        ? 'w-9 h-9 text-[10px]'
        : 'w-12 h-12 text-sm';
  return (
    <div className={`${cls} rounded-full bg-primary/10 flex items-center justify-center font-bold text-primary flex-shrink-0 overflow-hidden border border-border`}>
      {photo ? <img src={photo} alt="" className="w-full h-full object-cover" /> : name.charAt(0).toUpperCase()}
    </div>
  );
};

const CommitteeManager = ({ isResident = false }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [rows, setRows] = useState<CommitteeRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm());

  const load = useCallback(async () => {
    if (!societyId) {
      setRows([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from('committee_members')
      .select('*')
      .eq('society_id', societyId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });
    if (error) toast.error(error.message);
    setRows((data as CommitteeRow[]) ?? []);
    setLoading(false);
  }, [societyId]);

  useEffect(() => {
    void load();
  }, [load]);

  const openAdd = () => {
    setEditingId(null);
    setForm({ ...emptyForm(), sortOrder: rows.length });
    setShowForm(true);
  };

  const openEdit = (row: CommitteeRow) => {
    setEditingId(row.id);
    setForm({
      name: row.name,
      position: row.position,
      phone: row.phone ?? '',
      gender: row.gender ?? '',
      photo: row.photo ?? '',
      showRepresentative: row.show_representative,
      repName: row.rep_name ?? '',
      repPhone: row.rep_phone ?? '',
      repPhoto: row.rep_photo ?? '',
      sortOrder: row.sort_order,
    });
    setShowForm(true);
  };

  const save = async () => {
    if (!societyId || !form.name.trim() || !form.position.trim()) {
      toast.error('Name and position are required');
      return;
    }
    const isFemale = form.gender === 'female';
    const payload = {
      society_id: societyId,
      name: form.name.trim(),
      position: form.position.trim(),
      phone: form.phone.trim() || null,
      gender: form.gender || null,
      photo: form.photo || null,
      show_representative: isFemale && form.showRepresentative,
      rep_name: isFemale && form.showRepresentative ? form.repName.trim() || null : null,
      rep_phone: isFemale && form.showRepresentative ? form.repPhone.trim() || null : null,
      rep_photo: isFemale && form.showRepresentative ? form.repPhoto || null : null,
      sort_order: form.sortOrder,
      is_active: true,
    };

    if (editingId) {
      const { error } = await supabase.from('committee_members').update(payload).eq('id', editingId);
      if (error) return toast.error(error.message);
      toast.success('Committee member updated');
    } else {
      const { error } = await supabase.from('committee_members').insert([payload]);
      if (error) return toast.error(error.message);
      toast.success('Committee member added');
    }
    setShowForm(false);
    setEditingId(null);
    setForm(emptyForm());
    void load();
  };

  const remove = async (row: CommitteeRow) => {
    const ok = await confirmAction('Remove member?', `${row.name} will be removed from the committee list.`, 'Remove', 'Cancel');
    if (!ok) return;
    const { error } = await supabase.from('committee_members').update({ is_active: false }).eq('id', row.id);
    if (error) return toast.error(error.message);
    toast.success('Removed');
    void load();
  };

  const renderMemberCard = (row: CommitteeRow) => {
    const isFemale = row.gender === 'female';
    const showRep = isFemale && row.show_representative;

    return (
      <div key={row.id} className="card-section">
        <div className="flex items-start gap-3">
          <Avatar photo={row.photo} name={row.name} size="lg" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-foreground">{row.name}</p>
            <p className="text-xs text-primary font-medium">{row.position}</p>
            {row.phone && (
              <a href={`tel:${row.phone}`} className="inline-flex items-center gap-1 text-xs text-muted-foreground mt-1 hover:text-foreground">
                <Phone className="w-3 h-3" />
                <span className="font-mono">{row.phone}</span>
              </a>
            )}
          </div>
          {!isResident && (
            <div className="flex gap-1 flex-shrink-0">
              <button type="button" onClick={() => openEdit(row)} className="p-2 rounded-lg bg-secondary text-secondary-foreground" aria-label="Edit">
                <Edit2 className="w-3.5 h-3.5" />
              </button>
              <button type="button" onClick={() => void remove(row)} className="p-2 rounded-lg bg-destructive/10 text-destructive" aria-label="Remove">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </div>
          )}
        </div>

        {showRep && (
          <div className="mt-3 pt-3 border-t border-border">
            <p className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-2 flex items-center gap-1">
              <Users className="w-3 h-3" /> Representative
            </p>
            <div className="flex items-center gap-2 bg-secondary/50 rounded-lg px-2.5 py-2">
              <Avatar photo={row.rep_photo} name={row.rep_name ?? 'R'} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-medium truncate">{row.rep_name || 'Representative'}</p>
                {row.rep_phone && (
                  <a href={`tel:${row.rep_phone}`} className="inline-flex items-center gap-1 text-[10px] text-muted-foreground hover:text-foreground">
                    <Phone className="w-2.5 h-2.5" />
                    <span className="font-mono">{row.rep_phone}</span>
                  </a>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className={isResident ? 'flex flex-col gap-3' : 'page-container'}>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className={isResident ? 'text-sm font-semibold' : 'page-title'}>
            {isResident ? 'Managing Committee' : 'Committee Members'}
          </h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {isResident
              ? 'Office-bearers and committee members of your society'
              : 'Manage the society managing committee roster visible to all residents'}
          </p>
        </div>
        {!isResident && (
          <button type="button" onClick={openAdd} className="btn-primary flex items-center gap-1.5 text-sm">
            <Plus className="w-4 h-4" /> Add
          </button>
        )}
      </div>

      {loading ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : rows.length === 0 ? (
        <div className="card-section text-center py-8">
          <UserCircle className="w-10 h-10 text-muted-foreground mx-auto mb-2 opacity-50" />
          <p className="text-sm text-muted-foreground">
            {isResident ? 'No committee members listed yet.' : 'Add committee members to show them in the residents portal.'}
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">{rows.map(renderMemberCard)}</div>
      )}

      {!isResident && showForm && (
        <div className="fixed inset-0 z-[80] bg-black/50 flex items-end sm:items-center justify-center p-4">
          <div className="w-full max-w-lg bg-card border border-border rounded-2xl shadow-xl max-h-[90vh] overflow-y-auto">
            <div className="p-4 border-b border-border">
              <h3 className="font-semibold">{editingId ? 'Edit committee member' : 'Add committee member'}</h3>
            </div>
            <div className="p-4 space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div className="col-span-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Name *</label>
                  <input className="input-field mt-1" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </div>
                <div className="col-span-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Position *</label>
                  <select className="input-field mt-1" value={form.position} onChange={(e) => setForm({ ...form, position: e.target.value })}>
                    {POSITION_PRESETS.map((p) => (
                      <option key={p} value={p}>{p}</option>
                    ))}
                  </select>
                  <input
                    className="input-field mt-2 text-xs"
                    placeholder="Or type custom position"
                    value={POSITION_PRESETS.includes(form.position as typeof POSITION_PRESETS[number]) ? '' : form.position}
                    onChange={(e) => setForm({ ...form, position: e.target.value || form.position })}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Mobile</label>
                  <input className="input-field mt-1 font-mono" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Gender</label>
                  <select className="input-field mt-1" value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value, showRepresentative: e.target.value === 'female' ? form.showRepresentative : false })}>
                    <option value="">—</option>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div className="col-span-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Photo</label>
                  <div className="flex items-center gap-2 mt-1">
                    <button type="button" onClick={() => pickImage((photo) => setForm({ ...form, photo }))} className="text-xs px-2 py-1 rounded-lg border border-border flex items-center gap-1">
                      <Camera className="w-3 h-3" /> Upload photo
                    </button>
                    {form.photo && (
                      <>
                        <span className="text-[10px] text-green-600">✓</span>
                        <img src={form.photo} alt="" className="h-10 w-10 rounded-full object-cover border border-border" />
                      </>
                    )}
                  </div>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Display order</label>
                  <input type="number" className="input-field mt-1" value={form.sortOrder} onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) || 0 })} />
                </div>
              </div>

              {form.gender === 'female' && (
                <div className="rounded-lg border border-border p-3 space-y-3 bg-secondary/30">
                  <label className="flex items-center gap-2 text-sm cursor-pointer">
                    <input
                      type="checkbox"
                      checked={form.showRepresentative}
                      onChange={(e) => setForm({ ...form, showRepresentative: e.target.checked })}
                      className="rounded"
                    />
                    Show representative (photo & mobile) for residents
                  </label>
                  {form.showRepresentative && (
                    <>
                      <div>
                        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Representative name</label>
                        <input className="input-field mt-1" value={form.repName} onChange={(e) => setForm({ ...form, repName: e.target.value })} />
                      </div>
                      <div>
                        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Representative mobile</label>
                        <input className="input-field mt-1 font-mono" value={form.repPhone} onChange={(e) => setForm({ ...form, repPhone: e.target.value })} />
                      </div>
                      <div>
                        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Representative photo</label>
                        <div className="flex items-center gap-2 mt-1">
                          <button type="button" onClick={() => pickImage((repPhoto) => setForm({ ...form, repPhoto }))} className="text-xs px-2 py-1 rounded-lg border border-border flex items-center gap-1">
                            <Camera className="w-3 h-3" /> Upload photo
                          </button>
                          {form.repPhoto && (
                            <>
                              <span className="text-[10px] text-green-600">✓</span>
                              <img src={form.repPhoto} alt="" className="h-10 w-10 rounded-full object-cover border border-border" />
                            </>
                          )}
                        </div>
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>
            <div className="p-4 border-t border-border flex gap-2 justify-end">
              <button type="button" className="btn-secondary" onClick={() => { setShowForm(false); setEditingId(null); }}>Cancel</button>
              <button type="button" className="btn-primary" onClick={() => void save()}>Save</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CommitteeManager;
