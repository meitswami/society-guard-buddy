import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Shield, Plus, Trash2, Eye, EyeOff, KeyRound, Upload, FileImage, AlertTriangle, Phone } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import { auditPasswordReset } from '@/lib/auditLogger';

interface GuardRow {
  id: string; guard_id: string; name: string; password: string;
  auth_mode: string; police_verification: string; police_verification_date: string | null;
  kyc_alert_days: number; phone: string | null;
}

interface GuardDoc {
  id: string; guard_id: string; doc_label: string; front_url: string | null; back_url: string | null;
}

const AdminGuardManager = () => {
  const { t } = useLanguage();
  const { societyId } = useStore();
  const [guards, setGuards] = useState<GuardRow[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [guardId, setGuardId] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [authMode, setAuthMode] = useState('password');
  const [policeVerification, setPoliceVerification] = useState('pending');
  const [kycAlertDays, setKycAlertDays] = useState(7);
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});
  const [resetId, setResetId] = useState<string | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [expandedGuard, setExpandedGuard] = useState<string | null>(null);
  const [guardDocs, setGuardDocs] = useState<Record<string, GuardDoc[]>>({});
  const [docLabel, setDocLabel] = useState('Aadhaar Card');
  const [uploadingDoc, setUploadingDoc] = useState(false);
  const [editingGuard, setEditingGuard] = useState<string | null>(null);
  const [editFields, setEditFields] = useState<Partial<GuardRow>>({});

  useEffect(() => { loadGuards(); }, []);

  const loadGuards = async () => {
    let query = supabase.from('guards').select('*').order('guard_id');
    if (societyId) query = query.eq('society_id', societyId);
    const { data } = await query;
    if (data) {
      setGuards(data as any);
      // Load docs for each guard
      const ids = data.map(g => g.id);
      if (ids.length > 0) {
        const { data: docs } = await supabase.from('guard_documents').select('*').in('guard_id', ids);
        if (docs) {
          const grouped: Record<string, GuardDoc[]> = {};
          docs.forEach((d: any) => {
            if (!grouped[d.guard_id]) grouped[d.guard_id] = [];
            grouped[d.guard_id].push(d);
          });
          setGuardDocs(grouped);
        }
      }
    }
  };

  const addGuard = async () => {
    if (!guardId || !name) return;
    if (authMode === 'password' && !password) { toast.error('Password required for password login'); return; }
    if (authMode === 'otp' && !phone) { toast.error('Phone required for OTP login'); return; }

    await supabase.from('guards').insert({
      guard_id: guardId.toUpperCase(), name, password: password || 'OTP_AUTH',
      society_id: societyId || null, auth_mode: authMode,
      police_verification: policeVerification, kyc_alert_days: kycAlertDays,
      phone: phone || null,
    });
    setGuardId(''); setName(''); setPassword(''); setPhone('');
    setAuthMode('password'); setPoliceVerification('pending');
    setKycAlertDays(7); setShowForm(false);
    loadGuards();
    showSuccess(t('swal.success'), t('admin.guardAdded'));
  };

  const deleteGuard = async (id: string, gid: string) => {
    const confirmed = await confirmAction(t('swal.confirmDelete'), `Delete guard ${gid}?`, t('swal.yes'), t('swal.no'));
    if (confirmed) {
      await supabase.from('guards').delete().eq('id', id);
      loadGuards();
    }
  };

  const resetGuardPassword = async (id: string) => {
    if (!newPassword || newPassword.length < 4) { toast.error(t('admin.passwordTooShort')); return; }
    await supabase.from('guards').update({ password: newPassword }).eq('id', id);
    auditPasswordReset('guard', id, 'guard', 'admin');
    toast.success(t('admin.passwordChanged'));
    setResetId(null); setNewPassword(''); loadGuards();
  };

  const updateGuard = async (id: string) => {
    const updates: any = { ...editFields };
    await supabase.from('guards').update(updates).eq('id', id);
    toast.success('Guard updated');
    setEditingGuard(null); setEditFields({});
    loadGuards();
  };

  const uploadDoc = async (guardId: string, file: File, side: 'front' | 'back', existingDocId?: string) => {
    setUploadingDoc(true);
    const path = `${guardId}/${Date.now()}_${side}_${file.name}`;
    const { data: uploaded, error } = await supabase.storage.from('guard-documents').upload(path, file);
    if (error) { toast.error('Upload failed'); setUploadingDoc(false); return; }
    const { data: { publicUrl } } = supabase.storage.from('guard-documents').getPublicUrl(path);

    if (existingDocId) {
      await supabase.from('guard_documents').update({ [`${side}_url`]: publicUrl }).eq('id', existingDocId);
    } else {
      await supabase.from('guard_documents').insert({
        guard_id: guardId, doc_label: docLabel, [`${side}_url`]: publicUrl,
      });
    }
    setUploadingDoc(false);
    loadGuards();
    toast.success(`${side === 'front' ? 'Front' : 'Back'} uploaded`);
  };

  const deleteDoc = async (docId: string) => {
    const confirmed = await confirmAction('Delete Document?', 'This ID document will be removed.', t('swal.yes'), t('swal.no'));
    if (confirmed) {
      await supabase.from('guard_documents').delete().eq('id', docId);
      loadGuards();
    }
  };

  // KYC pending guards
  const kycPendingGuards = guards.filter(g => {
    if (g.police_verification !== 'pending') return false;
    const createdDaysAgo = (Date.now() - new Date(g.police_verification_date || Date.now()).getTime()) / (1000 * 60 * 60 * 24);
    return true; // show all pending
  });

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <Shield className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('admin.manageGuards')}</h1>
            <p className="text-xs text-muted-foreground">{guards.length} {t('admin.guardsRegistered')}</p>
          </div>
        </div>
        <button onClick={() => setShowForm(!showForm)} className="p-2 rounded-xl bg-primary/10 text-primary">
          <Plus className="w-5 h-5" />
        </button>
      </div>

      {/* KYC Pending Alert */}
      {kycPendingGuards.length > 0 && (
        <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3 mb-4">
          <div className="flex items-center gap-2 mb-2">
            <AlertTriangle className="w-4 h-4 text-amber-600" />
            <span className="text-sm font-semibold text-amber-700">KYC Pending ({kycPendingGuards.length})</span>
          </div>
          {kycPendingGuards.map(g => (
            <p key={g.id} className="text-xs text-amber-600 ml-6">• {g.name} ({g.guard_id}) - Police verification pending</p>
          ))}
        </div>
      )}

      {showForm && (
        <div className="card-section p-4 mb-4 space-y-3">
          <input className="input-field font-mono uppercase" placeholder="Guard ID (e.g. G002)" value={guardId} onChange={e => setGuardId(e.target.value)} />
          <input className="input-field" placeholder="Full Name" value={name} onChange={e => setName(e.target.value)} />

          {/* Auth Mode */}
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">Login Method</label>
            <div className="flex gap-2">
              <button type="button" onClick={() => setAuthMode('password')}
                className={`flex-1 py-2 rounded-lg text-xs font-medium border ${authMode === 'password' ? 'border-primary bg-primary/10 text-primary' : 'border-border text-muted-foreground'}`}>
                Password
              </button>
              <button type="button" onClick={() => setAuthMode('otp')}
                className={`flex-1 py-2 rounded-lg text-xs font-medium border ${authMode === 'otp' ? 'border-primary bg-primary/10 text-primary' : 'border-border text-muted-foreground'}`}>
                OTP (Phone)
              </button>
            </div>
          </div>

          {authMode === 'password' && (
            <input className="input-field" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)} />
          )}
          {authMode === 'otp' && (
            <div className="flex gap-2 items-center">
              <Phone className="w-4 h-4 text-muted-foreground" />
              <input className="input-field flex-1 font-mono" placeholder="Phone (10 digits)" type="tel" maxLength={10}
                value={phone} onChange={e => setPhone(e.target.value.replace(/\D/g, ''))} />
            </div>
          )}

          {/* Police Verification */}
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">Police Verification</label>
            <select className="input-field" value={policeVerification} onChange={e => setPoliceVerification(e.target.value)}>
              <option value="pending">Pending</option>
              <option value="done">Done</option>
            </select>
          </div>

          {/* KYC Alert Days */}
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">KYC Alert (days if pending)</label>
            <input className="input-field" type="number" min={1} max={365} value={kycAlertDays}
              onChange={e => setKycAlertDays(parseInt(e.target.value) || 7)} />
          </div>

          <button onClick={addGuard} className="btn-primary w-full">{t('common.add')}</button>
        </div>
      )}

      <div className="space-y-2">
        {guards.map(g => (
          <div key={g.id} className="card-section p-3">
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-sm font-semibold">{g.name}</p>
                  <span className={`text-[9px] px-1.5 py-0.5 rounded-full font-medium ${
                    g.auth_mode === 'otp' ? 'bg-blue-500/10 text-blue-600' : 'bg-muted text-muted-foreground'
                  }`}>
                    {g.auth_mode === 'otp' ? 'OTP' : 'PWD'}
                  </span>
                  <span className={`text-[9px] px-1.5 py-0.5 rounded-full font-medium ${
                    g.police_verification === 'done' ? 'bg-green-500/10 text-green-600' : 'bg-amber-500/10 text-amber-600'
                  }`}>
                    KYC: {g.police_verification}
                  </span>
                </div>
                <p className="text-xs text-muted-foreground font-mono">{g.guard_id}</p>
                {g.phone && <p className="text-xs text-muted-foreground">📞 {g.phone}</p>}
                {g.auth_mode === 'password' && (
                  <div className="flex items-center gap-1 mt-1">
                    <p className="text-xs text-muted-foreground">
                      {showPasswords[g.id] ? g.password : '••••••'}
                    </p>
                    <button onClick={() => setShowPasswords(p => ({ ...p, [g.id]: !p[g.id] }))} className="text-muted-foreground">
                      {showPasswords[g.id] ? <EyeOff className="w-3 h-3" /> : <Eye className="w-3 h-3" />}
                    </button>
                  </div>
                )}
              </div>
              <div className="flex gap-1">
                <button onClick={() => setExpandedGuard(expandedGuard === g.id ? null : g.id)}
                  className="p-2 rounded-lg bg-blue-500/10 text-blue-600">
                  <FileImage className="w-4 h-4" />
                </button>
                <button onClick={() => {
                  if (editingGuard === g.id) { setEditingGuard(null); setEditFields({}); }
                  else { setEditingGuard(g.id); setEditFields({ auth_mode: g.auth_mode, police_verification: g.police_verification, kyc_alert_days: g.kyc_alert_days, phone: g.phone || '' }); }
                }} className="p-2 rounded-lg bg-primary/10 text-primary">
                  <Shield className="w-4 h-4" />
                </button>
                <button onClick={() => { setResetId(resetId === g.id ? null : g.id); setNewPassword(''); }}
                  className="p-2 rounded-lg bg-amber-500/10 text-amber-600">
                  <KeyRound className="w-4 h-4" />
                </button>
                <button onClick={() => deleteGuard(g.id, g.guard_id)} className="p-2 rounded-lg bg-destructive/10 text-destructive">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Edit Panel */}
            {editingGuard === g.id && (
              <div className="mt-3 space-y-2 p-3 bg-muted/50 rounded-lg">
                <div className="flex gap-2">
                  <select className="input-field flex-1 text-sm" value={editFields.auth_mode || 'password'}
                    onChange={e => setEditFields(f => ({ ...f, auth_mode: e.target.value }))}>
                    <option value="password">Password Login</option>
                    <option value="otp">OTP Login</option>
                  </select>
                  <select className="input-field flex-1 text-sm" value={editFields.police_verification || 'pending'}
                    onChange={e => setEditFields(f => ({ ...f, police_verification: e.target.value }))}>
                    <option value="pending">KYC Pending</option>
                    <option value="done">KYC Done</option>
                  </select>
                </div>
                <input className="input-field text-sm font-mono" placeholder="Phone (for OTP)" type="tel" maxLength={10}
                  value={(editFields.phone as string) || ''} onChange={e => setEditFields(f => ({ ...f, phone: e.target.value.replace(/\D/g, '') }))} />
                <div className="flex gap-2 items-center">
                  <label className="text-xs text-muted-foreground whitespace-nowrap">KYC Alert Days:</label>
                  <input className="input-field flex-1 text-sm" type="number" min={1} max={365}
                    value={editFields.kyc_alert_days || 7} onChange={e => setEditFields(f => ({ ...f, kyc_alert_days: parseInt(e.target.value) || 7 }))} />
                </div>
                <button onClick={() => updateGuard(g.id)} className="btn-primary w-full text-sm">Save Changes</button>
              </div>
            )}

            {/* Password Reset */}
            {resetId === g.id && (
              <div className="mt-3 flex gap-2">
                <input className="input-field flex-1 text-sm" placeholder={t('admin.newPassword')}
                  value={newPassword} onChange={e => setNewPassword(e.target.value)} />
                <button onClick={() => resetGuardPassword(g.id)} className="btn-primary px-4 text-sm">
                  {t('common.save')}
                </button>
              </div>
            )}

            {/* Documents Panel */}
            {expandedGuard === g.id && (
              <div className="mt-3 space-y-2 p-3 bg-muted/50 rounded-lg">
                <p className="text-xs font-semibold mb-2">Identity Documents</p>

                {/* Existing docs */}
                {(guardDocs[g.id] || []).map(doc => (
                  <div key={doc.id} className="flex items-start gap-2 p-2 bg-background rounded-lg">
                    <div className="flex-1">
                      <p className="text-xs font-medium">{doc.doc_label}</p>
                      <div className="flex gap-2 mt-1">
                        {doc.front_url && (
                          <a href={doc.front_url} target="_blank" rel="noreferrer" className="text-[10px] text-primary underline">Front ↗</a>
                        )}
                        {doc.back_url && (
                          <a href={doc.back_url} target="_blank" rel="noreferrer" className="text-[10px] text-primary underline">Back ↗</a>
                        )}
                      </div>
                      <div className="flex gap-1 mt-1">
                        <label className="text-[10px] text-muted-foreground cursor-pointer underline">
                          + Front
                          <input type="file" accept="image/*" className="hidden" onChange={e => {
                            if (e.target.files?.[0]) uploadDoc(g.id, e.target.files[0], 'front', doc.id);
                          }} />
                        </label>
                        <label className="text-[10px] text-muted-foreground cursor-pointer underline">
                          + Back
                          <input type="file" accept="image/*" className="hidden" onChange={e => {
                            if (e.target.files?.[0]) uploadDoc(g.id, e.target.files[0], 'back', doc.id);
                          }} />
                        </label>
                      </div>
                    </div>
                    <button onClick={() => deleteDoc(doc.id)} className="p-1 text-destructive">
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}

                {/* Add new doc */}
                <div className="flex gap-2 items-end">
                  <div className="flex-1">
                    <label className="text-[10px] text-muted-foreground">Document Label</label>
                    <select className="input-field text-sm" value={docLabel} onChange={e => setDocLabel(e.target.value)}>
                      <option>Aadhaar Card</option>
                      <option>PAN Card</option>
                      <option>Driving License</option>
                      <option>Voter ID</option>
                      <option>Passport</option>
                      <option>Other</option>
                    </select>
                  </div>
                  <label className="p-2 rounded-lg bg-primary/10 text-primary cursor-pointer">
                    <Upload className="w-4 h-4" />
                    <input type="file" accept="image/*" className="hidden" disabled={uploadingDoc}
                      onChange={e => {
                        if (e.target.files?.[0]) uploadDoc(g.id, e.target.files[0], 'front');
                      }} />
                  </label>
                </div>
                <p className="text-[9px] text-muted-foreground">Upload front side first, then add back side. Multiple IDs supported.</p>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default AdminGuardManager;
