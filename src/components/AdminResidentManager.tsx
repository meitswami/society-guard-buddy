import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Plus, Trash2, Edit2, Search, Users, Home, ChevronDown, ChevronUp, Car, Phone, Star, UserPlus, Key, Eye, EyeOff, RefreshCw } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import { generateFlatPassword } from '@/lib/passwordGenerator';
import type { Flat, Member, ResidentVehicle } from '@/types';

type ViewTab = 'flats' | 'addFlat';

interface ResidentUser {
  id: string; name: string; phone: string; flat_id: string; flat_number: string; password: string;
}

const AdminResidentManager = () => {
  const { t } = useLanguage();
  const { flats, members, residentVehicles, loadFlats, loadMembers, loadResidentVehicles, societyId } = useStore();
  const [search, setSearch] = useState('');
  const [expandedFlat, setExpandedFlat] = useState<string | null>(null);
  const [viewTab, setViewTab] = useState<ViewTab>('flats');
  const [residentUsers, setResidentUsers] = useState<ResidentUser[]>([]);
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});

  // Add flat form
  const [flatForm, setFlatForm] = useState({ flat_number: '', floor: '', wing: 'A', owner_name: '', owner_phone: '', intercom: '' });

  // Add member form
  const [showMemberForm, setShowMemberForm] = useState<string | null>(null);
  const [memberForm, setMemberForm] = useState({ name: '', phone: '', relation: 'family', age: '', gender: 'Male', isPrimary: false });
  const [editingMember, setEditingMember] = useState<string | null>(null);

  useEffect(() => { loadFlats(); loadMembers(); loadResidentVehicles(); loadResidentUsers(); }, []);

  const loadResidentUsers = async () => {
    const { data } = await supabase.from('resident_users').select('*');
    if (data) setResidentUsers(data as ResidentUser[]);
  };

  const filteredFlats = useMemo(() => {
    if (!search.trim()) return flats;
    const q = search.toLowerCase();
    return flats.filter(f =>
      f.flatNumber.toLowerCase().includes(q) ||
      (f.ownerName && f.ownerName.toLowerCase().includes(q)) ||
      (f.ownerPhone && f.ownerPhone.includes(q))
    );
  }, [flats, search]);

  const getMembersForFlat = (flatId: string) => members.filter(m => m.flatId === flatId);
  const getVehiclesForFlat = (flatNumber: string) => residentVehicles.filter(v => v.flatNumber === flatNumber);
  const getPrimaryMember = (flatId: string) => members.find(m => m.flatId === flatId && m.isPrimary);
  const getResidentUsersForFlat = (flatId: string) => residentUsers.filter(r => r.flat_id === flatId);
  const getFlatPassword = (flatId: string) => {
    const users = getResidentUsersForFlat(flatId);
    return users.length > 0 ? users[0].password : null;
  };

  // === ADD FLAT ===
  const saveFlat = async () => {
    if (!flatForm.flat_number) { toast.error('Flat number is required'); return; }
    const existing = flats.find(f => f.flatNumber === flatForm.flat_number);
    if (existing) { toast.error('Flat number already exists'); return; }

    await supabase.from('flats').insert({
      flat_number: flatForm.flat_number,
      floor: flatForm.floor || null,
      wing: flatForm.wing || null,
      flat_type: 'residential',
      owner_name: flatForm.owner_name || null,
      owner_phone: flatForm.owner_phone || null,
      intercom: flatForm.intercom || null,
      is_occupied: !!flatForm.owner_name,
      society_id: societyId || null,
    });

    toast.success('Flat added successfully');
    setFlatForm({ flat_number: '', floor: '', wing: 'A', owner_name: '', owner_phone: '', intercom: '' });
    setViewTab('flats');
    loadFlats();
  };

  // === SYNC RESIDENT USERS for a flat ===
  const syncResidentUsersForFlat = async (flatId: string, flatNumber: string) => {
    const flatMembers = members.filter(m => m.flatId === flatId && m.phone);
    // Re-fetch to get latest after member add
    const { data: latestMembers } = await supabase.from('members').select('*').eq('flat_id', flatId);
    const membersWithPhone = (latestMembers || []).filter((m: any) => m.phone);
    if (membersWithPhone.length === 0) return;

    // Get existing resident_users for this flat
    const { data: existingUsers } = await supabase.from('resident_users').select('*').eq('flat_id', flatId);
    const existingPhones = new Set((existingUsers || []).map((u: any) => u.phone));

    // Determine flat password - reuse existing or generate new
    let flatPassword = (existingUsers && existingUsers.length > 0) ? existingUsers[0].password : generateFlatPassword();

    // Create accounts for members with phone who don't have one yet
    const newUsers = membersWithPhone
      .filter((m: any) => !existingPhones.has(m.phone))
      .map((m: any) => ({
        name: m.name,
        phone: m.phone,
        flat_id: flatId,
        flat_number: flatNumber,
        password: flatPassword,
      }));

    if (newUsers.length > 0) {
      await supabase.from('resident_users').insert(newUsers);
      toast.success(`${newUsers.length} resident login(s) created`);
      loadResidentUsers();
    }
  };

  // === ADD/EDIT MEMBER ===
  const saveMember = async (flatId: string) => {
    if (!memberForm.name) { toast.error('Name is required'); return; }

    // If marking as primary, unset existing primary
    if (memberForm.isPrimary) {
      const existingPrimary = getPrimaryMember(flatId);
      if (existingPrimary && existingPrimary.id !== editingMember) {
        await supabase.from('members').update({ is_primary: false }).eq('id', existingPrimary.id);
      }
    }

    const payload = {
      flat_id: flatId,
      name: memberForm.name,
      phone: memberForm.phone || null,
      relation: memberForm.relation,
      age: memberForm.age ? parseInt(memberForm.age) : null,
      gender: memberForm.gender || null,
      is_primary: memberForm.isPrimary,
    };

    const flat = flats.find(f => f.id === flatId);

    if (editingMember) {
      await supabase.from('members').update(payload).eq('id', editingMember);
      // Update resident_user name if phone matches
      if (memberForm.phone) {
        await supabase.from('resident_users').update({ name: memberForm.name }).eq('phone', memberForm.phone).eq('flat_id', flatId);
      }
      showSuccess('Updated!', 'Member updated successfully');
    } else {
      const existing = getMembersForFlat(flatId);
      if (existing.length === 0) payload.is_primary = true;
      await supabase.from('members').insert(payload);
      toast.success('Member added');
    }

    // Update flat owner_name if primary
    if (payload.is_primary && flat) {
      await supabase.from('flats').update({ owner_name: payload.name, is_occupied: true }).eq('id', flatId);
    }

    resetMemberForm();
    await loadMembers();
    loadFlats();

    // Auto-create resident login if member has phone
    if (memberForm.phone && flat) {
      await syncResidentUsersForFlat(flatId, flat.flatNumber);
    }
  };

  const editMember = (m: Member) => {
    setMemberForm({
      name: m.name, phone: m.phone || '', relation: m.relation,
      age: m.age ? String(m.age) : '', gender: m.gender || 'Male', isPrimary: m.isPrimary,
    });
    setEditingMember(m.id);
    setShowMemberForm(m.flatId);
  };

  const removeMember = async (id: string) => {
    const ok = await confirmAction('Delete Member?', 'This member will be removed permanently.', 'Delete', 'Cancel');
    if (!ok) return;
    const member = members.find(m => m.id === id);
    await supabase.from('members').delete().eq('id', id);
    // Also remove resident_user if exists
    if (member?.phone) {
      await supabase.from('resident_users').delete().eq('phone', member.phone).eq('flat_id', member.flatId);
    }
    toast.success('Member removed');
    loadMembers();
    loadResidentUsers();
  };

  const resetMemberForm = () => {
    setMemberForm({ name: '', phone: '', relation: 'family', age: '', gender: 'Male', isPrimary: false });
    setShowMemberForm(null);
    setEditingMember(null);
  };

  const setPrimaryMember = async (memberId: string, flatId: string) => {
    const flatMembers = getMembersForFlat(flatId);
    for (const m of flatMembers) {
      if (m.isPrimary) await supabase.from('members').update({ is_primary: false }).eq('id', m.id);
    }
    await supabase.from('members').update({ is_primary: true }).eq('id', memberId);
    const member = members.find(m => m.id === memberId);
    if (member) {
      await supabase.from('flats').update({ owner_name: member.name }).eq('id', flatId);
    }
    showSuccess('Updated!', 'Primary member changed');
    loadMembers();
    loadFlats();
  };

  // === RESET PASSWORD for flat ===
  const resetFlatPassword = async (flatId: string) => {
    const ok = await confirmAction('Reset Password?', 'Generate a new password for all members of this flat?', 'Yes, Reset', 'Cancel');
    if (!ok) return;
    const newPass = generateFlatPassword();
    await supabase.from('resident_users').update({ password: newPass }).eq('flat_id', flatId);
    showSuccess('Password Reset!', `New password: ${newPass}`);
    loadResidentUsers();
  };

  // === DELETE FLAT ===
  const removeFlat = async (flatId: string) => {
    const ok = await confirmAction('Delete Flat?', 'This will remove the flat, all members and login accounts.', 'Delete', 'Cancel');
    if (!ok) return;
    await supabase.from('resident_users').delete().eq('flat_id', flatId);
    await supabase.from('members').delete().eq('flat_id', flatId);
    await supabase.from('flats').delete().eq('id', flatId);
    showSuccess('Deleted!', 'Flat and all data removed');
    loadFlats();
    loadMembers();
    loadResidentUsers();
  };

  const togglePasswordVisibility = (flatId: string) => {
    setShowPasswords(prev => ({ ...prev, [flatId]: !prev[flatId] }));
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Users className="w-5 h-5 text-primary" />
          <h2 className="font-semibold">{t('admin.manageResidents')}</h2>
        </div>
        <button onClick={() => setViewTab(viewTab === 'addFlat' ? 'flats' : 'addFlat')}
          className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-primary/10 text-primary text-xs font-medium">
          <Plus className="w-3.5 h-3.5" /> Add Flat
        </button>
      </div>

      {/* Add Flat Form */}
      {viewTab === 'addFlat' && (
        <div className="card-section p-4 mb-4 space-y-3">
          <p className="text-sm font-semibold">Add New Flat</p>
          <div className="grid grid-cols-2 gap-3">
            <input className="input-field" placeholder="Flat No. (e.g. 607)" value={flatForm.flat_number} onChange={e => setFlatForm({...flatForm, flat_number: e.target.value})} />
            <input className="input-field" placeholder="Floor (e.g. 5th)" value={flatForm.floor} onChange={e => setFlatForm({...flatForm, floor: e.target.value})} />
            <input className="input-field" placeholder="Wing" value={flatForm.wing} onChange={e => setFlatForm({...flatForm, wing: e.target.value})} />
            <input className="input-field" placeholder="Owner Name" value={flatForm.owner_name} onChange={e => setFlatForm({...flatForm, owner_name: e.target.value})} />
            <input className="input-field" placeholder="Owner Phone" value={flatForm.owner_phone} onChange={e => setFlatForm({...flatForm, owner_phone: e.target.value})} />
            <input className="input-field" placeholder="Intercom" value={flatForm.intercom} onChange={e => setFlatForm({...flatForm, intercom: e.target.value})} />
          </div>
          <div className="flex gap-2">
            <button onClick={saveFlat} className="btn-primary flex-1">Add Flat</button>
            <button onClick={() => setViewTab('flats')} className="btn-secondary flex-1">{t('common.cancel')}</button>
          </div>
        </div>
      )}

      {/* Search */}
      <div className="relative mb-4">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input className="input-field pl-9" placeholder="Search flat, owner, phone..." value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {/* Summary */}
      <div className="flex gap-2 mb-4 text-xs">
        <span className="bg-primary/10 text-primary px-2 py-1 rounded-lg font-medium">{flats.length} Flats</span>
        <span className="bg-secondary text-secondary-foreground px-2 py-1 rounded-lg font-medium">{members.length} Members</span>
        <span className="bg-secondary text-secondary-foreground px-2 py-1 rounded-lg font-medium">{residentVehicles.length} Vehicles</span>
        <span className="bg-secondary text-secondary-foreground px-2 py-1 rounded-lg font-medium">{residentUsers.length} Logins</span>
      </div>

      {/* Flat List */}
      {filteredFlats.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-12">No flats found</p>
      ) : (
        <div className="flex flex-col gap-2">
          {filteredFlats.map(flat => {
            const isExpanded = expandedFlat === flat.id;
            const flatMembers = getMembersForFlat(flat.id);
            const flatVehicles = getVehiclesForFlat(flat.flatNumber);
            const primary = flatMembers.find(m => m.isPrimary);
            const flatLogins = getResidentUsersForFlat(flat.id);
            const flatPass = getFlatPassword(flat.id);

            return (
              <div key={flat.id} className="card-section">
                <button type="button" className="w-full flex items-center gap-3 text-left p-3"
                  onClick={() => setExpandedFlat(isExpanded ? null : flat.id)}>
                  <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${flat.isOccupied ? 'bg-primary/10' : 'bg-muted'}`}>
                    <Home className={`w-5 h-5 ${flat.isOccupied ? 'text-primary' : 'text-muted-foreground'}`} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-semibold font-mono">{flat.flatNumber}</p>
                      {flat.wing && <span className="text-[10px] bg-secondary px-1.5 py-0.5 rounded text-secondary-foreground">Wing {flat.wing}</span>}
                      {!flat.isOccupied && <span className="text-[10px] bg-warning/20 px-1.5 py-0.5 rounded text-warning">Vacant</span>}
                    </div>
                    <p className="text-xs text-muted-foreground truncate">
                      {primary?.name || flat.ownerName || 'No owner'} · {flatMembers.length} members · {flatVehicles.length} vehicles
                      {flatLogins.length > 0 && ` · ${flatLogins.length} logins`}
                    </p>
                  </div>
                  {isExpanded ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
                </button>

                {isExpanded && (
                  <div className="px-3 pb-3 border-t border-border space-y-3 pt-3">
                    {/* Flat details */}
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div><span className="text-muted-foreground">Floor:</span> <span className="font-medium">{flat.floor || '-'}</span></div>
                      <div><span className="text-muted-foreground">Type:</span> <span className="font-medium capitalize">{flat.flatType}</span></div>
                      {flat.intercom && <div><span className="text-muted-foreground">Intercom:</span> <span className="font-mono font-medium">{flat.intercom}</span></div>}
                      {flat.ownerPhone && (
                        <div className="flex items-center gap-1">
                          <Phone className="w-3 h-3 text-muted-foreground" />
                          <a href={`tel:${flat.ownerPhone}`} className="font-mono font-medium text-primary">{flat.ownerPhone}</a>
                        </div>
                      )}
                    </div>

                    {/* Login Credentials */}
                    {flatLogins.length > 0 && (
                      <div className="bg-primary/5 rounded-lg p-2.5 border border-primary/10">
                        <div className="flex items-center justify-between mb-1.5">
                          <div className="flex items-center gap-1.5">
                            <Key className="w-3.5 h-3.5 text-primary" />
                            <p className="text-[10px] uppercase tracking-wider text-primary font-medium">Login Credentials</p>
                          </div>
                          <div className="flex items-center gap-1">
                            <button onClick={() => togglePasswordVisibility(flat.id)} className="p-1 text-muted-foreground hover:text-primary" title="Show/Hide Password">
                              {showPasswords[flat.id] ? <EyeOff className="w-3 h-3" /> : <Eye className="w-3 h-3" />}
                            </button>
                            <button onClick={() => resetFlatPassword(flat.id)} className="p-1 text-muted-foreground hover:text-primary" title="Reset Password">
                              <RefreshCw className="w-3 h-3" />
                            </button>
                          </div>
                        </div>
                        <p className="text-[10px] text-muted-foreground mb-1">
                          Password (shared): <span className="font-mono font-medium text-foreground">
                            {showPasswords[flat.id] ? flatPass : '••••••••'}
                          </span>
                        </p>
                        <div className="space-y-0.5">
                          {flatLogins.map(u => (
                            <p key={u.id} className="text-[10px] text-muted-foreground">
                              📱 <span className="font-mono">{u.phone}</span> — {u.name}
                            </p>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Members */}
                    <div>
                      <div className="flex items-center justify-between mb-1.5">
                        <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium">Members ({flatMembers.length})</p>
                        <button onClick={() => { resetMemberForm(); setShowMemberForm(flat.id); }}
                          className="flex items-center gap-1 text-[10px] text-primary font-medium">
                          <UserPlus className="w-3 h-3" /> Add
                        </button>
                      </div>

                      {flatMembers.length > 0 && (
                        <div className="space-y-1.5">
                          {flatMembers.map(m => (
                            <div key={m.id} className="flex items-center gap-2 bg-secondary/50 rounded-lg px-2.5 py-1.5">
                              <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-[10px] font-bold text-primary flex-shrink-0">
                                {m.name.charAt(0)}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-xs font-medium truncate">
                                  {m.name}
                                  {m.isPrimary && <span className="ml-1 text-[9px] text-primary">★ Primary</span>}
                                </p>
                                <p className="text-[10px] text-muted-foreground capitalize">
                                  {m.relation}{m.age ? ` · ${m.age}y` : ''}{m.gender ? ` · ${m.gender}` : ''}
                                  {m.phone ? ` · 📱${m.phone}` : ''}
                                </p>
                              </div>
                              <div className="flex items-center gap-0.5 flex-shrink-0">
                                {!m.isPrimary && (
                                  <button onClick={() => setPrimaryMember(m.id, flat.id)} className="p-1 text-muted-foreground hover:text-primary" title="Set Primary">
                                    <Star className="w-3 h-3" />
                                  </button>
                                )}
                                <button onClick={() => editMember(m)} className="p-1 text-muted-foreground hover:text-primary">
                                  <Edit2 className="w-3 h-3" />
                                </button>
                                <button onClick={() => removeMember(m.id)} className="p-1 text-muted-foreground hover:text-destructive">
                                  <Trash2 className="w-3 h-3" />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}

                      {/* Add/Edit Member Form */}
                      {showMemberForm === flat.id && (
                        <div className="mt-2 p-3 bg-secondary/30 rounded-lg space-y-2">
                          <p className="text-xs font-semibold">{editingMember ? 'Edit Member' : 'Add Member'}</p>
                          <div className="grid grid-cols-2 gap-2">
                            <input className="input-field text-xs" placeholder="Name *" value={memberForm.name} onChange={e => setMemberForm({...memberForm, name: e.target.value})} />
                            <input className="input-field text-xs" placeholder="Phone (for login)" value={memberForm.phone} onChange={e => setMemberForm({...memberForm, phone: e.target.value.replace(/\D/g, '')})} maxLength={10} />
                            <select className="input-field text-xs" value={memberForm.relation} onChange={e => setMemberForm({...memberForm, relation: e.target.value})}>
                              <option value="owner">Owner</option>
                              <option value="spouse">Spouse</option>
                              <option value="son">Son</option>
                              <option value="daughter">Daughter</option>
                              <option value="father">Father</option>
                              <option value="mother">Mother</option>
                              <option value="family">Family</option>
                              <option value="tenant">Tenant</option>
                              <option value="other">Other</option>
                            </select>
                            <input className="input-field text-xs" placeholder="Age" type="number" value={memberForm.age} onChange={e => setMemberForm({...memberForm, age: e.target.value})} />
                            <select className="input-field text-xs" value={memberForm.gender} onChange={e => setMemberForm({...memberForm, gender: e.target.value})}>
                              <option value="Male">Male</option>
                              <option value="Female">Female</option>
                              <option value="Other">Other</option>
                            </select>
                            <label className="flex items-center gap-2 text-xs">
                              <input type="checkbox" checked={memberForm.isPrimary} onChange={e => setMemberForm({...memberForm, isPrimary: e.target.checked})} className="rounded" />
                              Primary Member
                            </label>
                          </div>
                          <p className="text-[10px] text-muted-foreground">💡 Members with phone numbers will automatically get a login account. All flatmates share the same password.</p>
                          <div className="flex gap-2">
                            <button onClick={() => saveMember(flat.id)} className="btn-primary flex-1 text-xs py-1.5">{editingMember ? 'Update' : 'Add'}</button>
                            <button onClick={resetMemberForm} className="btn-secondary flex-1 text-xs py-1.5">Cancel</button>
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Vehicles */}
                    {flatVehicles.length > 0 && (
                      <div>
                        <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mb-1.5">Vehicles ({flatVehicles.length})</p>
                        <div className="flex flex-wrap gap-1.5">
                          {flatVehicles.map(v => (
                            <span key={v.id} className="flex items-center gap-1 bg-secondary/50 rounded-lg px-2.5 py-1.5 text-xs">
                              <Car className="w-3 h-3 text-muted-foreground" />
                              <span className="font-mono font-medium">{v.vehicleNumber}</span>
                              <span className="text-[10px] text-muted-foreground capitalize">({v.vehicleType})</span>
                            </span>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Delete flat */}
                    <button onClick={() => removeFlat(flat.id)} className="text-[10px] text-destructive hover:underline mt-2">
                      Remove this flat
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default AdminResidentManager;
