import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { Home, Bell, KeyRound, LogOut, Check, X, Clock, Plus, Copy, Calendar, Vote, DollarSign, User, Eye, EyeOff, Lock } from 'lucide-react';
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
  const [tab, setTab] = useState<'approvals' | 'passes' | 'notifications' | 'polls' | 'payments' | 'profile'>('approvals');
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

  useEffect(() => { loadRequests(); loadPasses(); loadMyPayments(); loadFlatmates(); }, [loadRequests, loadPasses, loadMyPayments]);

  const loadFlatmates = async () => {
    const { data } = await supabase.from('resident_users').select('*').eq('flat_id', resident.flatId);
    if (data) setFlatmates(data);
  };

  const handlePasswordChange = async () => {
    if (!currentPass || !newPass || !confirmPass) { toast.error('Fill all fields'); return; }
    if (newPass !== confirmPass) { toast.error('Passwords do not match'); return; }
    if (newPass.length < 4) { toast.error('Password must be at least 4 characters'); return; }

    setPassLoading(true);
    // Verify current password
    const { data: user } = await supabase.from('resident_users').select('id').eq('id', resident.id).eq('password', currentPass).single();
    if (!user) { toast.error('Current password is wrong'); setPassLoading(false); return; }

    // Update password for ALL flatmates (shared password)
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

  const copyOTP = (code: string) => { navigator.clipboard.writeText(code); showSuccess('Copied!', code); };
  const pendingRequests = requests.filter(r => r.status === 'pending');

  const handleLogout = async () => {
    const confirmed = await confirmAction(t('swal.confirmLogout'), t('swal.confirmLogoutText'), t('swal.yes'), t('swal.no'));
    if (confirmed) {
      auditLogout('resident', resident.id, resident.name);
      onLogout();
    }
  };

  const tabItems = [
    { id: 'approvals' as const, label: t('resident.approvals'), icon: Bell, badge: pendingRequests.length },
    { id: 'passes' as const, label: t('resident.passes'), icon: KeyRound },
    { id: 'notifications' as const, label: 'Notifications', icon: Bell },
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
      <div className="flex gap-1 px-4 pt-4 overflow-x-auto">
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
      </div>
    </div>
  );
};

export default ResidentDashboard;
