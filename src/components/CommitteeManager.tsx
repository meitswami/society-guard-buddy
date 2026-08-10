import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Camera, Edit2, Plus, Trash2, UserCircle, Phone, Users, Search } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import {
  type CommitteeMemberRow,
  type CommitteeSelectionType,
  COMMITTEE_SELECTION_OPTIONS,
  committeeDisplayLabels,
  committeeIsRepresentative,
  committeeTenureLabel,
  filterEffectiveCommitteeMembers,
  selectionTypeLabel,
} from '@/lib/committeeMember';
import CommitteeDutiesChart from '@/components/CommitteeDutiesChart';

const POSITION_PRESETS = [
  'President',
  'Vice-President',
  'Secretary',
  'Treasurer',
  'Cultural Secretary',
  'Committee Member',
] as const;

type FlatOption = {
  id: string;
  flat_number: string;
  owner_name: string | null;
  primary_member_name: string;
  primary_member_photo: string | null;
};

type FormState = {
  flatId: string;
  flatNumber: string;
  flatOwnerName: string;
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
  termFrom: string;
  termTo: string;
  selectionType: CommitteeSelectionType | '';
};

const emptyForm = (): FormState => ({
  flatId: '',
  flatNumber: '',
  flatOwnerName: '',
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
  termFrom: '',
  termTo: '',
  selectionType: '',
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
  const [rows, setRows] = useState<CommitteeMemberRow[]>([]);
  const [flatOptions, setFlatOptions] = useState<FlatOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm());
  const [flatSearch, setFlatSearch] = useState('');

  const loadFlats = useCallback(async () => {
    if (!societyId) {
      setFlatOptions([]);
      return;
    }
    const { data: flats } = await supabase
      .from('flats')
      .select('id, flat_number, owner_name')
      .eq('society_id', societyId)
      .order('flat_number');
    const flatIds = (flats ?? []).map((f) => f.id);
    const { data: primaries } =
      flatIds.length > 0
        ? await supabase.from('members').select('flat_id, name, photo').eq('is_primary', true).in('flat_id', flatIds)
        : { data: [] as { flat_id: string; name: string; photo: string | null }[] };
    const primaryByFlatId = new Map<string, { name: string; photo: string | null }>();
    for (const row of primaries ?? []) {
      if (row.flat_id && row.name?.trim()) {
        primaryByFlatId.set(row.flat_id, {
          name: row.name.trim(),
          photo: typeof row.photo === 'string' && row.photo.trim() ? row.photo.trim() : null,
        });
      }
    }
    setFlatOptions(
      (flats ?? []).map((f) => {
        const primary = primaryByFlatId.get(f.id);
        return {
          id: f.id,
          flat_number: f.flat_number,
          owner_name: f.owner_name,
          primary_member_name: primary?.name ?? f.owner_name?.trim() ?? '',
          primary_member_photo: primary?.photo ?? null,
        };
      }),
    );
  }, [societyId]);

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

    const roster = filterEffectiveCommitteeMembers((data as CommitteeMemberRow[]) ?? []);
    const flatIds = [...new Set(roster.map((r) => r.flat_id).filter(Boolean))] as string[];
    if (flatIds.length > 0) {
      const { data: mems } = await supabase
        .from('members')
        .select('flat_id, name, photo')
        .in('flat_id', flatIds);
      const live = new Map<string, string>();
      for (const m of mems ?? []) {
        const photo = typeof m.photo === 'string' ? m.photo.trim() : '';
        const name = typeof m.name === 'string' ? m.name.trim() : '';
        if (m.flat_id && name && photo) live.set(`${m.flat_id}|${name}`, photo);
      }
      for (const row of roster) {
        if (!row.flat_id || !row.name) continue;
        const hit = live.get(`${row.flat_id}|${row.name.trim()}`);
        if (hit) row.photo = hit;
      }
    }

    setRows(roster);
    setLoading(false);
  }, [societyId]);

  useEffect(() => {
    void loadFlats();
    void load();
  }, [loadFlats, load]);

  const filteredFlatOptions = useMemo(() => {
    const q = flatSearch.trim().toLowerCase();
    if (!q) return flatOptions;
    return flatOptions.filter(
      (f) =>
        f.flat_number.toLowerCase().includes(q) ||
        f.primary_member_name.toLowerCase().includes(q) ||
        (f.owner_name ?? '').toLowerCase().includes(q),
    );
  }, [flatOptions, flatSearch]);

  const applyFlatSelection = (flatId: string) => {
    const flat = flatOptions.find((f) => f.id === flatId);
    if (!flat) {
      setForm((prev) => ({ ...prev, flatId: '', flatNumber: '', flatOwnerName: '' }));
      return;
    }
    const ownerName = flat.primary_member_name || flat.owner_name?.trim() || '';
    setForm((prev) => ({
      ...prev,
      flatId: flat.id,
      flatNumber: flat.flat_number,
      flatOwnerName: ownerName,
      name: prev.name.trim() ? prev.name : ownerName,
      photo: prev.photo.trim() ? prev.photo : flat.primary_member_photo || '',
    }));
  };

  const openAdd = () => {
    setEditingId(null);
    setFlatSearch('');
    setForm({ ...emptyForm(), sortOrder: rows.length });
    setShowForm(true);
  };

  const openEdit = (row: CommitteeMemberRow) => {
    setEditingId(row.id);
    setFlatSearch('');
    setForm({
      flatId: row.flat_id ?? '',
      flatNumber: row.flat_number ?? '',
      flatOwnerName: row.flat_owner_name ?? '',
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
      termFrom: row.term_from?.slice(0, 10) ?? '',
      termTo: row.term_to?.slice(0, 10) ?? '',
      selectionType: row.selection_type ?? '',
    });
    setShowForm(true);
  };

  const save = async () => {
    if (!societyId || !form.position.trim()) {
      toast.error('Position is required');
      return;
    }
    if (!form.flatId || !form.flatNumber.trim()) {
      toast.error('Select a flat number');
      return;
    }
    if (!form.name.trim()) {
      toast.error('Name for this post is required');
      return;
    }
    if (!form.termFrom) {
      toast.error('Tenure start date (From) is required');
      return;
    }
    if (!form.selectionType) {
      toast.error('Select how the member was chosen');
      return;
    }
    if (form.termTo && form.termTo < form.termFrom) {
      toast.error('Tenure end date must be on or after start date');
      return;
    }

    const isRep = committeeIsRepresentative({
      name: form.name,
      flat_owner_name: form.flatOwnerName,
    });
    const isFemale = form.gender === 'female';
    const showFemaleRep = isFemale && form.showRepresentative;

    const payload = {
      society_id: societyId,
      flat_id: form.flatId,
      flat_number: form.flatNumber.trim(),
      flat_owner_name: form.flatOwnerName.trim() || null,
      name: form.name.trim(),
      position: form.position.trim(),
      phone: form.phone.trim() || null,
      gender: form.gender || null,
      photo: form.photo || null,
      show_representative: isRep || showFemaleRep,
      rep_name: showFemaleRep ? form.repName.trim() || null : isRep ? form.name.trim() : null,
      rep_phone: showFemaleRep ? form.repPhone.trim() || null : null,
      rep_photo: showFemaleRep ? form.repPhoto || null : null,
      sort_order: form.sortOrder,
      term_from: form.termFrom,
      term_to: form.termTo.trim() || null,
      selection_type: form.selectionType,
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

  const remove = async (row: CommitteeMemberRow) => {
    const ok = await confirmAction('Remove member?', `${row.name} will be removed from the committee list.`, 'Remove', 'Cancel');
    if (!ok) return;
    const { error } = await supabase.from('committee_members').update({ is_active: false }).eq('id', row.id);
    if (error) return toast.error(error.message);
    toast.success('Removed');
    void load();
  };

  const renderMemberCard = (row: CommitteeMemberRow) => {
    const { primaryName, subtitle, isRepresentative } = committeeDisplayLabels(row);
    const tenure = committeeTenureLabel(row);
    const isFemale = row.gender === 'female';
    const showFemaleRep = isFemale && row.show_representative && row.rep_name;

    return (
      <div key={row.id} className="card-section">
        <div className="flex items-start gap-3">
          <Avatar photo={row.photo} name={primaryName} size="lg" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-foreground">{primaryName}</p>
            <p className="text-xs text-primary font-medium">{row.position}</p>
            {subtitle && <p className="text-[10px] text-muted-foreground mt-0.5">{subtitle}</p>}
            {row.selection_type && (
              <span className="inline-block mt-1 text-[9px] uppercase tracking-wide px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                {selectionTypeLabel(row.selection_type)}
              </span>
            )}
            {tenure && (
              <p className="text-[10px] text-muted-foreground mt-1">
                Tenure: {fmtIsoDateToDisplay(row.term_from!.slice(0, 10))}
                {' → '}
                {row.term_to ? fmtIsoDateToDisplay(row.term_to.slice(0, 10)) : 'Until retirement'}
              </p>
            )}
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

        {isRepresentative && !showFemaleRep && (
          <div className="mt-3 pt-3 border-t border-border">
            <p className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-1 flex items-center gap-1">
              <Users className="w-3 h-3" /> Representative for this post
            </p>
            <p className="text-xs text-muted-foreground">
              Flat owner: <span className="text-foreground font-medium">{row.flat_owner_name}</span>
            </p>
          </div>
        )}

        {showFemaleRep && (
          <div className="mt-3 pt-3 border-t border-border">
            <p className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-2 flex items-center gap-1">
              <Users className="w-3 h-3" /> Representative contact
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

  const nameDiffersFromOwner = committeeIsRepresentative({
    name: form.name,
    flat_owner_name: form.flatOwnerName,
  });

  return (
    <div className={isResident ? 'flex flex-col gap-3' : 'page-container'}>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className={isResident ? 'text-sm font-semibold' : 'page-title'}>
            {isResident ? 'Managing Committee' : 'Committee Members'}
          </h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {isResident
              ? 'Office-bearers and committee members of your society. Roster changes are admin-only; you may edit your personal profile details elsewhere.'
              : 'Flat-linked roster with tenure and elected / nominated status'}
          </p>
        </div>
        {!isResident && (
          <button type="button" onClick={openAdd} className="btn-primary flex items-center gap-1.5 text-sm">
            <Plus className="w-4 h-4" /> Add
          </button>
        )}
      </div>

      <CommitteeDutiesChart isResident={isResident} />

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
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Flat no. *</label>
                  <div className="relative mt-1">
                    <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                    <input
                      className="input-field pl-9"
                      type="search"
                      placeholder="Search flat or owner name…"
                      value={flatSearch}
                      onChange={(e) => setFlatSearch(e.target.value)}
                    />
                  </div>
                  <select
                    className="input-field mt-2"
                    value={form.flatId}
                    onChange={(e) => applyFlatSelection(e.target.value)}
                  >
                    <option value="">Select flat…</option>
                    {filteredFlatOptions.map((f) => (
                      <option key={f.id} value={f.id}>
                        {f.flat_number}
                        {f.primary_member_name ? ` — ${f.primary_member_name}` : ''}
                      </option>
                    ))}
                  </select>
                </div>

                {form.flatOwnerName && (
                  <div className="col-span-2 rounded-lg border border-border bg-muted/20 px-3 py-2 flex items-center gap-2.5">
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center font-bold text-primary flex-shrink-0 overflow-hidden border border-border">
                      {form.photo ? (
                        <img src={form.photo} alt="" className="w-full h-full object-cover" />
                      ) : (
                        form.flatOwnerName.charAt(0).toUpperCase()
                      )}
                    </div>
                    <div className="min-w-0">
                      <p className="text-[10px] font-medium text-muted-foreground uppercase">Flat owner (from Members)</p>
                      <p className="text-sm font-medium">{form.flatOwnerName}</p>
                      {form.flatNumber && <p className="text-[10px] text-muted-foreground">Flat {form.flatNumber}</p>}
                    </div>
                  </div>
                )}

                <div className="col-span-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Name for this post *</label>
                  <input
                    className="input-field mt-1"
                    placeholder="Defaults to flat owner; change if a representative holds the post"
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                  />
                  {nameDiffersFromOwner && (
                    <p className="text-[10px] text-primary mt-1">
                      Representative name will be shown (owner: {form.flatOwnerName})
                    </p>
                  )}
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

                <div className="col-span-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    How selected *
                  </label>
                  <div className="flex flex-wrap gap-3 mt-2">
                    {COMMITTEE_SELECTION_OPTIONS.map((opt) => (
                      <label key={opt.value} className="flex items-center gap-2 text-sm cursor-pointer">
                        <input
                          type="radio"
                          name="selection-type"
                          checked={form.selectionType === opt.value}
                          onChange={() => setForm({ ...form, selectionType: opt.value })}
                        />
                        {opt.label}
                      </label>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Tenure from *</label>
                  <DateInput className="input-field mt-1" value={form.termFrom} onChange={(e) => setForm({ ...form, termFrom: e.target.value })} />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Tenure to</label>
                  <DateInput className="input-field mt-1" value={form.termTo} onChange={(e) => setForm({ ...form, termTo: e.target.value })} />
                  <p className="text-[10px] text-muted-foreground mt-1">Leave blank until retirement</p>
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
                    Add separate representative contact (photo & mobile) for residents
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
