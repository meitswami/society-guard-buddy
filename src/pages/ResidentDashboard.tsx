import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { Home, Bell, KeyRound, LogOut, Check, X, Clock, Plus, Copy, Calendar, Vote, DollarSign, User, Eye, EyeOff, Lock, Car, Users, Trash2, Edit2, Camera, BookUser, Sparkles, MessageSquare } from 'lucide-react';
import { format } from 'date-fns';
import { showSuccess, confirmAction } from '@/lib/swal';
import { toast } from 'sonner';
import LanguageToggle from '@/components/LanguageToggle';
import ThemeToggle from '@/components/ThemeToggle';
import BiometricSetup from '@/components/BiometricSetup';
import NotificationCenter from '@/components/NotificationCenter';
import PollManager from '@/components/PollManager';
import { auditLogout } from '@/lib/auditLogger';
import { useStore } from '@/store/useStore';
import { isRestrictedMemberCategory, STAFF_VEHICLE_TYPES } from '@/lib/memberCategories';
import { useNotificationsRealtimeRevision } from '@/hooks/useNotificationsRealtimeRevision';
import { useBiometric } from '@/hooks/useBiometric';
import { playNotificationAlert } from '@/lib/notificationSounds';
import TourGuideFirstLogin from '@/components/TourGuideFirstLogin';
import TourGuideHub from '@/components/TourGuideHub';
import ResidentFeedbackForm from '@/components/ResidentFeedbackForm';

interface Resident {
  id: string; name: string; phone: string; flatId: string; flatNumber: string;
}

interface ApprovalRequest {
  id: string; visitor_name: string; visitor_phone: string | null; flat_number: string;
  guard_name: string; purpose: string | null; status: string; created_at: string;
}

interface VisitorPass {
  id: string; otp_code: string; flat_number: string; guest_name: string | null;
  guest_phone: string | null; valid_date: string; time_slot_start: string | null;
  time_slot_end: string | null; status: string; created_by_name: string; created_at: string;
}

interface Props { resident: Resident; onLogout: () => void; }

const SERVICE_TYPES = ['Cook', 'Maid', 'Washerman', 'Newspaper', 'Driver', 'Others'] as const;
const RELATION_TYPES = ['Owner', 'Spouse', 'Son', 'Daughter', 'Father', 'Mother', 'Brother', 'Sister', 'Tenant', 'Others'] as const;

const DOC_TYPES = {
  photoId: [
    { value: 'aadhaar', label: 'Aadhaar' },
    { value: 'pan', label: 'PAN Card' },
    { value: 'passport', label: 'Passport' },
    { value: 'voter_id', label: 'Voter ID' },
    { value: 'driving_license', label: 'Driving License' },
    { value: 'other', label: 'Other' },
  ],
  tenant: [
    { value: 'rental_agreement', label: 'Rental agreement' },
    { value: 'police_verification', label: 'Police verification' },
    { value: 'other', label: 'Other' },
  ],
} as const;

const notificationSound = () => {
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain); gain.connect(ctx.destination);
    osc.frequency.value = 800; gain.gain.value = 0.3;
    osc.start(); osc.stop(ctx.currentTime + 0.3);
    setTimeout(() => {
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.connect(gain2); gain2.connect(ctx.destination);
      osc2.frequency.value = 1000; gain2.gain.value = 0.3;
      osc2.start(); osc2.stop(ctx.currentTime + 0.3);
    }, 350);
  } catch {}
};

const ResidentDashboard = ({ resident, onLogout }: Props) => {
  const { t } = useLanguage();
  const { isAvailable, register: registerBiometric } = useBiometric();
  const societyId = useStore((s) => s.societyId);
  const [loginBanners, setLoginBanners] = useState<{ id: string; image_url: string; title: string | null }[]>([]);
  const [bannerOpen, setBannerOpen] = useState(false);
  const [bannerIdx, setBannerIdx] = useState(0);
  const [bannerZoom, setBannerZoom] = useState(1);
  const pinchRef = useRef<{
    pointers: Map<number, { x: number; y: number }>;
    startDist: number;
    startZoom: number;
    pinching: boolean;
  }>({ pointers: new Map(), startDist: 0, startZoom: 1, pinching: false });

  const notificationRowForResident = (row: Record<string, unknown>) => {
    if (societyId && row.society_id && String(row.society_id) !== societyId) return false;
    const tt = String(row.target_type ?? '');
    const tid = String(row.target_id ?? '');
    if (tt === 'all') return true;
    if (tt === 'flat') {
      if (tid === resident.flatNumber) return true;
      if (tid.includes(',')) return tid.split(',').map((s) => s.trim()).includes(resident.flatNumber);
    }
    if (tt === 'user' && tid === resident.id) return true;
    return false;
  };

  const notificationFeedRevision = useNotificationsRealtimeRevision(true, `resident-${resident.id}`, {
    onNotificationInsert: (row) => {
      if (!notificationRowForResident(row)) return;
      const title = String(row.title ?? 'Alert');
      const message = String(row.message ?? '');
      toast.info(title, { description: message.slice(0, 200) || undefined, duration: 8000 });
      playNotificationAlert(
        String(row.sound_key ?? 'digital'),
        (row.sound_custom_url as string | null | undefined) ?? null,
      );
    },
  });
  const [tab, setTab] = useState<
    | 'approvals'
    | 'passes'
    | 'notifications'
    | 'polls'
    | 'payments'
    | 'family'
    | 'vehicles'
    | 'directory'
    | 'profile'
    | 'tour'
    | 'feedback'
  >('approvals');

  useEffect(() => {
    try {
      if (sessionStorage.getItem('sgb_open_family_tab') === '1') {
        sessionStorage.removeItem('sgb_open_family_tab');
        setTab('family');
        setShowAddMember(true);
      }
    } catch {
      /* ignore */
    }
  }, []);
  const [currentPass, setCurrentPass] = useState('');
  const [newPass, setNewPass] = useState('');
  const [confirmPass, setConfirmPass] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [passLoading, setPassLoading] = useState(false);
  const [flatmates, setFlatmates] = useState<any[]>([]);
  const [requests, setRequests] = useState<ApprovalRequest[]>([]);
  const [passes, setPasses] = useState<VisitorPass[]>([]);
  const [myPayments, setMyPayments] = useState<any[]>([]);
  const [showNewPass, setShowNewPass] = useState(false);
  const [passForm, setPassForm] = useState({
    guestName: '', guestPhone: '', validDate: format(new Date(), 'yyyy-MM-dd'),
    timeStart: '09:00', timeEnd: '18:00',
  });
  const prevPendingCount = useRef(0);

  // Family & servicemen state
  const [myMembers, setMyMembers] = useState<any[]>([]);
  const [showAddMember, setShowAddMember] = useState(false);
  const [editingMember, setEditingMember] = useState<any>(null);
  type MemberDocumentKind = 'photo_id' | 'tenant_doc' | 'service_doc';
  type MemberDocDraft = { kind: MemberDocumentKind; type: string; front: string; back: string };
  const [memberDocs, setMemberDocs] = useState<MemberDocDraft[]>([]);
  const [memberForm, setMemberForm] = useState({
    name: '',
    phone: '',
    relation: '',
    age: '',
    gender: '',
    isServiceman: false,
    serviceType: '',
    customServiceType: '',
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

  // Vehicles state
  const [myVehicles, setMyVehicles] = useState<any[]>([]);
  const [showAddVehicle, setShowAddVehicle] = useState(false);
  const [vehicleForm, setVehicleForm] = useState({ vehicleNumber: '', vehicleType: '' as string });

  // Directory state (all flats)
  const [allFlats, setAllFlats] = useState<any[]>([]);
  const [allMembers, setAllMembers] = useState<any[]>([]);
  const [allVehicles, setAllVehicles] = useState<any[]>([]);
  const [dirSearch, setDirSearch] = useState('');
  const [expandedFlat, setExpandedFlat] = useState<string | null>(null);
  const [residentSelfIdUploadEnabled, setResidentSelfIdUploadEnabled] = useState(false);
  const [selfIdDocs, setSelfIdDocs] = useState<MemberDocDraft[]>([]);
  const [savingSelfId, setSavingSelfId] = useState(false);
  const [mandatoryPasswordOpen, setMandatoryPasswordOpen] = useState(false);
  const [mandatoryNew, setMandatoryNew] = useState('');
  const [mandatoryConfirm, setMandatoryConfirm] = useState('');
  const [mandatorySaving, setMandatorySaving] = useState(false);

  const loadRequests = useCallback(async () => {
    const { data } = await supabase.from('approval_requests').select('*')
      .eq('flat_id', resident.flatId).order('created_at', { ascending: false }).limit(50);
    if (data) {
      const newPending = (data as ApprovalRequest[]).filter(r => r.status === 'pending').length;
      if (newPending > prevPendingCount.current && prevPendingCount.current >= 0) notificationSound();
      prevPendingCount.current = newPending;
      setRequests(data as ApprovalRequest[]);
    }
  }, [resident.flatId]);

  const loadPasses = useCallback(async () => {
    const { data } = await supabase.from('visitor_passes').select('*')
      .eq('flat_id', resident.flatId).order('created_at', { ascending: false }).limit(50);
    if (data) setPasses(data as VisitorPass[]);
  }, [resident.flatId]);

  const loadMyPayments = useCallback(async () => {
    const { data } = await supabase.from('maintenance_payments').select('*')
      .eq('flat_id', resident.flatId).order('created_at', { ascending: false }).limit(50);
    if (data) setMyPayments(data);
  }, [resident.flatId]);

  const loadFlatmates = async () => {
    const { data } = await supabase.from('resident_users').select('*').eq('flat_id', resident.flatId);
    if (data) setFlatmates(data);
  };

  const loadMyMembers = async () => {
    const { data } = await supabase.from('members').select('*').eq('flat_id', resident.flatId).order('created_at');
    if (data) setMyMembers(data);
  };

  const loadMyVehicles = async () => {
    const { data } = await supabase.from('resident_vehicles').select('*').eq('flat_id', resident.flatId).order('created_at');
    if (data) setMyVehicles(data);
  };

  const loadDirectory = async () => {
    const { data: flat } = await supabase.from('flats').select('society_id').eq('id', resident.flatId).single();
    if (!flat?.society_id) return;
    const { data: flats } = await supabase.from('flats').select('*').eq('society_id', flat.society_id).order('flat_number');
    const flatIds = (flats || []).map((f) => f.id);
    const flatNumbers = new Set((flats || []).map((f) => f.flat_number));
    const membersRes = flatIds.length
      ? await supabase
          .from('members')
          .select('id, flat_id, name, phone, relation, age, gender, photo, is_primary, created_at')
          .in('flat_id', flatIds)
      : { data: [] as any[] };
    const { data: vehicles } = flatIds.length
      ? await supabase.from('resident_vehicles').select('*').in('flat_id', flatIds)
      : { data: [] as any[] };
    const vehFiltered = (vehicles || []).filter((v) => flatNumbers.has(v.flat_number));
    if (flats) setAllFlats(flats);
    setAllMembers(membersRes.data || []);
    setAllVehicles(vehFiltered);
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data: flat } = await supabase.from('flats').select('society_id').eq('id', resident.flatId).single();
      if (!flat?.society_id || cancelled) return;
      const { data: soc } = await supabase.from('societies').select('resident_self_id_upload_enabled').eq('id', flat.society_id).single();
      if (!cancelled) setResidentSelfIdUploadEnabled(!!soc?.resident_self_id_upload_enabled);
    })();
    return () => { cancelled = true; };
  }, [resident.flatId]);

  const normPhone = (p: string) => p.replace(/\D/g, '');
  const myMemberRecord = useMemo(() => {
    const myPhone = normPhone(resident.phone || '');
    if (!myPhone) return null;
    return myMembers.find((m: any) => m.phone && normPhone(m.phone) === myPhone) || null;
  }, [myMembers, resident.phone]);

  useEffect(() => {
    if (mandatoryPasswordOpen) return;
    if (flatmates.length === 0) return;
    const self = flatmates.find((u: any) => u.id === resident.id);
    const must = !!(self as { must_change_password?: boolean })?.must_change_password;
    if (!must) return;
    setMandatoryPasswordOpen(true);
  }, [flatmates, resident.id, mandatoryPasswordOpen]);

  useEffect(() => {
    if (!residentSelfIdUploadEnabled || !myMemberRecord) {
      setSelfIdDocs([]);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data: docs } = await supabase
        .from('member_documents')
        .select('doc_kind, doc_type, front_url, back_url')
        .eq('member_id', myMemberRecord.id)
        .eq('doc_kind', 'photo_id')
        .order('created_at', { ascending: true });
      if (cancelled) return;
      if (docs && docs.length > 0) {
        setSelfIdDocs(
          docs.map((d: any) => ({
            kind: 'photo_id',
            type: String(d.doc_type || 'aadhaar'),
            front: String(d.front_url || ''),
            back: String(d.back_url || ''),
          })),
        );
        return;
      }
      // Back-compat: show legacy front/back if present (single doc).
      const front = String((myMemberRecord as any)?.id_photo_front || '');
      const back = String((myMemberRecord as any)?.id_photo_back || '');
      setSelfIdDocs(front || back ? [{ kind: 'photo_id', type: 'other', front, back }] : []);
    })();
    return () => { cancelled = true; };
  }, [residentSelfIdUploadEnabled, myMemberRecord?.id]);

  useEffect(() => { loadRequests(); loadPasses(); loadMyPayments(); loadFlatmates(); loadMyMembers(); loadMyVehicles(); loadDirectory(); }, []);

  useEffect(() => {
    if (!societyId) return;
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('society_dashboard_banners')
        .select('id, image_url, title, is_active')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: false });
      if (cancelled) return;
      const rows = (data || []) as any[];
      setLoginBanners(rows);
      const key = `sgb_seen_banner_${societyId}`;
      const seen = sessionStorage.getItem(key) === '1';
      if (!seen && rows.length > 0) {
        setBannerIdx(0);
        setBannerZoom(1);
        setBannerOpen(true);
        sessionStorage.setItem(key, '1');
      }
    })();
    return () => { cancelled = true; };
  }, [societyId]);

  const handleSaveSelfIdPhotos = async () => {
    if (!myMemberRecord?.id) return;
    if (normPhone(myMemberRecord.phone || '') !== normPhone(resident.phone || '')) {
      toast.error('Profile does not match your login');
      return;
    }
    setSavingSelfId(true);
    await supabase.from('member_documents').delete().eq('member_id', myMemberRecord.id).eq('doc_kind', 'photo_id');
    const rows = selfIdDocs
      .filter((d) => d.kind === 'photo_id' && d.type && (d.front || d.back))
      .map((d) => ({
        member_id: myMemberRecord.id,
        doc_kind: 'photo_id',
        doc_type: d.type,
        front_url: d.front || null,
        back_url: d.back || null,
      }));
    const { error } = rows.length > 0 ? await supabase.from('member_documents').insert(rows) : { error: null as any };
    setSavingSelfId(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Photo ID saved');
    loadMyMembers();
  };

  const handlePasswordChange = async () => {
    if (!currentPass || !newPass || !confirmPass) { toast.error('Fill all fields'); return; }
    if (newPass !== confirmPass) { toast.error('Passwords do not match'); return; }
    if (newPass.length < 4) { toast.error('Password must be at least 4 characters'); return; }
    setPassLoading(true);
    const { data: user } = await supabase.from('resident_users').select('id').eq('id', resident.id).eq('password', currentPass).single();
    if (!user) { toast.error('Current password is wrong'); setPassLoading(false); return; }
    await supabase.from('resident_users').update({ password: newPass, must_change_password: false }).eq('flat_id', resident.flatId);
    toast.success('Password changed for all flatmates');
    setCurrentPass(''); setNewPass(''); setConfirmPass('');
    setPassLoading(false);
    loadFlatmates();
  };

  useEffect(() => {
    const channel = supabase.channel('resident-approvals')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'approval_requests',
        filter: `flat_id=eq.${resident.flatId}` }, () => loadRequests())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [resident.flatId, loadRequests]);

  const handleApproval = async (id: string, status: 'approved' | 'rejected') => {
    const label = status === 'approved' ? t('resident.approve') : t('resident.reject');
    const confirmed = await confirmAction(label + '?', t('resident.confirmApprovalText'), t('swal.yes'), t('swal.no'));
    if (!confirmed) return;
    await supabase.from('approval_requests').update({ status, responded_at: new Date().toISOString() }).eq('id', id).eq('flat_id', resident.flatId);
    loadRequests();
    showSuccess(t('swal.success'), status === 'approved' ? t('resident.approved') : t('resident.rejected'));
  };

  const handleCreatePass = async (e: React.FormEvent) => {
    e.preventDefault();
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await supabase.from('visitor_passes').insert({
      otp_code: otp, flat_id: resident.flatId, flat_number: resident.flatNumber,
      created_by_type: 'resident', created_by_id: resident.id, created_by_name: resident.name,
      guest_name: passForm.guestName || null, guest_phone: passForm.guestPhone || null,
      valid_date: passForm.validDate, time_slot_start: passForm.timeStart, time_slot_end: passForm.timeEnd,
    });
    showSuccess(t('swal.success'), `${t('resident.passCreated')} — OTP: ${otp}`);
    setShowNewPass(false);
    setPassForm({ guestName: '', guestPhone: '', validDate: format(new Date(), 'yyyy-MM-dd'), timeStart: '09:00', timeEnd: '18:00' });
    loadPasses();
  };

  // ========== FAMILY/SERVICEMEN HANDLERS ==========
  const handlePhotoCapture = (setter: (val: string) => void) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.capture = 'environment';
    input.onchange = (e: any) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onloadend = () => setter(reader.result as string);
      reader.readAsDataURL(file);
    };
    input.click();
  };

  const syncResidentStaffVehicle = async (memberId: string) => {
    const { data: existing } = await supabase.from('resident_vehicles').select('id').eq('member_id', memberId).maybeSingle();
    const num = memberForm.vehicleNumber.trim();
    const hasVehicle = num.length > 0 || memberForm.vehicleName.trim().length > 0;
    if (!hasVehicle) {
      if (existing?.id) await supabase.from('resident_vehicles').delete().eq('id', existing.id);
      return;
    }
    const row = {
      society_id: societyId,
      flat_id: resident.flatId,
      flat_number: resident.flatNumber,
      resident_name: memberForm.name,
      vehicle_number: num || 'N/A',
      vehicle_type: memberForm.vehicleCategory || 'other',
      vehicle_display_name: memberForm.vehicleName.trim() || null,
      vehicle_color: memberForm.vehicleColor.trim() || null,
      member_id: memberId,
    };
    if (existing?.id) await supabase.from('resident_vehicles').update(row).eq('id', existing.id);
    else await supabase.from('resident_vehicles').insert(row);
  };

  const emptyMemberForm = () => ({
    name: '',
    phone: '',
    relation: '',
    age: '',
    gender: '',
    isServiceman: false,
    serviceType: '',
    customServiceType: '',
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

  const handleAddMember = async () => {
    if (!memberForm.name) { toast.error('Name is required'); return; }
    if (memberForm.isServiceman) {
      if (!memberForm.serviceType) { toast.error('Please select a service type'); return; }
    } else if (!memberForm.relation) {
      toast.error('Please select a relation');
      return;
    }
    const relationRaw = memberForm.isServiceman
      ? (memberForm.serviceType === 'Others' ? memberForm.customServiceType || 'others' : memberForm.serviceType)
      : (memberForm.relation === 'Others' ? 'others' : memberForm.relation);
    const relNorm = relationRaw.toLowerCase();
    const restricted = isRestrictedMemberCategory(relNorm);
    const isTenant = relNorm === 'tenant';
    const photoIdDocs = memberDocs.filter((d) => d.kind === 'photo_id' && !!d.front);
    const tenantDocs = memberDocs.filter((d) => d.kind === 'tenant_doc' && !!d.front);
    const legacyFront = String(editingMember?.id_photo_front || '');
    const hasAnyPhotoId = photoIdDocs.length > 0 || !!legacyFront || !!memberForm.idPhotoFront || !!memberForm.photo;
    if (restricted || isTenant) {
      if (isTenant && !hasAnyPhotoId) {
        toast.error('Tenant: at least 1 Photo ID is required');
        return;
      }
      if (isTenant && tenantDocs.length === 0) {
        toast.error('Tenant: rental agreement is required');
        return;
      }
      if (!isTenant && !hasAnyPhotoId) {
        toast.error('Photo ID is required for restricted categories (tenant/other/service)');
        return;
      }
    }

    const payload: Record<string, unknown> = {
      flat_id: resident.flatId,
      name: memberForm.name,
      phone: memberForm.phone || null,
      relation: relNorm,
      household_group:
        relNorm === 'tenant' || String((myMemberRecord as any)?.household_group || '') === 'tenant' ? 'tenant' : 'owner',
      age: memberForm.age ? parseInt(memberForm.age, 10) : null,
      gender: memberForm.gender || null,
      photo: memberForm.photo || null,
      is_primary: false,
    };

    if (restricted || isTenant) {
      const bestPhotoId = memberDocs.find((d) => d.kind === 'photo_id' && !!d.front) ?? null;
      const idFront = bestPhotoId?.front || memberForm.idPhotoFront || memberForm.photo || null;
      payload.id_photo_front = idFront;
      payload.id_photo_back = bestPhotoId?.back || memberForm.idPhotoBack || null;
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

    const prev = editingMember;

    if (prev?.phone && (restricted || !memberForm.phone || memberForm.phone !== prev.phone)) {
      await supabase.from('resident_users').delete().eq('phone', prev.phone).eq('flat_id', resident.flatId);
    }
    if (restricted && memberForm.phone) {
      await supabase.from('resident_users').delete().eq('phone', memberForm.phone).eq('flat_id', resident.flatId);
    }

    let memberId: string | null = prev?.id ?? null;

    if (editingMember) {
      await supabase.from('members').update(payload).eq('id', editingMember.id);
      toast.success('Member updated');
      memberId = editingMember.id;
    } else {
      const { data: ins, error } = await supabase.from('members').insert(payload).select('id').single();
      if (error || !ins) {
        toast.error(error?.message || 'Could not add member');
        return;
      }
      memberId = ins.id;
      if (!restricted && memberForm.phone) {
        const { data: existing } = await supabase.from('resident_users').select('id').eq('phone', memberForm.phone).maybeSingle();
        if (!existing) {
          const { data: flatmate } = await supabase.from('resident_users').select('password').eq('flat_id', resident.flatId).limit(1).maybeSingle();
          const pw = flatmate?.password || 'Welcome123!';
          await supabase.from('resident_users').insert({
            phone: memberForm.phone, name: memberForm.name, password: pw,
            flat_id: resident.flatId, flat_number: resident.flatNumber,
          });
        }
      }
      toast.success('Member added');
    }

    if (memberId) {
      await supabase.from('member_documents').delete().eq('member_id', memberId);
      const rows = memberDocs
        .filter((d) => d.type && (d.front || d.back))
        .map((d) => ({
          member_id: memberId,
          doc_kind: d.kind,
          doc_type: d.type,
          front_url: d.front || null,
          back_url: d.back || null,
        }));
      if (rows.length > 0) await supabase.from('member_documents').insert(rows);
    }

    if (restricted && memberId) await syncResidentStaffVehicle(memberId);
    else if (memberId) {
      const { data: vdel } = await supabase.from('resident_vehicles').select('id').eq('member_id', memberId).maybeSingle();
      if (vdel?.id) await supabase.from('resident_vehicles').delete().eq('id', vdel.id);
    }

    setMemberForm(emptyMemberForm());
    setMemberDocs([]);
    setShowAddMember(false);
    setEditingMember(null);
    loadMyMembers();
    loadDirectory();
    useStore.getState().loadResidentVehicles();
  };

  const handleDeleteMember = async (member: any) => {
    if (member.is_primary) { toast.error('Cannot delete primary member'); return; }
    const confirmed = await confirmAction('Delete member?', `Remove ${member.name}?`, 'Yes', 'No');
    if (!confirmed) return;
    await supabase.from('resident_vehicles').delete().eq('member_id', member.id);
    await supabase.from('members').delete().eq('id', member.id);
    if (member.phone) {
      await supabase.from('resident_users').delete().eq('phone', member.phone).eq('flat_id', resident.flatId);
    }
    showSuccess('Removed!', 'Member removed successfully');
    loadMyMembers();
    loadDirectory();
  };

  const startEditMember = async (m: any) => {
    const isService = SERVICE_TYPES.map(s => s.toLowerCase()).includes(m.relation?.toLowerCase());
    const relLower = (m.relation || '').toLowerCase();
    const relationCap = RELATION_TYPES.find((r) => r.toLowerCase() === relLower) || 'Spouse';
    const gNorm = (m.gender || '').trim().toLowerCase();
    const genderVal = gNorm === 'male' || gNorm === 'female' || gNorm === 'other' ? gNorm : '';
    setEditingMember(m);
    setMemberDocs([]);
    setMemberForm({
      name: m.name,
      phone: m.phone || '',
      relation: isService ? 'Spouse' : relationCap,
      age: m.age?.toString() || '',
      gender: genderVal,
      isServiceman: isService,
      serviceType: isService ? SERVICE_TYPES.find(s => s.toLowerCase() === m.relation?.toLowerCase()) || 'Others' : '',
      customServiceType: '',
      photo: m.photo || '',
      idPhotoFront: m.id_photo_front || '',
      idPhotoBack: m.id_photo_back || '',
      policeVerification: m.police_verification || '',
      spouseName: m.spouse_name || '',
      dateJoining: m.date_joining || '',
      dateLeave: m.date_leave || '',
      vehicleCategory: '',
      vehicleName: '',
      vehicleNumber: '',
      vehicleColor: '',
    });
    const { data: docs } = await supabase
      .from('member_documents')
      .select('doc_kind, doc_type, front_url, back_url')
      .eq('member_id', m.id)
      .order('created_at', { ascending: true });
    if (docs && docs.length > 0) {
      setMemberDocs(
        docs.map((d: any) => ({
          kind: (d.doc_kind as MemberDocumentKind) || 'photo_id',
          type: String(d.doc_type || 'other'),
          front: String(d.front_url || ''),
          back: String(d.back_url || ''),
        })),
      );
    }
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
    setShowAddMember(true);
  };

  // ========== VEHICLE HANDLERS ==========
  const handleAddVehicle = async () => {
    if (!vehicleForm.vehicleNumber) { toast.error('Vehicle number required'); return; }
    if (!vehicleForm.vehicleType) { toast.error('Please select a vehicle type'); return; }
    await supabase.from('resident_vehicles').insert({
      society_id: societyId,
      flat_number: resident.flatNumber, flat_id: resident.flatId,
      resident_name: resident.name, vehicle_number: vehicleForm.vehicleNumber.toUpperCase(),
      vehicle_type: vehicleForm.vehicleType,
    });
    toast.success('Vehicle added');
    setVehicleForm({ vehicleNumber: '', vehicleType: '' });
    setShowAddVehicle(false);
    loadMyVehicles();
    loadDirectory();
  };

  const handleDeleteVehicle = async (v: any) => {
    const confirmed = await confirmAction('Delete vehicle?', `Remove ${v.vehicle_number}?`, 'Yes', 'No');
    if (!confirmed) return;
    await supabase.from('resident_vehicles').delete().eq('id', v.id).eq('flat_id', resident.flatId);
    showSuccess('Removed!', 'Vehicle removed successfully');
    loadMyVehicles();
    loadDirectory();
  };

  const copyOTP = (code: string) => { navigator.clipboard.writeText(code); showSuccess('Copied!', code); };
  const pendingRequests = requests.filter(r => r.status === 'pending');

  const handleMandatoryPasswordSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!mandatoryNew || !mandatoryConfirm) {
      toast.error('Enter new password and confirmation');
      return;
    }
    if (mandatoryNew !== mandatoryConfirm) {
      toast.error('Passwords do not match');
      return;
    }
    if (mandatoryNew.length < 4) {
      toast.error('Password must be at least 4 characters');
      return;
    }
    setMandatorySaving(true);
    const { error } = await supabase
      .from('resident_users')
      .update({ password: mandatoryNew, must_change_password: false })
      .eq('flat_id', resident.flatId);
    setMandatorySaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Password set for all flatmates');
    setMandatoryPasswordOpen(false);
    setMandatoryNew('');
    setMandatoryConfirm('');
    await loadFlatmates();

    const bioOk = await isAvailable();
    if (bioOk) {
      const enroll = await confirmAction(
        t('resident.mandatoryBioTitle'),
        t('resident.mandatoryBioBody'),
        t('swal.yes'),
        t('swal.no'),
      );
      if (enroll) {
        const regOk = await registerBiometric('resident', resident.id, resident.name);
        if (regOk) toast.success(t('biometric.registered'));
        else toast.error(t('biometric.registerFailed'));
      }
    }
  };

  const handleLogout = async () => {
    const confirmed = await confirmAction(
      t('swal.confirmLogoutUser'),
      t('swal.confirmLogoutUserText'),
      t('swal.yes'),
      t('swal.no'),
    );
    if (confirmed) {
      auditLogout('resident', resident.id, resident.name);
      onLogout();
    }
  };

  // Directory filtering
  const filteredDirFlats = allFlats.filter(f => {
    if (!dirSearch.trim()) return true;
    const q = dirSearch.toLowerCase();
    return f.flat_number?.toLowerCase().includes(q) || f.owner_name?.toLowerCase().includes(q) || f.owner_phone?.includes(q);
  });

  const tabItems = [
    { id: 'approvals' as const, label: t('resident.approvals'), icon: Bell, badge: pendingRequests.length },
    { id: 'passes' as const, label: t('resident.passes'), icon: KeyRound },
    { id: 'family' as const, label: 'Family', icon: Users },
    { id: 'vehicles' as const, label: 'Vehicles', icon: Car },
    { id: 'directory' as const, label: 'Directory', icon: BookUser },
    { id: 'notifications' as const, label: 'Alerts', icon: Bell },
    { id: 'polls' as const, label: 'Polls', icon: Vote },
    { id: 'payments' as const, label: 'Payments', icon: DollarSign },
    { id: 'profile' as const, label: 'Profile', icon: User },
    { id: 'tour' as const, label: t('nav.tour'), icon: Sparkles },
    { id: 'feedback' as const, label: 'Feedback', icon: MessageSquare },
  ];

  return (
    <div className="min-h-screen bg-background pb-20">
      {bannerOpen && loginBanners.length > 0 && (
        <div className="fixed inset-0 z-[90] bg-black/60 flex items-center justify-center p-4">
          <div className="w-full max-w-3xl rounded-2xl bg-card border border-border overflow-hidden shadow-xl">
            <div className="relative">
              <div
                className="w-full bg-muted overflow-auto"
                style={{ maxHeight: '75vh', touchAction: 'none' }}
                onPointerDown={(e) => {
                  // Only handle touch/pen for pinch. Mouse wheel/drag should just scroll.
                  if (e.pointerType === 'mouse') return;
                  (e.currentTarget as HTMLDivElement).setPointerCapture(e.pointerId);
                  pinchRef.current.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
                  if (pinchRef.current.pointers.size === 2) {
                    const pts = Array.from(pinchRef.current.pointers.values());
                    const dx = pts[0].x - pts[1].x;
                    const dy = pts[0].y - pts[1].y;
                    pinchRef.current.startDist = Math.hypot(dx, dy) || 1;
                    pinchRef.current.startZoom = bannerZoom;
                    pinchRef.current.pinching = true;
                  }
                }}
                onPointerMove={(e) => {
                  if (e.pointerType === 'mouse') return;
                  if (!pinchRef.current.pointers.has(e.pointerId)) return;
                  pinchRef.current.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
                  if (pinchRef.current.pointers.size !== 2) return;
                  const pts = Array.from(pinchRef.current.pointers.values());
                  const dx = pts[0].x - pts[1].x;
                  const dy = pts[0].y - pts[1].y;
                  const dist = Math.hypot(dx, dy) || 1;
                  const ratio = dist / (pinchRef.current.startDist || 1);
                  const next = Math.max(1, Math.min(3, pinchRef.current.startZoom * ratio));
                  // Avoid spamming state updates with tiny changes.
                  setBannerZoom((z) => (Math.abs(z - next) < 0.01 ? z : Math.round(next * 100) / 100));
                  e.preventDefault();
                }}
                onPointerUp={(e) => {
                  if (e.pointerType === 'mouse') return;
                  pinchRef.current.pointers.delete(e.pointerId);
                  if (pinchRef.current.pointers.size < 2) {
                    pinchRef.current.pinching = false;
                    pinchRef.current.startDist = 0;
                    pinchRef.current.startZoom = bannerZoom;
                  }
                }}
                onPointerCancel={(e) => {
                  if (e.pointerType === 'mouse') return;
                  pinchRef.current.pointers.delete(e.pointerId);
                  if (pinchRef.current.pointers.size < 2) {
                    pinchRef.current.pinching = false;
                    pinchRef.current.startDist = 0;
                    pinchRef.current.startZoom = bannerZoom;
                  }
                }}
              >
                <img
                  src={loginBanners[bannerIdx]?.image_url}
                  alt={loginBanners[bannerIdx]?.title || 'Banner'}
                  className="w-full object-contain bg-muted origin-center"
                  style={{
                    maxHeight: '75vh',
                    transform: `scale(${bannerZoom})`,
                    touchAction: 'none',
                  }}
                />
              </div>
              <button
                type="button"
                onClick={() => {
                  setBannerOpen(false);
                  setBannerZoom(1);
                }}
                className="absolute top-2 right-2 rounded-lg bg-black/40 text-white px-2 py-1 text-xs"
              >
                Close
              </button>
              <div className="absolute bottom-2 right-2 flex items-center gap-1 rounded-lg bg-black/40 text-white px-2 py-1">
                <button
                  type="button"
                  onClick={() => setBannerZoom((z) => Math.max(1, Math.round((z - 0.25) * 100) / 100))}
                  className="px-2 py-1 text-xs"
                  aria-label="Zoom out"
                >
                  −
                </button>
                <span className="text-[10px] tabular-nums">{Math.round(bannerZoom * 100)}%</span>
                <button
                  type="button"
                  onClick={() => setBannerZoom((z) => Math.min(3, Math.round((z + 0.25) * 100) / 100))}
                  className="px-2 py-1 text-xs"
                  aria-label="Zoom in"
                >
                  +
                </button>
              </div>
              {loginBanners.length > 1 && (
                <>
                  <button
                    type="button"
                    onClick={() => {
                      setBannerZoom(1);
                      setBannerIdx((i) => (i - 1 + loginBanners.length) % loginBanners.length);
                    }}
                    className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-black/40 text-white px-2 py-1 text-sm"
                    aria-label="Previous banner"
                  >
                    ‹
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setBannerZoom(1);
                      setBannerIdx((i) => (i + 1) % loginBanners.length);
                    }}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-black/40 text-white px-2 py-1 text-sm"
                    aria-label="Next banner"
                  >
                    ›
                  </button>
                </>
              )}
            </div>
            {(loginBanners[bannerIdx]?.title || loginBanners.length > 1) && (
              <div className="p-3 flex items-center justify-between gap-2">
                <p className="text-sm font-medium truncate">{loginBanners[bannerIdx]?.title || ' '}</p>
                {loginBanners.length > 1 && (
                  <p className="text-[10px] text-muted-foreground">
                    {bannerIdx + 1}/{loginBanners.length}
                  </p>
                )}
              </div>
            )}
          </div>
        </div>
      )}
      {!mandatoryPasswordOpen && <TourGuideFirstLogin role="resident" userId={resident.id} t={t} />}
      {mandatoryPasswordOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-background/95 p-4">
          <form
            onSubmit={handleMandatoryPasswordSave}
            className="w-full max-w-sm rounded-2xl border border-border bg-card p-5 shadow-lg space-y-4"
          >
            <div>
              <h2 className="text-lg font-semibold">{t('resident.mandatoryPasswordTitle')}</h2>
              <p className="text-xs text-muted-foreground mt-2 leading-relaxed">{t('resident.mandatoryPasswordSubtitle')}</p>
              <p className="text-[11px] text-muted-foreground/90 mt-2 leading-relaxed">{t('resident.mandatoryPasswordNoCurrent')}</p>
              <p className="text-[11px] text-muted-foreground/90 mt-1 leading-relaxed">{t('resident.mandatoryPasswordBioHint')}</p>
            </div>
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider block mb-1">
                {t('resident.mandatoryPasswordNew')}
              </label>
              <input
                type="password"
                className="input-field w-full"
                value={mandatoryNew}
                onChange={(e) => setMandatoryNew(e.target.value)}
                autoComplete="new-password"
                required
              />
            </div>
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider block mb-1">
                {t('resident.mandatoryPasswordConfirm')}
              </label>
              <input
                type="password"
                className="input-field w-full"
                value={mandatoryConfirm}
                onChange={(e) => setMandatoryConfirm(e.target.value)}
                autoComplete="new-password"
                required
              />
            </div>
            <button type="submit" className="btn-primary w-full" disabled={mandatorySaving}>
              {mandatorySaving ? 'Saving…' : t('resident.mandatoryPasswordSave')}
            </button>
          </form>
        </div>
      )}
      {/* Header */}
      <div className="bg-card border-b border-border px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Home className="w-5 h-5 text-primary" />
            </div>
            <div>
              <p className="text-sm font-semibold text-foreground">{resident.name}</p>
              <p className="text-xs text-muted-foreground">{t('common.flat')} {resident.flatNumber}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {pendingRequests.length > 0 && (
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
                <span className="relative inline-flex rounded-full h-3 w-3 bg-destructive" />
              </span>
            )}
            <LanguageToggle />
            <ThemeToggle />
            <button onClick={handleLogout} className="p-2 text-muted-foreground hover:text-destructive">
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 px-4 pt-4 overflow-x-auto scrollbar-hide">
        {tabItems.map(ti => (
          <button key={ti.id} onClick={() => setTab(ti.id)}
            className={`px-3 py-2 rounded-lg text-xs font-medium flex items-center gap-1.5 whitespace-nowrap ${tab === ti.id ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
            <ti.icon className="w-3.5 h-3.5" />
            {ti.label}
            {ti.badge ? <span className="bg-destructive text-destructive-foreground text-[10px] px-1.5 rounded-full">{ti.badge}</span> : null}
          </button>
        ))}
      </div>

      <div className="px-4 pt-4">
        {/* ========== APPROVALS TAB ========== */}
        {tab === 'approvals' && (
          <div className="flex flex-col gap-3">
            {pendingRequests.length > 0 && (
              <div className="card-section border-warning/30">
                <p className="text-sm font-semibold text-warning mb-3">🔔 {t('resident.pendingApprovals')}</p>
                {pendingRequests.map(req => (
                  <div key={req.id} className="bg-background rounded-lg p-3 mb-2 border border-border">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <p className="font-semibold text-sm text-foreground">{req.visitor_name}</p>
                        {req.visitor_phone && <p className="text-xs text-muted-foreground font-mono">{req.visitor_phone}</p>}
                        {req.purpose && <p className="text-xs text-muted-foreground">{req.purpose}</p>}
                      </div>
                      <p className="text-[10px] text-muted-foreground">{format(new Date(req.created_at), 'HH:mm')}</p>
                    </div>
                    <p className="text-xs text-muted-foreground mb-2">{t('logs.guard')}: {req.guard_name}</p>
                    <div className="flex gap-2">
                      <button onClick={() => handleApproval(req.id, 'approved')}
                        className="flex-1 flex items-center justify-center gap-1 py-2 bg-green-600 text-white rounded-lg text-sm font-medium">
                        <Check className="w-4 h-4" /> {t('resident.approve')}
                      </button>
                      <button onClick={() => handleApproval(req.id, 'rejected')}
                        className="flex-1 flex items-center justify-center gap-1 py-2 bg-destructive text-destructive-foreground rounded-lg text-sm font-medium">
                        <X className="w-4 h-4" /> {t('resident.reject')}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
            <p className="text-xs text-muted-foreground uppercase tracking-wider">{t('resident.history')}</p>
            {requests.filter(r => r.status !== 'pending').length === 0 && (
              <p className="text-sm text-muted-foreground text-center py-8">{t('resident.noHistory')}</p>
            )}
            {requests.filter(r => r.status !== 'pending').map(req => (
              <div key={req.id} className="card-section flex justify-between items-center">
                <div>
                  <p className="text-sm font-medium text-foreground">{req.visitor_name}</p>
                  <p className="text-xs text-muted-foreground">{format(new Date(req.created_at), 'dd MMM HH:mm')}</p>
                </div>
                <span className={`text-xs px-2 py-1 rounded-full font-medium ${req.status === 'approved' ? 'bg-green-500/20 text-green-600' : 'bg-destructive/20 text-destructive'}`}>
                  {req.status === 'approved' ? t('resident.approved') : t('resident.rejected')}
                </span>
              </div>
            ))}
          </div>
        )}

        {/* ========== PASSES TAB ========== */}
        {tab === 'passes' && (
          <div className="flex flex-col gap-3">
            <button onClick={() => setShowNewPass(!showNewPass)} className="btn-primary flex items-center justify-center gap-2">
              <Plus className="w-4 h-4" /> {t('resident.createPass')}
            </button>
            {showNewPass && (
              <form onSubmit={handleCreatePass} className="card-section flex flex-col gap-3">
                <input className="input-field" placeholder={t('resident.guestName')} value={passForm.guestName}
                  onChange={e => setPassForm(f => ({ ...f, guestName: e.target.value }))} />
                <input className="input-field font-mono" placeholder={t('resident.guestPhone')} type="tel" maxLength={10}
                  value={passForm.guestPhone} onChange={e => setPassForm(f => ({ ...f, guestPhone: e.target.value.replace(/\D/g, '') }))} />
                <div>
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">{t('resident.validDate')}</label>
                  <input className="input-field" type="date" value={passForm.validDate}
                    onChange={e => setPassForm(f => ({ ...f, validDate: e.target.value }))} />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">{t('resident.from')}</label>
                    <input className="input-field" type="time" value={passForm.timeStart}
                      onChange={e => setPassForm(f => ({ ...f, timeStart: e.target.value }))} />
                  </div>
                  <div>
                    <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">{t('resident.to')}</label>
                    <input className="input-field" type="time" value={passForm.timeEnd}
                      onChange={e => setPassForm(f => ({ ...f, timeEnd: e.target.value }))} />
                  </div>
                </div>
                <button type="submit" className="btn-primary">{t('resident.generateOTP')}</button>
              </form>
            )}
            {passes.length === 0 && !showNewPass && (
              <p className="text-sm text-muted-foreground text-center py-8">{t('resident.noPasses')}</p>
            )}
            {passes.map(pass => (
              <div key={pass.id} className={`card-section ${pass.status === 'active' ? 'border-primary/30' : 'opacity-60'}`}>
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-lg font-bold text-primary tracking-widest">{pass.otp_code}</span>
                      {pass.status === 'active' && (
                        <button onClick={() => copyOTP(pass.otp_code)} className="text-muted-foreground hover:text-primary">
                          <Copy className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                    {pass.guest_name && <p className="text-sm text-foreground">{pass.guest_name}</p>}
                    {pass.guest_phone && <p className="text-xs text-muted-foreground font-mono">{pass.guest_phone}</p>}
                  </div>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${
                    pass.status === 'active' ? 'bg-green-500/20 text-green-600' :
                    pass.status === 'used' ? 'bg-secondary text-secondary-foreground' :
                    'bg-destructive/20 text-destructive'
                  }`}>{pass.status}</span>
                </div>
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  <Clock className="w-3 h-3" />
                  <span>{pass.valid_date} · {pass.time_slot_start?.slice(0, 5)} – {pass.time_slot_end?.slice(0, 5)}</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ========== FAMILY & SERVICEMEN TAB ========== */}
        {tab === 'family' && (
          <div className="flex flex-col gap-3">
            <div className="flex justify-between items-center">
              <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">My Family & Staff ({myMembers.length})</p>
              <button onClick={() => { setShowAddMember(true); setEditingMember(null); setMemberForm(emptyMemberForm()); }}
                className="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium flex items-center gap-1">
                <Plus className="w-3 h-3" /> Add
              </button>
            </div>

            {showAddMember && (
              <div className="card-section p-4 flex flex-col gap-3">
                <p className="text-sm font-semibold">{editingMember ? 'Edit Member' : 'Add Member'}</p>

                {/* Type toggle */}
                <div className="flex gap-2">
                  <button onClick={() => setMemberForm(f => ({ ...f, isServiceman: false }))}
                    className={`flex-1 py-2 rounded-lg text-xs font-medium ${!memberForm.isServiceman ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
                    👨‍👩‍👧‍👦 Family
                  </button>
                  <button onClick={() => setMemberForm(f => ({ ...f, isServiceman: true }))}
                    className={`flex-1 py-2 rounded-lg text-xs font-medium ${memberForm.isServiceman ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
                    🧹 Serviceman
                  </button>
                </div>

                <input className="input-field" placeholder="Full Name *" value={memberForm.name}
                  onChange={e => setMemberForm(f => ({ ...f, name: e.target.value }))} />
                <input
                  className="input-field font-mono"
                  placeholder={
                    memberForm.isServiceman || memberForm.relation === 'Tenant' || memberForm.relation === 'Others'
                      ? 'Phone (contact only — no app login)'
                      : 'Phone (optional, for shared flat login)'
                  }
                  type="tel"
                  maxLength={10}
                  value={memberForm.phone}
                  onChange={e => setMemberForm(f => ({ ...f, phone: e.target.value.replace(/\D/g, '') }))}
                />

                {!memberForm.isServiceman ? (
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Relation</label>
                    <select className="input-field" value={memberForm.relation}
                      onChange={e => setMemberForm(f => ({ ...f, relation: e.target.value }))}>
                      <option value="" disabled>---Select---</option>
                      {RELATION_TYPES.map(r => <option key={r} value={r}>{r}</option>)}
                    </select>
                  </div>
                ) : (
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Service Type</label>
                    <select className="input-field" value={memberForm.serviceType}
                      onChange={e => setMemberForm(f => ({ ...f, serviceType: e.target.value }))}>
                      <option value="" disabled>---Select---</option>
                      {SERVICE_TYPES.map(s => <option key={s} value={s}>{s}</option>)}
                    </select>
                    {memberForm.serviceType === 'Others' && (
                      <input className="input-field mt-2" placeholder="Specify type..." value={memberForm.customServiceType}
                        onChange={e => setMemberForm(f => ({ ...f, customServiceType: e.target.value }))} />
                    )}
                  </div>
                )}

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Age</label>
                    <input className="input-field" type="number" placeholder="Age" value={memberForm.age}
                      onChange={e => setMemberForm(f => ({ ...f, age: e.target.value }))} />
                  </div>
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Gender</label>
                    <select className="input-field" value={memberForm.gender}
                      onChange={e => setMemberForm(f => ({ ...f, gender: e.target.value }))}>
                      <option value="" disabled>---Select---</option>
                      <option value="male">Male</option>
                      <option value="female">Female</option>
                      <option value="other">Other</option>
                    </select>
                  </div>
                </div>

                {!memberForm.isServiceman && memberForm.relation !== 'Tenant' && memberForm.relation !== 'Others' && (
                  <div className="space-y-2 border border-border/60 rounded-lg p-3 bg-secondary/10">
                    <p className="text-[10px] font-medium text-muted-foreground uppercase">Profile photo (optional)</p>
                    <div className="flex flex-wrap items-center gap-2">
                      <button
                        type="button"
                        onClick={() => handlePhotoCapture((val) => setMemberForm((f) => ({ ...f, photo: val })))}
                        className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                      >
                        <Camera className="w-3.5 h-3.5" /> Upload photo
                      </button>
                      {memberForm.photo && <span className="text-[10px] text-green-600">✓</span>}
                      {memberForm.photo && (
                        <img src={memberForm.photo} alt="" className="h-12 w-12 rounded-full object-cover border border-border" />
                      )}
                    </div>
                  </div>
                )}

                {(memberForm.isServiceman || memberForm.relation === 'Tenant' || memberForm.relation === 'Others') && (
                  <div className="space-y-2 border border-border/60 rounded-lg p-3 bg-secondary/20">
                    <p className="text-[10px] text-muted-foreground">
                      Tenant, other, and staff are not given resident app login. Add ID and optional details below.
                    </p>
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] font-medium text-muted-foreground uppercase">Photo ID uploads</p>
                      <button
                        type="button"
                        onClick={() => setMemberDocs((d) => [...d, { kind: 'photo_id', type: 'aadhaar', front: '', back: '' }])}
                        className="text-xs bg-primary/10 text-primary px-2 py-1 rounded-lg font-medium flex items-center gap-1"
                      >
                        <Plus className="w-3 h-3" /> Add ID
                      </button>
                    </div>
                    <div className="space-y-2">
                      {memberDocs.filter((d) => d.kind === 'photo_id').length === 0 && (
                        <p className="text-[10px] text-muted-foreground">No Photo IDs added yet.</p>
                      )}
                      {memberDocs.map((d, idx) => d.kind !== 'photo_id' ? null : (
                        <div key={`pid-${idx}`} className="rounded-lg border border-border bg-background/50 p-2 space-y-2">
                          <div className="flex items-center gap-2">
                            <select
                              className="input-field text-sm flex-1"
                              value={d.type}
                              onChange={(e) => setMemberDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, type: e.target.value }) : x))}
                            >
                              {DOC_TYPES.photoId.map((opt) => (
                                <option key={opt.value} value={opt.value}>{opt.label}</option>
                              ))}
                            </select>
                            <button
                              type="button"
                              onClick={() => setMemberDocs((prev) => prev.filter((_, i) => i !== idx))}
                              className="p-2 text-muted-foreground hover:text-destructive"
                              title="Remove"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                          <div className="flex flex-wrap gap-2 items-center">
                            <button
                              type="button"
                              onClick={() => {
                                const input = document.createElement('input');
                                input.type = 'file';
                                input.accept = 'image/*';
                                input.capture = 'environment';
                                input.onchange = (e: any) => {
                                  const file = e.target.files[0];
                                  if (!file) return;
                                  const reader = new FileReader();
                                  reader.onloadend = () => {
                                    const val = String(reader.result ?? '');
                                    setMemberDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, front: val }) : x));
                                  };
                                  reader.readAsDataURL(file);
                                };
                                input.click();
                              }}
                              className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                            >
                              <Camera className="w-3.5 h-3.5" /> Front
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                const input = document.createElement('input');
                                input.type = 'file';
                                input.accept = 'image/*';
                                input.capture = 'environment';
                                input.onchange = (e: any) => {
                                  const file = e.target.files[0];
                                  if (!file) return;
                                  const reader = new FileReader();
                                  reader.onloadend = () => {
                                    const val = String(reader.result ?? '');
                                    setMemberDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, back: val }) : x));
                                  };
                                  reader.readAsDataURL(file);
                                };
                                input.click();
                              }}
                              className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                            >
                              <Camera className="w-3.5 h-3.5" /> Back
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                    {String(memberForm.relation || '').toLowerCase() === 'tenant' && (
                      <div className="space-y-2 pt-1">
                        <div className="flex items-center justify-between">
                          <p className="text-[10px] font-medium text-muted-foreground uppercase">Tenant documents (mandatory)</p>
                          <button
                            type="button"
                            onClick={() => setMemberDocs((d) => [...d, { kind: 'tenant_doc', type: 'rental_agreement', front: '', back: '' }])}
                            className="text-xs bg-primary/10 text-primary px-2 py-1 rounded-lg font-medium flex items-center gap-1"
                          >
                            <Plus className="w-3 h-3" /> Add doc
                          </button>
                        </div>
                        {memberDocs.map((d, idx) => d.kind !== 'tenant_doc' ? null : (
                          <div key={`td-${idx}`} className="rounded-lg border border-border bg-background/50 p-2 space-y-2">
                            <div className="flex items-center gap-2">
                              <select
                                className="input-field text-sm flex-1"
                                value={d.type}
                                onChange={(e) => setMemberDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, type: e.target.value }) : x))}
                              >
                                {DOC_TYPES.tenant.map((opt) => (
                                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                                ))}
                              </select>
                              <button
                                type="button"
                                onClick={() => setMemberDocs((prev) => prev.filter((_, i) => i !== idx))}
                                className="p-2 text-muted-foreground hover:text-destructive"
                                title="Remove"
                              >
                                <X className="w-4 h-4" />
                              </button>
                            </div>
                            <button
                              type="button"
                              onClick={() => {
                                const input = document.createElement('input');
                                input.type = 'file';
                                input.accept = 'image/*';
                                input.capture = 'environment';
                                input.onchange = (e: any) => {
                                  const file = e.target.files[0];
                                  if (!file) return;
                                  const reader = new FileReader();
                                  reader.onloadend = () => {
                                    const val = String(reader.result ?? '');
                                    setMemberDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, front: val }) : x));
                                  };
                                  reader.readAsDataURL(file);
                                };
                                input.click();
                              }}
                              className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                            >
                              <Camera className="w-3.5 h-3.5" /> Upload
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                    <select
                      className="input-field text-sm"
                      value={memberForm.policeVerification}
                      onChange={(e) => setMemberForm((f) => ({ ...f, policeVerification: e.target.value }))}
                    >
                      <option value="" disabled>---Select---</option>
                      <option value="pending">Pending</option>
                      <option value="submitted">Submitted</option>
                      <option value="verified">Verified</option>
                    </select>
                    <input
                      className="input-field text-sm"
                      placeholder="Spouse / husband name (optional)"
                      value={memberForm.spouseName}
                      onChange={(e) => setMemberForm((f) => ({ ...f, spouseName: e.target.value }))}
                    />
                    <hr className="border-border" />
                    <div className="space-y-2">
                      <p className="text-[10px] font-medium text-muted-foreground uppercase">Service dates (optional)</p>
                      <p className="text-[10px] text-muted-foreground leading-snug">
                        When this person started / finished working for your flat (e.g. staff start date, last working day).
                      </p>
                      <div className="grid grid-cols-2 gap-2">
                        <div>
                          <label className="text-[10px] font-medium text-muted-foreground mb-0.5 block">Date of joining</label>
                          <input className="input-field text-sm w-full" type="date" value={memberForm.dateJoining}
                            onChange={(e) => setMemberForm((f) => ({ ...f, dateJoining: e.target.value }))} />
                        </div>
                        <div>
                          <label className="text-[10px] font-medium text-muted-foreground mb-0.5 block">Date of leave</label>
                          <input className="input-field text-sm w-full" type="date" value={memberForm.dateLeave}
                            onChange={(e) => setMemberForm((f) => ({ ...f, dateLeave: e.target.value }))} />
                        </div>
                      </div>
                    </div>
                    <hr className="border-border" />
                    <p className="text-[10px] font-medium text-muted-foreground uppercase">Vehicle (optional)</p>
                    <div className="grid grid-cols-2 gap-2">
                      <select
                        className="input-field text-sm"
                        value={memberForm.vehicleCategory}
                        onChange={(e) => setMemberForm((f) => ({ ...f, vehicleCategory: e.target.value }))}
                      >
                        <option value="" disabled>---Select---</option>
                        {STAFF_VEHICLE_TYPES.map((vt) => (
                          <option key={vt} value={vt}>{vt}</option>
                        ))}
                      </select>
                      <input className="input-field text-sm" placeholder="Vehicle name" value={memberForm.vehicleName}
                        onChange={(e) => setMemberForm((f) => ({ ...f, vehicleName: e.target.value }))} />
                      <input className="input-field text-sm font-mono" placeholder="Registration no." value={memberForm.vehicleNumber}
                        onChange={(e) => setMemberForm((f) => ({ ...f, vehicleNumber: e.target.value }))} />
                      <input className="input-field text-sm" placeholder="Color" value={memberForm.vehicleColor}
                        onChange={(e) => setMemberForm((f) => ({ ...f, vehicleColor: e.target.value }))} />
                    </div>
                  </div>
                )}

                <div className="flex gap-2">
                  <button onClick={handleAddMember} className="btn-primary flex-1">
                    {editingMember ? 'Update' : 'Add Member'}
                  </button>
                  <button onClick={() => { setShowAddMember(false); setEditingMember(null); setMemberForm(emptyMemberForm()); }}
                    className="px-4 py-2 rounded-lg bg-secondary text-secondary-foreground text-sm">Cancel</button>
                </div>
              </div>
            )}

            {myMembers.length === 0 && !showAddMember && (
              <p className="text-sm text-muted-foreground text-center py-8">No members added yet</p>
            )}
            {(() => {
              const groupOf = (m: any) => {
                const g = String(m.household_group || '').trim().toLowerCase();
                if (g === 'owner' || g === 'tenant') return g;
                return String(m.relation || '').trim().toLowerCase() === 'tenant' ? 'tenant' : 'owner';
              };
              const ownerGroup = myMembers.filter((m) => groupOf(m) === 'owner');
              const tenantGroup = myMembers.filter((m) => groupOf(m) === 'tenant');
              const renderMember = (m: any) => {
                const isService = SERVICE_TYPES.map(s => s.toLowerCase()).includes(m.relation?.toLowerCase());
                return (
                  <div key={m.id} className="card-section p-3 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 overflow-hidden">
                      {m.photo ? <img src={m.photo} alt={m.name} className="w-full h-full object-cover" /> :
                        <span className="text-sm font-bold text-primary">{m.name.charAt(0)}</span>}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">
                        {m.name}
                        {m.is_primary && <span className="ml-1 text-[9px] text-primary">★ Primary</span>}
                      </p>
                      <p className="text-[10px] text-muted-foreground capitalize">
                        {isService ? `🧹 ${m.relation}` : m.relation}
                        {m.age ? ` · ${m.age}y` : ''}{m.gender ? ` · ${m.gender}` : ''}
                        {m.phone ? ` · 📱${m.phone}` : ''}
                      </p>
                    </div>
                    {!m.is_primary && (
                      <div className="flex gap-1 flex-shrink-0">
                        <button onClick={() => startEditMember(m)} className="p-1.5 text-muted-foreground hover:text-primary">
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button onClick={() => handleDeleteMember(m)} className="p-1.5 text-muted-foreground hover:text-destructive">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    )}
                  </div>
                );
              };
              return (
                <div className="space-y-2">
                  <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium">Owner group ({ownerGroup.length})</p>
                  {ownerGroup.map(renderMember)}
                  <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mt-2">Tenant group ({tenantGroup.length})</p>
                  {tenantGroup.map(renderMember)}
                </div>
              );
            })()}
          </div>
        )}

        {/* ========== VEHICLES TAB ========== */}
        {tab === 'vehicles' && (
          <div className="flex flex-col gap-3">
            <div className="flex justify-between items-center">
              <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">My Vehicles ({myVehicles.length})</p>
              <button onClick={() => setShowAddVehicle(true)}
                className="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium flex items-center gap-1">
                <Plus className="w-3 h-3" /> Add
              </button>
            </div>

            {showAddVehicle && (
              <div className="card-section p-4 flex flex-col gap-3">
                <p className="text-sm font-semibold">Add Vehicle</p>
                <input className="input-field font-mono uppercase" placeholder="Vehicle Number (e.g. MH04AB1234)"
                  value={vehicleForm.vehicleNumber} onChange={e => setVehicleForm(f => ({ ...f, vehicleNumber: e.target.value }))} />
                <select className="input-field" value={vehicleForm.vehicleType}
                  onChange={e => setVehicleForm(f => ({ ...f, vehicleType: e.target.value }))}>
                  <option value="" disabled>---Select---</option>
                  <option value="car">🚗 Car</option>
                  <option value="bike">🏍️ Bike</option>
                  <option value="other">🚐 Other</option>
                </select>
                <div className="flex gap-2">
                  <button onClick={handleAddVehicle} className="btn-primary flex-1">Add Vehicle</button>
                  <button onClick={() => setShowAddVehicle(false)}
                    className="px-4 py-2 rounded-lg bg-secondary text-secondary-foreground text-sm">Cancel</button>
                </div>
              </div>
            )}

            {myVehicles.length === 0 && !showAddVehicle && (
              <p className="text-sm text-muted-foreground text-center py-8">No vehicles registered</p>
            )}
            {myVehicles.map(v => (
              <div key={v.id} className="card-section p-3 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
                    <Car className="w-5 h-5 text-primary" />
                  </div>
                  <div>
                    <p className="text-sm font-mono font-semibold">{v.vehicle_number}</p>
                    <p className="text-[10px] text-muted-foreground capitalize">{v.vehicle_type}</p>
                  </div>
                </div>
                <button onClick={() => handleDeleteVehicle(v)} className="p-1.5 text-muted-foreground hover:text-destructive">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}

        {/* ========== DIRECTORY TAB ========== */}
        {tab === 'directory' && (
          <div className="flex flex-col gap-3">
            <div className="relative">
              <input className="input-field pl-9" placeholder="Search flats, names, phone..."
                value={dirSearch} onChange={e => setDirSearch(e.target.value)} />
              <BookUser className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
            </div>
            <p className="text-[10px] text-muted-foreground">{filteredDirFlats.length} flats · You can only edit your own flat's data</p>

            {filteredDirFlats.map(flat => {
              const isMyFlat = flat.id === resident.flatId;
              const flatMembers = allMembers.filter((m: any) => m.flat_id === flat.id);
              const flatVehicles = allVehicles.filter((v: any) => v.flat_number === flat.flat_number);
              const isExpanded = expandedFlat === flat.id;

              return (
                <div key={flat.id} className={`card-section ${isMyFlat ? 'border-primary/30' : ''}`}>
                  <button type="button" className="w-full flex items-center gap-3 text-left"
                    onClick={() => setExpandedFlat(isExpanded ? null : flat.id)}>
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${isMyFlat ? 'bg-primary/20' : 'bg-primary/10'}`}>
                      <Home className={`w-5 h-5 ${isMyFlat ? 'text-primary' : 'text-muted-foreground'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="text-sm font-semibold font-mono">{flat.flat_number}</p>
                        {isMyFlat && <span className="text-[9px] bg-primary/20 text-primary px-1.5 py-0.5 rounded">My Flat</span>}
                        {flat.wing && <span className="text-[10px] bg-secondary px-1.5 py-0.5 rounded text-secondary-foreground">Wing {flat.wing}</span>}
                      </div>
                      <p className="text-xs text-muted-foreground truncate">{flat.owner_name || 'No owner'} · {flatMembers.length} members · {flatVehicles.length} vehicles</p>
                    </div>
                  </button>

                  {isExpanded && (
                    <div className="mt-3 pt-3 border-t border-border space-y-2">
                      {flatMembers.map((m: any) => (
                        <div key={m.id} className="flex items-center gap-2 bg-secondary/50 rounded-lg px-2.5 py-1.5">
                          <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-[10px] font-bold text-primary flex-shrink-0 overflow-hidden">
                            {m.photo ? <img src={m.photo} alt="" className="w-full h-full object-cover" /> : m.name.charAt(0)}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-xs font-medium truncate">
                              {m.name} {m.is_primary && <span className="text-[9px] text-primary">★</span>}
                            </p>
                            <p className="text-[10px] text-muted-foreground capitalize">
                              {m.relation}{m.age ? ` · ${m.age}y` : ''}{m.phone ? ` · 📱${m.phone}` : ''}
                            </p>
                          </div>
                        </div>
                      ))}
                      {flatVehicles.length > 0 && (
                        <div className="flex flex-wrap gap-1.5 pt-1">
                          {flatVehicles.map((v: any) => (
                            <span key={v.id} className="flex items-center gap-1 bg-secondary/50 rounded-lg px-2.5 py-1.5 text-xs">
                              <Car className="w-3 h-3 text-muted-foreground" />
                              <span className="font-mono font-medium">{v.vehicle_number}</span>
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {tab === 'notifications' && (
          <NotificationCenter
            isResident
            flatNumber={resident.flatNumber}
            resident={{ id: resident.id, name: resident.name, flatNumber: resident.flatNumber }}
            societyId={societyId}
            feedRevision={notificationFeedRevision}
          />
        )}

        {tab === 'polls' && (
          <PollManager isResident voterId={resident.id} flatNumber={resident.flatNumber} />
        )}

        {tab === 'payments' && (
          <div className="flex flex-col gap-3">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">My Payment History</p>
            {myPayments.length === 0 && <p className="text-sm text-muted-foreground text-center py-8">No payment records</p>}
            {myPayments.map(p => (
              <div key={p.id} className="card-section p-3">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="text-sm font-medium">₹{p.amount}</p>
                    <p className="text-xs text-muted-foreground">{p.payment_method} · {new Date(p.created_at).toLocaleDateString()}</p>
                    {p.notes && <p className="text-[10px] text-muted-foreground">{p.notes}</p>}
                  </div>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full ${
                    p.payment_status === 'verified' ? 'bg-green-500/20 text-green-600' :
                    p.payment_status === 'rejected' ? 'bg-destructive/20 text-destructive' :
                    'bg-amber-500/20 text-amber-600'
                  }`}>{p.payment_status}</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ========== PROFILE TAB ========== */}
        {tab === 'profile' && (
          <div className="flex flex-col gap-4">
            <div className="card-section p-4">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <User className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <p className="font-semibold text-foreground">{resident.name}</p>
                  <p className="text-xs text-muted-foreground">Flat {resident.flatNumber} · 📱 {resident.phone}</p>
                </div>
              </div>
              {flatmates.length > 1 && (
                <div>
                  <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mb-1.5">Flatmates (shared login)</p>
                  <div className="space-y-1">
                    {flatmates.filter(f => f.id !== resident.id).map((f: any) => (
                      <p key={f.id} className="text-xs text-muted-foreground">📱 {f.phone} — {f.name}</p>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {residentSelfIdUploadEnabled && (
              <div className="card-section p-4">
                <p className="text-sm font-semibold mb-1">Your Photo ID</p>
                <p className="text-[10px] text-muted-foreground mb-3 leading-relaxed">
                  Upload or update the ID images for your own member record only (linked to your login phone). Other flats never see this here.
                </p>
                {!myMemberRecord && (
                  <p className="text-xs text-amber-600 dark:text-amber-500">
                    No household member row matches your login phone. Ask the society admin to set your phone on your member profile so you can upload ID.
                  </p>
                )}
                {myMemberRecord && (
                  <div className="flex flex-col gap-3">
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] font-medium text-muted-foreground uppercase">Photo ID uploads</p>
                      <button
                        type="button"
                        onClick={() => setSelfIdDocs((d) => [...d, { kind: 'photo_id', type: 'aadhaar', front: '', back: '' }])}
                        className="text-xs bg-primary/10 text-primary px-2 py-1 rounded-lg font-medium flex items-center gap-1"
                      >
                        <Plus className="w-3 h-3" /> Add ID
                      </button>
                    </div>
                    <div className="space-y-2">
                      {selfIdDocs.length === 0 && (
                        <p className="text-[10px] text-muted-foreground">No Photo IDs added yet.</p>
                      )}
                      {selfIdDocs.map((d, idx) => (
                        <div key={`sid-${idx}`} className="rounded-lg border border-border bg-background/50 p-2 space-y-2">
                          <div className="flex items-center gap-2">
                            <select
                              className="input-field text-sm flex-1"
                              value={d.type}
                              onChange={(e) => setSelfIdDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, type: e.target.value }) : x))}
                            >
                              {DOC_TYPES.photoId.map((opt) => (
                                <option key={opt.value} value={opt.value}>{opt.label}</option>
                              ))}
                            </select>
                            <button
                              type="button"
                              onClick={() => setSelfIdDocs((prev) => prev.filter((_, i) => i !== idx))}
                              className="p-2 text-muted-foreground hover:text-destructive"
                              title="Remove"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                          <div className="flex flex-wrap gap-2 items-center">
                            <button
                              type="button"
                              onClick={() => {
                                const input = document.createElement('input');
                                input.type = 'file';
                                input.accept = 'image/*';
                                input.capture = 'environment';
                                input.onchange = (e: any) => {
                                  const file = e.target.files[0];
                                  if (!file) return;
                                  const reader = new FileReader();
                                  reader.onloadend = () => {
                                    const val = String(reader.result ?? '');
                                    setSelfIdDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, front: val }) : x));
                                  };
                                  reader.readAsDataURL(file);
                                };
                                input.click();
                              }}
                              className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                            >
                              <Camera className="w-3.5 h-3.5" /> Front
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                const input = document.createElement('input');
                                input.type = 'file';
                                input.accept = 'image/*';
                                input.capture = 'environment';
                                input.onchange = (e: any) => {
                                  const file = e.target.files[0];
                                  if (!file) return;
                                  const reader = new FileReader();
                                  reader.onloadend = () => {
                                    const val = String(reader.result ?? '');
                                    setSelfIdDocs((prev) => prev.map((x, i) => i === idx ? ({ ...x, back: val }) : x));
                                  };
                                  reader.readAsDataURL(file);
                                };
                                input.click();
                              }}
                              className="text-xs px-3 py-2 rounded-lg border border-border flex items-center gap-1"
                            >
                              <Camera className="w-3.5 h-3.5" /> Back
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                    <button
                      type="button"
                      onClick={handleSaveSelfIdPhotos}
                      disabled={savingSelfId}
                      className="btn-primary text-sm self-start"
                    >
                      {savingSelfId ? 'Saving…' : 'Save Photo ID'}
                    </button>
                  </div>
                )}
              </div>
            )}

            <div className="card-section p-4">
              <div className="flex items-center gap-2 mb-3">
                <Lock className="w-4 h-4 text-primary" />
                <p className="text-sm font-semibold">Change Password</p>
              </div>
              <p className="text-[10px] text-muted-foreground mb-3">⚠️ Changing password will update it for all flatmates</p>
              <div className="flex flex-col gap-2.5">
                <div className="relative">
                  <input className="input-field pr-10 text-sm" type={showPass ? 'text' : 'password'}
                    placeholder="Current Password" value={currentPass} onChange={e => setCurrentPass(e.target.value)} />
                  <button type="button" className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                    onClick={() => setShowPass(!showPass)}>
                    {showPass ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
                <input className="input-field text-sm" type={showPass ? 'text' : 'password'}
                  placeholder="New Password" value={newPass} onChange={e => setNewPass(e.target.value)} />
                <input className="input-field text-sm" type={showPass ? 'text' : 'password'}
                  placeholder="Confirm New Password" value={confirmPass} onChange={e => setConfirmPass(e.target.value)} />
                <button onClick={handlePasswordChange} className="btn-primary text-sm" disabled={passLoading}>
                  {passLoading ? 'Changing...' : 'Change Password'}
                </button>
              </div>
            </div>

            <BiometricSetup userId={resident.id} userType="resident" userName={resident.name} />
          </div>
        )}

        {tab === 'tour' && <TourGuideHub role="resident" t={t} />}

        {tab === 'feedback' && <ResidentFeedbackForm resident={resident} societyId={societyId} />}
      </div>
    </div>
  );
};

export default ResidentDashboard;
