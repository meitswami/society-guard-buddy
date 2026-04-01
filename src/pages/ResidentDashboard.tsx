import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { Home, Bell, KeyRound, LogOut, Check, X, Clock, Plus, Copy, Calendar, Vote, DollarSign, User, Eye, EyeOff, Lock, Car, Users, Trash2, Edit2, Camera, BookUser } from 'lucide-react';
import { format } from 'date-fns';
import { showSuccess, confirmAction } from '@/lib/swal';
import { toast } from 'sonner';
import LanguageToggle from '@/components/LanguageToggle';
import ThemeToggle from '@/components/ThemeToggle';
import BiometricSetup from '@/components/BiometricSetup';
import NotificationCenter from '@/components/NotificationCenter';
import PollManager from '@/components/PollManager';
import { auditLogout } from '@/lib/auditLogger';

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
  const [tab, setTab] = useState<'approvals' | 'passes' | 'notifications' | 'polls' | 'payments' | 'family' | 'vehicles' | 'directory' | 'profile'>('approvals');
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
  const [memberForm, setMemberForm] = useState({ name: '', phone: '', relation: 'Spouse', age: '', gender: 'male', isServiceman: false, serviceType: '', customServiceType: '', photo: '' });

  // Vehicles state
  const [myVehicles, setMyVehicles] = useState<any[]>([]);
  const [showAddVehicle, setShowAddVehicle] = useState(false);
  const [vehicleForm, setVehicleForm] = useState({ vehicleNumber: '', vehicleType: 'car' as string });

  // Directory state (all flats)
  const [allFlats, setAllFlats] = useState<any[]>([]);
  const [allMembers, setAllMembers] = useState<any[]>([]);
  const [allVehicles, setAllVehicles] = useState<any[]>([]);
  const [dirSearch, setDirSearch] = useState('');
  const [expandedFlat, setExpandedFlat] = useState<string | null>(null);

  const loadRequests = useCallback(async () => {
    const { data } = await supabase.from('approval_requests').select('*')
      .eq('flat_number', resident.flatNumber).order('created_at', { ascending: false }).limit(50);
    if (data) {
      const newPending = (data as ApprovalRequest[]).filter(r => r.status === 'pending').length;
      if (newPending > prevPendingCount.current && prevPendingCount.current >= 0) notificationSound();
      prevPendingCount.current = newPending;
      setRequests(data as ApprovalRequest[]);
    }
  }, [resident.flatNumber]);

  const loadPasses = useCallback(async () => {
    const { data } = await supabase.from('visitor_passes').select('*')
      .eq('flat_number', resident.flatNumber).order('created_at', { ascending: false }).limit(50);
    if (data) setPasses(data as VisitorPass[]);
  }, [resident.flatNumber]);

  const loadMyPayments = useCallback(async () => {
    const { data } = await supabase.from('maintenance_payments').select('*')
      .eq('flat_number', resident.flatNumber).order('created_at', { ascending: false }).limit(50);
    if (data) setMyPayments(data);
  }, [resident.flatNumber]);

  const loadFlatmates = async () => {
    const { data } = await supabase.from('resident_users').select('*').eq('flat_id', resident.flatId);
    if (data) setFlatmates(data);
  };

  const loadMyMembers = async () => {
    const { data } = await supabase.from('members').select('*').eq('flat_id', resident.flatId).order('created_at');
    if (data) setMyMembers(data);
  };

  const loadMyVehicles = async () => {
    const { data } = await supabase.from('resident_vehicles').select('*').eq('flat_number', resident.flatNumber).order('created_at');
    if (data) setMyVehicles(data);
  };

  const loadDirectory = async () => {
    // Get society_id from flat
    const { data: flat } = await supabase.from('flats').select('society_id').eq('id', resident.flatId).single();
    if (!flat?.society_id) return;
    const { data: flats } = await supabase.from('flats').select('*').eq('society_id', flat.society_id).order('flat_number');
    const { data: members } = await supabase.from('members').select('*');
    const { data: vehicles } = await supabase.from('resident_vehicles').select('*');
    if (flats) setAllFlats(flats);
    if (members) setAllMembers(members);
    if (vehicles) setAllVehicles(vehicles);
  };

  useEffect(() => { loadRequests(); loadPasses(); loadMyPayments(); loadFlatmates(); loadMyMembers(); loadMyVehicles(); loadDirectory(); }, []);

  const handlePasswordChange = async () => {
    if (!currentPass || !newPass || !confirmPass) { toast.error('Fill all fields'); return; }
    if (newPass !== confirmPass) { toast.error('Passwords do not match'); return; }
    if (newPass.length < 4) { toast.error('Password must be at least 4 characters'); return; }
    setPassLoading(true);
    const { data: user } = await supabase.from('resident_users').select('id').eq('id', resident.id).eq('password', currentPass).single();
    if (!user) { toast.error('Current password is wrong'); setPassLoading(false); return; }
    await supabase.from('resident_users').update({ password: newPass }).eq('flat_id', resident.flatId);
    toast.success('Password changed for all flatmates');
    setCurrentPass(''); setNewPass(''); setConfirmPass('');
    setPassLoading(false);
    loadFlatmates();
  };

  useEffect(() => {
    const channel = supabase.channel('resident-approvals')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'approval_requests',
        filter: `flat_number=eq.${resident.flatNumber}` }, () => loadRequests())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [resident.flatNumber, loadRequests]);

  const handleApproval = async (id: string, status: 'approved' | 'rejected') => {
    const label = status === 'approved' ? t('resident.approve') : t('resident.reject');
    const confirmed = await confirmAction(label + '?', t('resident.confirmApprovalText'), t('swal.yes'), t('swal.no'));
    if (!confirmed) return;
    await supabase.from('approval_requests').update({ status, responded_at: new Date().toISOString() }).eq('id', id);
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

  const handleAddMember = async () => {
    if (!memberForm.name) { toast.error('Name is required'); return; }
    const relation = memberForm.isServiceman
      ? (memberForm.serviceType === 'Others' ? memberForm.customServiceType || 'Others' : memberForm.serviceType)
      : (memberForm.relation === 'Others' ? 'Others' : memberForm.relation);

    const payload = {
      flat_id: resident.flatId,
      name: memberForm.name,
      phone: memberForm.phone || null,
      relation: relation.toLowerCase(),
      age: memberForm.age ? parseInt(memberForm.age) : null,
      gender: memberForm.gender || null,
      photo: memberForm.photo || null,
      is_primary: false,
    };

    if (editingMember) {
      await supabase.from('members').update(payload).eq('id', editingMember.id);
      toast.success('Member updated');
    } else {
      await supabase.from('members').insert(payload);
      // Also create resident_user login if phone provided
      if (memberForm.phone) {
        const { data: existing } = await supabase.from('resident_users').select('id').eq('phone', memberForm.phone).single();
        if (!existing) {
          const { data: flatmate } = await supabase.from('resident_users').select('password').eq('flat_id', resident.flatId).limit(1).single();
          const pw = flatmate?.password || 'Welcome123!';
          await supabase.from('resident_users').insert({
            phone: memberForm.phone, name: memberForm.name, password: pw,
            flat_id: resident.flatId, flat_number: resident.flatNumber,
          });
        }
      }
      toast.success('Member added');
    }

    setMemberForm({ name: '', phone: '', relation: 'Spouse', age: '', gender: 'male', isServiceman: false, serviceType: '', customServiceType: '', photo: '' });
    setShowAddMember(false);
    setEditingMember(null);
    loadMyMembers();
    loadDirectory();
  };

  const handleDeleteMember = async (member: any) => {
    if (member.is_primary) { toast.error('Cannot delete primary member'); return; }
    const confirmed = await confirmAction('Delete member?', `Remove ${member.name}?`, 'Yes', 'No');
    if (!confirmed) return;
    await supabase.from('members').delete().eq('id', member.id);
    if (member.phone) {
      await supabase.from('resident_users').delete().eq('phone', member.phone).eq('flat_id', resident.flatId);
    }
    toast.success('Member removed');
    loadMyMembers();
    loadDirectory();
  };

  const startEditMember = (m: any) => {
    const isService = SERVICE_TYPES.map(s => s.toLowerCase()).includes(m.relation?.toLowerCase());
    setEditingMember(m);
    setMemberForm({
      name: m.name, phone: m.phone || '', relation: isService ? 'Spouse' : (m.relation || 'Spouse'),
      age: m.age?.toString() || '', gender: m.gender || 'male',
      isServiceman: isService,
      serviceType: isService ? SERVICE_TYPES.find(s => s.toLowerCase() === m.relation?.toLowerCase()) || 'Others' : '',
      customServiceType: '', photo: m.photo || '',
    });
    setShowAddMember(true);
  };

  // ========== VEHICLE HANDLERS ==========
  const handleAddVehicle = async () => {
    if (!vehicleForm.vehicleNumber) { toast.error('Vehicle number required'); return; }
    await supabase.from('resident_vehicles').insert({
      flat_number: resident.flatNumber, flat_id: resident.flatId,
      resident_name: resident.name, vehicle_number: vehicleForm.vehicleNumber.toUpperCase(),
      vehicle_type: vehicleForm.vehicleType,
    });
    toast.success('Vehicle added');
    setVehicleForm({ vehicleNumber: '', vehicleType: 'car' });
    setShowAddVehicle(false);
    loadMyVehicles();
    loadDirectory();
  };

  const handleDeleteVehicle = async (v: any) => {
    const confirmed = await confirmAction('Delete vehicle?', `Remove ${v.vehicle_number}?`, 'Yes', 'No');
    if (!confirmed) return;
    await supabase.from('resident_vehicles').delete().eq('id', v.id);
    toast.success('Vehicle removed');
    loadMyVehicles();
    loadDirectory();
  };

  const copyOTP = (code: string) => { navigator.clipboard.writeText(code); showSuccess('Copied!', code); };
  const pendingRequests = requests.filter(r => r.status === 'pending');

  const handleLogout = async () => {
    const confirmed = await confirmAction(t('swal.confirmLogout'), t('swal.confirmLogoutText'), t('swal.yes'), t('swal.no'));
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
  ];

  return (
    <div className="min-h-screen bg-background pb-20">
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
              <button onClick={() => { setShowAddMember(true); setEditingMember(null); setMemberForm({ name: '', phone: '', relation: 'Spouse', age: '', gender: 'male', isServiceman: false, serviceType: '', customServiceType: '', photo: '' }); }}
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
                <input className="input-field font-mono" placeholder="Phone (optional)" type="tel" maxLength={10}
                  value={memberForm.phone} onChange={e => setMemberForm(f => ({ ...f, phone: e.target.value.replace(/\D/g, '') }))} />

                {!memberForm.isServiceman ? (
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Relation</label>
                    <select className="input-field" value={memberForm.relation}
                      onChange={e => setMemberForm(f => ({ ...f, relation: e.target.value }))}>
                      {RELATION_TYPES.map(r => <option key={r} value={r}>{r}</option>)}
                    </select>
                  </div>
                ) : (
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">Service Type</label>
                    <select className="input-field" value={memberForm.serviceType}
                      onChange={e => setMemberForm(f => ({ ...f, serviceType: e.target.value }))}>
                      <option value="">Select...</option>
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
                      <option value="male">Male</option>
                      <option value="female">Female</option>
                      <option value="other">Other</option>
                    </select>
                  </div>
                </div>

                {/* Photo (for servicemen ID) */}
                {memberForm.isServiceman && (
                  <div>
                    <label className="text-xs text-muted-foreground mb-1 block">ID Photo</label>
                    {memberForm.photo ? (
                      <div className="relative w-24 h-24">
                        <img src={memberForm.photo} alt="ID" className="w-24 h-24 rounded-lg object-cover border border-border" />
                        <button onClick={() => setMemberForm(f => ({ ...f, photo: '' }))}
                          className="absolute -top-1 -right-1 bg-destructive text-destructive-foreground rounded-full w-5 h-5 flex items-center justify-center text-xs">×</button>
                      </div>
                    ) : (
                      <button onClick={() => handlePhotoCapture(val => setMemberForm(f => ({ ...f, photo: val })))}
                        className="w-full py-3 rounded-lg border-2 border-dashed border-border flex items-center justify-center gap-2 text-sm text-muted-foreground hover:border-primary/50">
                        <Camera className="w-4 h-4" /> Capture ID Photo
                      </button>
                    )}
                  </div>
                )}

                <div className="flex gap-2">
                  <button onClick={handleAddMember} className="btn-primary flex-1">
                    {editingMember ? 'Update' : 'Add Member'}
                  </button>
                  <button onClick={() => { setShowAddMember(false); setEditingMember(null); }}
                    className="px-4 py-2 rounded-lg bg-secondary text-secondary-foreground text-sm">Cancel</button>
                </div>
              </div>
            )}

            {myMembers.length === 0 && !showAddMember && (
              <p className="text-sm text-muted-foreground text-center py-8">No members added yet</p>
            )}
            {myMembers.map(m => {
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
            })}
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
          <NotificationCenter isResident flatNumber={resident.flatNumber} />
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
      </div>
    </div>
  );
};

export default ResidentDashboard;
