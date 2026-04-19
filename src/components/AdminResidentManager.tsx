import { useState, useEffect, useMemo, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Plus, Trash2, Edit2, Search, Users, Home, ChevronDown, ChevronUp, Car, Phone, Star, UserPlus, Key, Eye, EyeOff, RefreshCw, Camera, FileDown } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import { generateFlatPassword } from '@/lib/passwordGenerator';
import { floorLabelFromFlatNumber } from '@/lib/flatFloor';
import { allowsResidentLoginAndPrimary, isRestrictedMemberCategory, STAFF_VEHICLE_TYPES } from '@/lib/memberCategories';
import type { Flat, Member } from '@/types';
import { Switch } from '@/components/ui/switch';
import { exportResidentsDirectoryPdf, type PdfFlat, type PdfMember } from '@/lib/exportResidentsPdf';
import SensitiveAdminVerifyModal from '@/components/SensitiveAdminVerifyModal';

type MemberFormState = {
  name: string;
  phone: string;
  relation: string;
  age: string;
  gender: string;
  isPrimary: boolean;
  photo: string;
  idPhotoFront: string;
  idPhotoBack: string;
  policeVerification: string;
  spouseName: string;
  dateJoining: string;
  dateLeave: string;
  vehicleCategory: string;
  vehicleName: string;
  vehicleNumber: string;
  vehicleColor: string;
};

const initialMemberForm = (): MemberFormState => ({
  name: '',
  phone: '',
  relation: '',
  age: '',
  gender: '',
  isPrimary: false,
  photo: '',
  idPhotoFront: '',
  idPhotoBack: '',
  policeVerification: '',
  spouseName: '',
  dateJoining: '',
  dateLeave: '',
  vehicleCategory: '',
  vehicleName: '',
  vehicleNumber: '',
  vehicleColor: '',
});

type ViewTab = 'flats' | 'addFlat';

interface ResidentUser {
  id: string; name: string; phone: string; flat_id: string; flat_number: string; password: string;
}

interface AdminResidentManagerProps {
  verifyAdminId: string;
  verifyAdminName: string;
  /** When true, password/biometric step runs before mutating resident or flat records. */
  requireSensitiveVerify?: boolean;
}

const AdminResidentManager = ({
  verifyAdminId,
  verifyAdminName,
  requireSensitiveVerify = true,
}: AdminResidentManagerProps) => {
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
  const [memberForm, setMemberForm] = useState<MemberFormState>(initialMemberForm);
  const [editingMember, setEditingMember] = useState<string | null>(null);

  const floorFieldTouched = useRef(false);
  const [flatMetaEditId, setFlatMetaEditId] = useState<string | null>(null);
  const [flatMetaForm, setFlatMetaForm] = useState({ floor: '', wing: '', intercom: '' });
  const [residentSelfIdUploadEnabled, setResidentSelfIdUploadEnabled] = useState(false);
  const [exportingPdf, setExportingPdf] = useState(false);

  const pendingSensitive = useRef<null | (() => Promise<void>)>(null);
  const [sensitiveOpen, setSensitiveOpen] = useState(false);
  const [sensitiveTitle, setSensitiveTitle] = useState('');
  const [sensitiveActionLabel, setSensitiveActionLabel] = useState('');

  const runSensitive = (actionLabel: string, title: string, fn: () => Promise<void>) => {
    if (!requireSensitiveVerify) {
      void fn();
      return;
    }
    pendingSensitive.current = fn;
    setSensitiveActionLabel(actionLabel);
    setSensitiveTitle(title);
    setSensitiveOpen(true);
  };

  const handleSensitiveVerified = () => {
    const fn = pendingSensitive.current;
    pendingSensitive.current = null;
    if (fn) void fn();
  };

  useEffect(() => { loadFlats(); loadMembers(); loadResidentVehicles(); loadResidentUsers(); }, []);

  useEffect(() => {
    if (!societyId) {
      setResidentSelfIdUploadEnabled(false);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('societies').select('resident_self_id_upload_enabled').eq('id', societyId).single();
      if (!cancelled) setResidentSelfIdUploadEnabled(!!data?.resident_self_id_upload_enabled);
    })();
    return () => { cancelled = true; };
  }, [societyId]);

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

    runSensitive('add_flat', 'Add flat', async () => {
      const suggested = floorLabelFromFlatNumber(flatForm.flat_number);
      const floorValue = (flatForm.floor.trim() || suggested || '').trim() || null;

      await supabase.from('flats').insert({
        flat_number: flatForm.flat_number,
        floor: floorValue,
        wing: flatForm.wing || null,
        flat_type: 'residential',
        owner_name: flatForm.owner_name || null,
        owner_phone: flatForm.owner_phone || null,
        intercom: flatForm.intercom || null,
        is_occupied: !!flatForm.owner_name,
        society_id: societyId || null,
      });

      toast.success('Flat added successfully');
      floorFieldTouched.current = false;
      setFlatForm({ flat_number: '', floor: '', wing: 'A', owner_name: '', owner_phone: '', intercom: '' });
      setViewTab('flats');
      loadFlats();
    });
  };

  const openAddFlatTab = () => {
    if (viewTab !== 'addFlat') {
      floorFieldTouched.current = false;
      setFlatForm({ flat_number: '', floor: '', wing: 'A', owner_name: '', owner_phone: '', intercom: '' });
    }
    setViewTab(viewTab === 'addFlat' ? 'flats' : 'addFlat');
  };

  const startFlatMetaEdit = (f: Flat) => {
    setFlatMetaEditId(f.id);
    setFlatMetaForm({
      floor: f.floor || '',
      wing: f.wing || '',
      intercom: f.intercom || '',
    });
  };

  const cancelFlatMetaEdit = () => setFlatMetaEditId(null);

  const saveFlatMeta = async () => {
    if (!flatMetaEditId) return;
    const id = flatMetaEditId;
    runSensitive('edit_flat_meta', 'Update flat details', async () => {
      await supabase
        .from('flats')
        .update({
          floor: flatMetaForm.floor.trim() || null,
          wing: flatMetaForm.wing.trim() || null,
          intercom: flatMetaForm.intercom.trim() || null,
        })
        .eq('id', id);
      toast.success('Flat details updated');
      setFlatMetaEditId(null);
      loadFlats();
    });
  };

  // === SYNC RESIDENT USERS for a flat ===
  const syncResidentUsersForFlat = async (flatId: string, flatNumber: string) => {
    // Re-fetch to get latest after member add
    const { data: latestMembers } = await supabase.from('members').select('*').eq('flat_id', flatId);
    const membersWithPhone = (latestMembers || []).filter(
      (m: { phone?: string | null; relation?: string | null }) =>
        !!m.phone && allowsResidentLoginAndPrimary(m.relation),
    );
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
        must_change_password: !!m.is_primary,
      }));

    if (newUsers.length > 0) {
      await supabase.from('resident_users').insert(newUsers);
      toast.success(`${newUsers.length} resident login(s) created`);
      loadResidentUsers();
    }
  };

  const toggleResidentSelfIdUpload = async (on: boolean) => {
    if (!societyId) {
      toast.error('Select a society first');
      return;
    }
    runSensitive('resident_self_id_policy', 'Change resident ID upload policy', async () => {
      const { error } = await supabase.from('societies').update({ resident_self_id_upload_enabled: on }).eq('id', societyId);
      if (error) {
        toast.error(error.message);
        return;
      }
      setResidentSelfIdUploadEnabled(on);
      toast.success(on ? 'Residents can add or edit their own Photo ID in the app (Profile).' : 'Self-service Photo ID turned off');
    });
  };

  const handleExportResidentsPdf = async () => {
    if (!societyId) {
      toast.error('Select a society first');
      return;
    }
    setExportingPdf(true);
    try {
      const { data: soc } = await supabase.from('societies').select('name').eq('id', societyId).single();
      const pdfFlats: PdfFlat[] = flats.map((f) => ({
        id: f.id,
        flat_number: f.flatNumber,
        owner_name: f.ownerName ?? null,
        floor: f.floor ?? null,
        wing: f.wing ?? null,
      }));
      const pdfMembers: PdfMember[] = members.map((m) => ({
        flat_id: m.flatId,
        name: m.name,
        relation: m.relation,
        phone: m.phone ?? null,
        age: m.age ?? null,
        gender: m.gender ?? null,
        is_primary: m.isPrimary,
        spouse_name: m.spouseName ?? null,
        police_verification: m.policeVerification ?? null,
        date_joining: m.dateJoining ?? null,
        date_leave: m.dateLeave ?? null,
        id_photo_front: m.idPhotoFront ?? null,
        id_photo_back: m.idPhotoBack ?? null,
      }));
      exportResidentsDirectoryPdf(soc?.name || 'Society', pdfFlats, pdfMembers);
    } finally {
      setExportingPdf(false);
    }
  };

  const pickIdImage = (field: 'idPhotoFront' | 'idPhotoBack' | 'photo') => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onloadend = () => setMemberForm((f) => ({ ...f, [field]: reader.result as string }));
      reader.readAsDataURL(file);
    };
    input.click();
  };

  const syncStaffVehicleRow = async (memberId: string, flatId: string, flatNumber: string, residentName: string) => {
    const { data: existing } = await supabase.from('resident_vehicles').select('id').eq('member_id', memberId).maybeSingle();
    const num = memberForm.vehicleNumber.trim();
    const hasVehicle = num.length > 0 || memberForm.vehicleName.trim().length > 0;
    if (!hasVehicle) {
      if (existing?.id) await supabase.from('resident_vehicles').delete().eq('id', existing.id);
      return;
    }
    const row = {
      flat_id: flatId,
      flat_number: flatNumber,
      resident_name: residentName,
      vehicle_number: num || 'N/A',
      vehicle_type: memberForm.vehicleCategory || 'other',
      vehicle_display_name: memberForm.vehicleName.trim() || null,
      vehicle_color: memberForm.vehicleColor.trim() || null,
      member_id: memberId,
    };
    if (existing?.id) await supabase.from('resident_vehicles').update(row).eq('id', existing.id);
    else await supabase.from('resident_vehicles').insert(row);
  };

  // === ADD/EDIT MEMBER ===
  const saveMember = async (flatId: string) => {
    if (!memberForm.name) { toast.error('Name is required'); return; }
    if (!memberForm.relation) { toast.error('Please select a relation or role'); return; }

    const restricted = isRestrictedMemberCategory(memberForm.relation);
    if (restricted && !memberForm.idPhotoFront && !(editingMember && members.find((x) => x.id === editingMember)?.idPhotoFront)) {
      toast.error('Photo ID (front) is required for tenant, other, and staff/service');
      return;
    }

    runSensitive(
      editingMember ? 'update_member' : 'add_member',
      editingMember ? 'Update household member' : 'Add household member',
      async () => {
    const flat = flats.find((f) => f.id === flatId);
    const existing = getMembersForFlat(flatId);
    const prev = editingMember ? members.find((m) => m.id === editingMember) : null;
    const primaryExists = !!getPrimaryMember(flatId);
    const showPrimaryCheckbox =
      allowsResidentLoginAndPrimary(memberForm.relation) && !primaryExists && existing.length > 0;

    let isPrimary = false;
    if (allowsResidentLoginAndPrimary(memberForm.relation)) {
      if (prev?.isPrimary) isPrimary = true;
      else if (!editingMember && existing.length === 0) isPrimary = true;
      else if (memberForm.isPrimary && showPrimaryCheckbox) isPrimary = true;
    }

    if (isPrimary) {
      const existingPrimary = getPrimaryMember(flatId);
      if (existingPrimary && existingPrimary.id !== editingMember) {
        await supabase.from('members').update({ is_primary: false }).eq('id', existingPrimary.id);
      }
    }

    const payload: Record<string, unknown> = {
      flat_id: flatId,
      name: memberForm.name,
      phone: memberForm.phone || null,
      relation: memberForm.relation,
      age: memberForm.age ? parseInt(memberForm.age, 10) : null,
      gender: memberForm.gender || null,
      is_primary: isPrimary,
      photo: memberForm.photo || null,
    };

    if (restricted) {
      payload.id_photo_front = memberForm.idPhotoFront || null;
      payload.id_photo_back = memberForm.idPhotoBack || null;
      payload.police_verification = memberForm.policeVerification.trim() || null;
      payload.spouse_name = memberForm.spouseName.trim() || null;
      payload.date_joining = memberForm.dateJoining || null;
      payload.date_leave = memberForm.dateLeave || null;
    } else {
      payload.id_photo_front = null;
      payload.id_photo_back = null;
      payload.police_verification = null;
      payload.spouse_name = null;
      payload.date_joining = null;
      payload.date_leave = null;
    }

    if (prev?.phone && (restricted || !memberForm.phone || memberForm.phone !== prev.phone)) {
      await supabase.from('resident_users').delete().eq('phone', prev.phone).eq('flat_id', flatId);
    }
    if (restricted && memberForm.phone) {
      await supabase.from('resident_users').delete().eq('phone', memberForm.phone).eq('flat_id', flatId);
    }

    let memberId = editingMember;

    if (editingMember) {
      await supabase.from('members').update(payload).eq('id', editingMember);
      if (allowsResidentLoginAndPrimary(memberForm.relation) && memberForm.phone) {
        await supabase
          .from('resident_users')
          .update({ name: memberForm.name })
          .eq('phone', memberForm.phone)
          .eq('flat_id', flatId);
      }
      showSuccess('Updated!', 'Member updated successfully');
    } else {
      const { data: ins, error: insErr } = await supabase.from('members').insert(payload).select('id').single();
      if (insErr || !ins) {
        toast.error(insErr?.message || 'Could not add member');
        return;
      }
      memberId = ins.id;
      toast.success('Member added');
    }

    if (isPrimary && flat) {
      await supabase.from('flats').update({ owner_name: memberForm.name, is_occupied: true }).eq('id', flatId);
    }

    if (restricted && memberId && flat) {
      await syncStaffVehicleRow(memberId, flatId, flat.flatNumber, memberForm.name);
    } else if (memberId) {
      const { data: vdel } = await supabase.from('resident_vehicles').select('id').eq('member_id', memberId).maybeSingle();
      if (vdel?.id) await supabase.from('resident_vehicles').delete().eq('id', vdel.id);
    }

    resetMemberForm();
    await loadMembers();
    loadResidentVehicles();
    loadFlats();

    if (allowsResidentLoginAndPrimary(memberForm.relation) && memberForm.phone && flat) {
      await syncResidentUsersForFlat(flatId, flat.flatNumber);
    }
    loadResidentUsers();
      },
    );
  };

  const mapGenderForAdminForm = (g: string | undefined) => {
    const x = (g ?? '').trim().toLowerCase();
    if (x === 'male') return 'Male';
    if (x === 'female') return 'Female';
    if (x === 'other') return 'Other';
    if (g === 'Male' || g === 'Female' || g === 'Other') return g;
    return '';
  };

  const editMember = async (m: Member) => {
    setMemberForm({
      ...initialMemberForm(),
      name: m.name,
      phone: m.phone || '',
      relation: m.relation,
      age: m.age ? String(m.age) : '',
      gender: mapGenderForAdminForm(m.gender),
      isPrimary: m.isPrimary,
      photo: m.photo || '',
      idPhotoFront: m.idPhotoFront || '',
      idPhotoBack: m.idPhotoBack || '',
      policeVerification: m.policeVerification || '',
      spouseName: m.spouseName || '',
      dateJoining: m.dateJoining || '',
      dateLeave: m.dateLeave || '',
    });
    setEditingMember(m.id);
    setShowMemberForm(m.flatId);
    const { data: vrow } = await supabase.from('resident_vehicles').select('*').eq('member_id', m.id).maybeSingle();
    if (vrow) {
      setMemberForm((f) => ({
        ...f,
        vehicleCategory: vrow.vehicle_type || '',
        vehicleName: vrow.vehicle_display_name || '',
        vehicleNumber: vrow.vehicle_number === 'N/A' ? '' : vrow.vehicle_number,
        vehicleColor: vrow.vehicle_color || '',
      }));
    }
  };

  const removeMember = async (id: string) => {
    const ok = await confirmAction('Delete Member?', 'This member will be removed permanently.', 'Delete', 'Cancel');
    if (!ok) return;
    runSensitive('remove_member', 'Remove household member', async () => {
      const member = members.find(m => m.id === id);
      await supabase.from('resident_vehicles').delete().eq('member_id', id);
      await supabase.from('members').delete().eq('id', id);
      if (member?.phone) {
        await supabase.from('resident_users').delete().eq('phone', member.phone).eq('flat_id', member.flatId);
      }
      toast.success('Member removed');
      loadMembers();
      loadResidentUsers();
    });
  };

  const resetMemberForm = () => {
    setMemberForm(initialMemberForm());
    setShowMemberForm(null);
    setEditingMember(null);
  };

  const setPrimaryMember = async (memberId: string, flatId: string) => {
    const target = members.find((m) => m.id === memberId);
    if (!target || !allowsResidentLoginAndPrimary(target.relation)) {
      toast.error('Only household members can be primary (not tenant, staff, or other)');
      return;
    }
    runSensitive('set_primary_member', 'Change primary member', async () => {
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
    });
  };

  // === RESET PASSWORD for flat ===
  const resetFlatPassword = async (flatId: string) => {
    const ok = await confirmAction('Reset Password?', 'Generate a new password for all members of this flat?', 'Yes, Reset', 'Cancel');
    if (!ok) return;
    runSensitive('reset_flat_password', 'Reset resident login password', async () => {
      const newPass = generateFlatPassword();
      await supabase.from('resident_users').update({ password: newPass }).eq('flat_id', flatId);
      showSuccess('Password Reset!', `New password: ${newPass}`);
      loadResidentUsers();
    });
  };

  // === DELETE FLAT ===
  const removeFlat = async (flatId: string) => {
    const ok = await confirmAction('Delete Flat?', 'This will remove the flat, all members and login accounts.', 'Delete', 'Cancel');
    if (!ok) return;
    runSensitive('remove_flat', 'Delete flat and all members', async () => {
      await supabase.from('resident_users').delete().eq('flat_id', flatId);
      await supabase.from('members').delete().eq('flat_id', flatId);
      await supabase.from('flats').delete().eq('id', flatId);
      showSuccess('Deleted!', 'Flat and all data removed');
      loadFlats();
      loadMembers();
      loadResidentUsers();
    });
  };

  const togglePasswordVisibility = (flatId: string) => {
    setShowPasswords(prev => ({ ...prev, [flatId]: !prev[flatId] }));
  };

  return (
    <div className="page-container">
      <div className="flex flex-col gap-3 mb-4">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Users className="w-5 h-5 text-primary" />
            <h2 className="font-semibold">{t('admin.manageResidents')}</h2>
          </div>
          <div className="flex items-center gap-2 flex-wrap justify-end">
            <button
              type="button"
              onClick={handleExportResidentsPdf}
              disabled={exportingPdf || !societyId}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-secondary text-secondary-foreground text-xs font-medium disabled:opacity-50"
            >
              <FileDown className="w-3.5 h-3.5" /> {exportingPdf ? 'PDF…' : 'Export PDF'}
            </button>
            <button onClick={openAddFlatTab}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-primary/10 text-primary text-xs font-medium">
              <Plus className="w-3.5 h-3.5" /> Add Flat
            </button>
          </div>
        </div>
        {societyId && (
          <div className="flex items-center justify-between gap-3 rounded-lg border border-border bg-card/50 px-3 py-2.5">
            <div className="min-w-0">
              <p className="text-xs font-medium text-foreground">Resident self-service Photo ID</p>
              <p className="text-[10px] text-muted-foreground leading-snug">
                When on, logged-in residents see Profile options to upload or change their own ID (front/back) only for their linked member row.
              </p>
            </div>
            <Switch
              checked={residentSelfIdUploadEnabled}
              onCheckedChange={toggleResidentSelfIdUpload}
              aria-label="Allow residents to upload their own photo ID"
            />
          </div>
        )}
      </div>

      {/* Add Flat Form */}
      {viewTab === 'addFlat' && (
        <div className="card-section p-4 mb-4 space-y-3">
          <p className="text-sm font-semibold">Add New Flat</p>
          <p className="text-[11px] text-muted-foreground leading-snug">
            Floor is filled automatically for 3-digit flats (101–199 → 1st Floor, … 601–699 → 6th Floor). Change it anytime for your society’s numbering.
          </p>
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Flat no. *</label>
              <input
                className="input-field"
                placeholder="e.g. 103, 607"
                value={flatForm.flat_number}
                onChange={e => {
                  const v = e.target.value;
                  const sug = floorLabelFromFlatNumber(v);
                  setFlatForm(prev => ({
                    ...prev,
                    flat_number: v,
                    floor: floorFieldTouched.current ? prev.floor : (sug ?? (v.trim() ? prev.floor : '')),
                  }));
                }}
              />
            </div>
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Floor</label>
              <input
                className="input-field"
                placeholder="Auto or e.g. Ground, 1st Floor"
                value={flatForm.floor}
                onChange={e => {
                  floorFieldTouched.current = true;
                  setFlatForm({ ...flatForm, floor: e.target.value });
                }}
              />
            </div>
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Wing</label>
              <input className="input-field" placeholder="e.g. A" value={flatForm.wing} onChange={e => setFlatForm({ ...flatForm, wing: e.target.value })} />
            </div>
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Primary / owner name</label>
              <input className="input-field" placeholder="Owner name" value={flatForm.owner_name} onChange={e => setFlatForm({ ...flatForm, owner_name: e.target.value })} />
            </div>
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Owner phone</label>
              <input className="input-field" placeholder="For resident login" value={flatForm.owner_phone} onChange={e => setFlatForm({ ...flatForm, owner_phone: e.target.value })} />
            </div>
            <div className="col-span-2 sm:col-span-1">
              <label className="text-[10px] uppercase tracking-wide text-muted-foreground font-medium block mb-1">Intercom</label>
              <input className="input-field" placeholder="Optional" value={flatForm.intercom} onChange={e => setFlatForm({ ...flatForm, intercom: e.target.value })} />
            </div>
          </div>
          <div className="flex gap-2">
            <button onClick={saveFlat} className="btn-primary flex-1">Add Flat</button>
            <button
              onClick={() => {
                floorFieldTouched.current = false;
                setViewTab('flats');
              }}
              className="btn-secondary flex-1"
            >
              {t('common.cancel')}
            </button>
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
                  onClick={() => {
                    if (isExpanded) {
                      setExpandedFlat(null);
                      if (flatMetaEditId === flat.id) setFlatMetaEditId(null);
                    } else {
                      setExpandedFlat(flat.id);
                    }
                  }}>
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
                    {flatMetaEditId === flat.id ? (
                      <div className="space-y-2 rounded-lg bg-secondary/30 p-3">
                        <p className="text-xs font-semibold">Edit flat / floor</p>
                        <div className="grid grid-cols-2 gap-2">
                          <div className="col-span-2 sm:col-span-1">
                            <label className="text-[10px] text-muted-foreground block mb-0.5">Floor</label>
                            <input
                              className="input-field text-xs"
                              value={flatMetaForm.floor}
                              onChange={e => setFlatMetaForm(f => ({ ...f, floor: e.target.value }))}
                              placeholder="e.g. 1st Floor, Ground"
                            />
                          </div>
                          <div className="col-span-2 sm:col-span-1">
                            <label className="text-[10px] text-muted-foreground block mb-0.5">Wing</label>
                            <input
                              className="input-field text-xs"
                              value={flatMetaForm.wing}
                              onChange={e => setFlatMetaForm(f => ({ ...f, wing: e.target.value }))}
                              placeholder="Wing"
                            />
                          </div>
                          <div className="col-span-2">
                            <label className="text-[10px] text-muted-foreground block mb-0.5">Intercom</label>
                            <input
                              className="input-field text-xs"
                              value={flatMetaForm.intercom}
                              onChange={e => setFlatMetaForm(f => ({ ...f, intercom: e.target.value }))}
                              placeholder="Intercom"
                            />
                          </div>
                        </div>
                        <div className="flex gap-2">
                          <button type="button" onClick={saveFlatMeta} className="btn-primary text-xs py-1.5 flex-1">Save</button>
                          <button type="button" onClick={cancelFlatMetaEdit} className="btn-secondary text-xs py-1.5 flex-1">Cancel</button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex flex-col gap-2">
                        <div className="grid grid-cols-2 gap-2 text-xs">
                          <div><span className="text-muted-foreground">Floor:</span> <span className="font-medium">{flat.floor || '-'}</span></div>
                          <div><span className="text-muted-foreground">Type:</span> <span className="font-medium capitalize">{flat.flatType}</span></div>
                          {flat.wing && <div><span className="text-muted-foreground">Wing:</span> <span className="font-medium">{flat.wing}</span></div>}
                          {flat.intercom && <div className="col-span-2"><span className="text-muted-foreground">Intercom:</span> <span className="font-mono font-medium">{flat.intercom}</span></div>}
                          {flat.ownerPhone && (
                            <div className="col-span-2 flex items-center gap-1">
                              <Phone className="w-3 h-3 text-muted-foreground" />
                              <a href={`tel:${flat.ownerPhone}`} className="font-mono font-medium text-primary">{flat.ownerPhone}</a>
                            </div>
                          )}
                        </div>
                        <button
                          type="button"
                          onClick={() => startFlatMetaEdit(flat)}
                          className="self-start text-[10px] font-medium text-primary hover:underline"
                        >
                          Edit floor / wing / intercom
                        </button>
                      </div>
                    )}

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
                            <div key={m.id} className="flex items-start gap-2 bg-secondary/50 rounded-lg px-2.5 py-1.5">
                              <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-[10px] font-bold text-primary flex-shrink-0 overflow-hidden">
                                {m.photo ? <img src={m.photo} alt="" className="w-full h-full object-cover" /> : m.name.charAt(0)}
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
                                {(m.idPhotoFront || m.idPhotoBack) && (
                                  <div className="flex gap-1 mt-1 flex-wrap">
                                    {m.idPhotoFront && (
                                      <img src={m.idPhotoFront} alt="" className="h-9 w-14 object-cover rounded border border-border" />
                                    )}
                                    {m.idPhotoBack && (
                                      <img src={m.idPhotoBack} alt="" className="h-9 w-14 object-cover rounded border border-border" />
                                    )}
                                  </div>
                                )}
                              </div>
                              <div className="flex items-center gap-0.5 flex-shrink-0">
                                {!m.isPrimary && allowsResidentLoginAndPrimary(m.relation) && (
                                  <button onClick={() => setPrimaryMember(m.id, flat.id)} className="p-1 text-muted-foreground hover:text-primary" title="Set primary (household only)">
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
                      {showMemberForm === flat.id && (() => {
                        const restrictedForm = isRestrictedMemberCategory(memberForm.relation);
                        const showPrimaryCheckbox =
                          allowsResidentLoginAndPrimary(memberForm.relation) && !primary && flatMembers.length > 0;
                        return (
                        <div className="mt-2 p-3 bg-secondary/30 rounded-lg space-y-2">
                          <p className="text-xs font-semibold">{editingMember ? 'Edit Member' : 'Add Member'}</p>
                          <div className="grid grid-cols-2 gap-2">
                            <input className="input-field text-xs" placeholder="Name *" value={memberForm.name} onChange={e => setMemberForm({...memberForm, name: e.target.value})} />
                            <input
                              className="input-field text-xs"
                              placeholder={restrictedForm ? 'Phone (contact only, no login)' : 'Phone (for login)'}
                              value={memberForm.phone}
                              onChange={e => setMemberForm({...memberForm, phone: e.target.value.replace(/\D/g, '')})}
                              maxLength={10}
                            />
                            <select className="input-field text-xs col-span-2" value={memberForm.relation} onChange={e => setMemberForm({...memberForm, relation: e.target.value, isPrimary: false})}>
                              <option value="" disabled>---Select---</option>
                              <optgroup label="Household">
                                <option value="owner">Owner</option>
                                <option value="spouse">Spouse</option>
                                <option value="son">Son</option>
                                <option value="daughter">Daughter</option>
                                <option value="father">Father</option>
                                <option value="mother">Mother</option>
                                <option value="family">Family</option>
                                <option value="tenant">Tenant</option>
                                <option value="other">Other</option>
                              </optgroup>
                              <optgroup label="Staff / service (Quick Entry)">
                                <option value="cook">Cook</option>
                                <option value="maid">Maid</option>
                                <option value="washerman">Washerman</option>
                                <option value="newspaper">Newspaper</option>
                                <option value="driver">Driver</option>
                              </optgroup>
                            </select>
                            <input className="input-field text-xs" placeholder="Age" type="number" value={memberForm.age} onChange={e => setMemberForm({...memberForm, age: e.target.value})} />
                            <select className="input-field text-xs" value={memberForm.gender} onChange={e => setMemberForm({...memberForm, gender: e.target.value})}>
                              <option value="" disabled>---Select---</option>
                              <option value="Male">Male</option>
                              <option value="Female">Female</option>
                              <option value="Other">Other</option>
                            </select>
                            {!restrictedForm && (
                              <div className="col-span-2 space-y-1">
                                <p className="text-[10px] font-medium text-muted-foreground uppercase">Profile photo (optional)</p>
                                <div className="flex flex-wrap items-center gap-2">
                                  <button type="button" onClick={() => pickIdImage('photo')} className="text-xs px-2 py-1 rounded-lg border border-border flex items-center gap-1">
                                    <Camera className="w-3 h-3" /> Upload photo
                                  </button>
                                  {memberForm.photo && <span className="text-[10px] text-green-600">✓</span>}
                                  {memberForm.photo && (
                                    <img src={memberForm.photo} alt="" className="h-10 w-10 rounded-full object-cover border border-border" />
                                  )}
                                </div>
                              </div>
                            )}
                            {restrictedForm && (
                              <>
                                <div className="col-span-2 space-y-1">
                                  <p className="text-[10px] font-medium text-muted-foreground uppercase">Photo ID (front required)</p>
                                  <div className="flex flex-wrap gap-2">
                                    <button type="button" onClick={() => pickIdImage('idPhotoFront')} className="text-xs px-2 py-1 rounded-lg border border-border flex items-center gap-1">
                                      <Camera className="w-3 h-3" /> Front
                                    </button>
                                    {memberForm.idPhotoFront && <span className="text-[10px] text-green-600">✓</span>}
                                    <button type="button" onClick={() => pickIdImage('idPhotoBack')} className="text-xs px-2 py-1 rounded-lg border border-border flex items-center gap-1">
                                      <Camera className="w-3 h-3" /> Back (optional)
                                    </button>
                                    {memberForm.idPhotoBack && <span className="text-[10px] text-green-600">✓</span>}
                                  </div>
                                </div>
                                <select
                                  className="input-field text-xs col-span-2"
                                  value={memberForm.policeVerification}
                                  onChange={e => setMemberForm({ ...memberForm, policeVerification: e.target.value })}
                                >
                                  <option value="" disabled>---Select---</option>
                                  <option value="pending">Pending</option>
                                  <option value="submitted">Submitted</option>
                                  <option value="verified">Verified</option>
                                </select>
                                <input
                                  className="input-field text-xs col-span-2"
                                  placeholder="Spouse / husband name (optional)"
                                  value={memberForm.spouseName}
                                  onChange={e => setMemberForm({ ...memberForm, spouseName: e.target.value })}
                                />
                                <hr className="col-span-2 border-border" />
                                <div className="col-span-2 space-y-2">
                                  <p className="text-[10px] font-medium text-muted-foreground uppercase">Service dates (optional)</p>
                                  <p className="text-[10px] text-muted-foreground leading-snug">
                                    When this person started / finished working for the flat (for staff, maid, driver, etc.).
                                  </p>
                                  <div className="grid grid-cols-2 gap-2">
                                    <div>
                                      <label className="text-[10px] font-medium text-muted-foreground block mb-0.5">Date of joining</label>
                                      <input
                                        className="input-field text-xs w-full"
                                        type="date"
                                        value={memberForm.dateJoining}
                                        onChange={e => setMemberForm({ ...memberForm, dateJoining: e.target.value })}
                                      />
                                    </div>
                                    <div>
                                      <label className="text-[10px] font-medium text-muted-foreground block mb-0.5">Date of leave</label>
                                      <input
                                        className="input-field text-xs w-full"
                                        type="date"
                                        value={memberForm.dateLeave}
                                        onChange={e => setMemberForm({ ...memberForm, dateLeave: e.target.value })}
                                      />
                                    </div>
                                  </div>
                                </div>
                                <hr className="col-span-2 border-border" />
                                <p className="col-span-2 text-[10px] font-medium text-muted-foreground uppercase">Vehicle (optional)</p>
                                <select
                                  className="input-field text-xs"
                                  value={memberForm.vehicleCategory}
                                  onChange={e => setMemberForm({ ...memberForm, vehicleCategory: e.target.value })}
                                >
                                  <option value="" disabled>---Select---</option>
                                  {STAFF_VEHICLE_TYPES.map((vt) => (
                                    <option key={vt} value={vt}>{vt}</option>
                                  ))}
                                </select>
                                <input
                                  className="input-field text-xs"
                                  placeholder="Vehicle name / model"
                                  value={memberForm.vehicleName}
                                  onChange={e => setMemberForm({ ...memberForm, vehicleName: e.target.value })}
                                />
                                <input
                                  className="input-field text-xs font-mono"
                                  placeholder="Registration no."
                                  value={memberForm.vehicleNumber}
                                  onChange={e => setMemberForm({ ...memberForm, vehicleNumber: e.target.value })}
                                />
                                <input
                                  className="input-field text-xs"
                                  placeholder="Color"
                                  value={memberForm.vehicleColor}
                                  onChange={e => setMemberForm({ ...memberForm, vehicleColor: e.target.value })}
                                />
                              </>
                            )}
                            {showPrimaryCheckbox && (
                              <label className="flex items-center gap-2 text-xs col-span-2">
                                <input type="checkbox" checked={memberForm.isPrimary} onChange={e => setMemberForm({...memberForm, isPrimary: e.target.checked})} className="rounded" />
                                Set as primary member
                              </label>
                            )}
                            {primary && !showPrimaryCheckbox && allowsResidentLoginAndPrimary(memberForm.relation) && (
                              <p className="text-[10px] text-muted-foreground col-span-2">
                                Primary is already set. Use ★ on a household member in the list to change it.
                              </p>
                            )}
                          </div>
                          <p className="text-[10px] text-muted-foreground">
                            {restrictedForm
                              ? '💡 Tenant, other, and staff do not get resident app login. Phone is for contact only.'
                              : '💡 Household members with a phone number get a shared flat login password.'}
                          </p>
                          <div className="flex gap-2">
                            <button type="button" onClick={() => saveMember(flat.id)} className="btn-primary flex-1 text-xs py-1.5">{editingMember ? 'Update' : 'Add'}</button>
                            <button type="button" onClick={resetMemberForm} className="btn-secondary flex-1 text-xs py-1.5">Cancel</button>
                          </div>
                        </div>
                        );
                      })()}
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
      <SensitiveAdminVerifyModal
        open={sensitiveOpen}
        title={sensitiveTitle}
        actionLabel={sensitiveActionLabel}
        adminId={verifyAdminId}
        adminName={verifyAdminName}
        onClose={() => {
          pendingSensitive.current = null;
          setSensitiveOpen(false);
        }}
        onVerified={handleSensitiveVerified}
      />
    </div>
  );
};

export default AdminResidentManager;
