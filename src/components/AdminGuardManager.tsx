import { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Shield, Plus, Trash2, Eye, EyeOff, KeyRound, Upload, FileImage, AlertTriangle, Phone, Pencil, Camera, ImagePlus, X } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';
import { auditPasswordReset } from '@/lib/auditLogger';

interface GuardRow {
  id: string; guard_id: string; name: string; password: string;
  auth_mode: string; police_verification: string; police_verification_date: string | null;
  kyc_alert_days: number; phone: string | null; photo_url: string | null;
}

interface GuardDoc {
  id: string; guard_id: string; doc_label: string; front_url: string | null; back_url: string | null;
}

interface GuardAttachment {
  id: string; guard_id: string; file_url: string; file_name: string | null; doc_label: string; sort_order: number;
}

const DOC_ACCEPT = 'image/*,application/pdf';

const uploadGuardFile = async (guardUuid: string, file: File, prefix: string): Promise<string> => {
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
  const path = `${guardUuid}/${prefix}_${Date.now()}_${safeName}`;
  const { error } = await supabase.storage.from('guard-documents').upload(path, file);
  if (error) throw error;
  const { data: { publicUrl } } = supabase.storage.from('guard-documents').getPublicUrl(path);
  return publicUrl;
};

const isPdfUrl = (url: string) => /\.pdf($|\?)/i.test(url) || url.toLowerCase().includes('application/pdf');

const useDoubleTap = (onDoubleTap: (url: string) => void, url: string | null) => {
  const lastTap = useRef(0);
  return () => {
    if (!url) return;
    const now = Date.now();
    if (now - lastTap.current < 350) {
      onDoubleTap(url);
      lastTap.current = 0;
    } else {
      lastTap.current = now;
    }
  };
};

const GuardPhotoThumb = ({
  photoUrl,
  guardCode,
  size = 'list',
  onDoubleTap,
}: {
  photoUrl: string | null;
  guardCode: string;
  size?: 'list' | 'sm';
  onDoubleTap: (url: string) => void;
}) => {
  const dim = size === 'list' ? 'w-12 h-12' : 'w-10 h-10';
  const handleTap = useDoubleTap(onDoubleTap, photoUrl);

  return (
    <button
      type="button"
      onClick={handleTap}
      title={photoUrl ? 'Double-tap to enlarge' : 'No photo'}
      className={`${dim} shrink-0 rounded-lg overflow-hidden border border-border bg-muted flex items-center justify-center`}
    >
      {photoUrl ? (
        <img src={photoUrl} alt={guardCode} className="w-full h-full object-cover" />
      ) : (
        <Shield className="w-5 h-5 text-muted-foreground" />
      )}
    </button>
  );
};

const DocThumb = ({ url, label, onEnlarge }: { url: string; label: string; onEnlarge: (url: string) => void }) => {
  const handleTap = useDoubleTap(onEnlarge, url);
  return (
    <button
      type="button"
      className="w-14 h-14 rounded-lg border border-border overflow-hidden bg-muted shrink-0"
      onClick={handleTap}
      title="Double-tap to enlarge"
    >
      {isPdfUrl(url) ? (
        <span className="text-[9px] p-1 flex items-center justify-center h-full text-center text-muted-foreground">PDF</span>
      ) : (
        <img src={url} alt={label} className="w-full h-full object-cover" />
      )}
    </button>
  );
};

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
  const [guardAttachments, setGuardAttachments] = useState<Record<string, GuardAttachment[]>>({});
  const [docLabel, setDocLabel] = useState('Aadhaar Card');
  const [attachLabel, setAttachLabel] = useState('Document');
  const [uploadingDoc, setUploadingDoc] = useState(false);
  const [uploadingProfile, setUploadingProfile] = useState<string | null>(null);
  const [editingGuard, setEditingGuard] = useState<string | null>(null);
  const [editFields, setEditFields] = useState<Partial<GuardRow>>({});
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null);

  const openLightbox = useCallback((url: string) => setLightboxUrl(url), []);

  useEffect(() => { loadGuards(); }, [societyId]);

  const loadGuards = async () => {
    if (!societyId) {
      setGuards([]);
      setGuardDocs({});
      setGuardAttachments({});
      return;
    }
    const query = supabase.from('guards').select('*').eq('society_id', societyId).order('guard_id');
    const { data } = await query;
    if (data) {
      setGuards(data as GuardRow[]);
      const ids = data.map(g => g.id);
      if (ids.length > 0) {
        const [{ data: docs }, { data: attachments }] = await Promise.all([
          supabase.from('guard_documents').select('*').in('guard_id', ids),
          supabase.from('guard_attachments').select('*').in('guard_id', ids).order('sort_order'),
        ]);
        if (docs) {
          const grouped: Record<string, GuardDoc[]> = {};
          docs.forEach((d: GuardDoc) => {
            if (!grouped[d.guard_id]) grouped[d.guard_id] = [];
            grouped[d.guard_id].push(d);
          });
          setGuardDocs(grouped);
        }
        if (attachments) {
          const groupedAtt: Record<string, GuardAttachment[]> = {};
          attachments.forEach((a: GuardAttachment) => {
            if (!groupedAtt[a.guard_id]) groupedAtt[a.guard_id] = [];
            groupedAtt[a.guard_id].push(a);
          });
          setGuardAttachments(groupedAtt);
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
    const nameVal = (editFields.name as string | undefined)?.trim();
    const gid = (editFields.guard_id as string | undefined)?.trim().toUpperCase();
    if (!nameVal) {
      toast.error('Name is required');
      return;
    }
    if (!gid) {
      toast.error('Guard ID is required');
      return;
    }
    const mode = editFields.auth_mode || 'password';
    const phoneDigits = (editFields.phone as string)?.replace(/\D/g, '') || '';
    if (mode === 'otp' && phoneDigits.length < 10) {
      toast.error('OTP login requires a 10-digit phone number');
      return;
    }
    const updates: Record<string, unknown> = {
      name: nameVal,
      guard_id: gid,
      auth_mode: mode,
      police_verification: editFields.police_verification,
      kyc_alert_days: editFields.kyc_alert_days,
      phone: phoneDigits ? phoneDigits : null,
    };
    await supabase.from('guards').update(updates).eq('id', id);
    toast.success('Guard updated');
    setEditingGuard(null); setEditFields({});
    loadGuards();
  };

  const uploadProfilePhoto = async (guardUuid: string, file: File) => {
    setUploadingProfile(guardUuid);
    try {
      const publicUrl = await uploadGuardFile(guardUuid, file, 'profile');
      await supabase.from('guards').update({ photo_url: publicUrl }).eq('id', guardUuid);
      toast.success('Worker photo saved');
      loadGuards();
    } catch {
      toast.error('Photo upload failed');
    } finally {
      setUploadingProfile(null);
    }
  };

  const removeProfilePhoto = async (guardUuid: string) => {
    const confirmed = await confirmAction('Remove photo?', 'The worker profile photo will be cleared.', t('swal.yes'), t('swal.no'));
    if (!confirmed) return;
    await supabase.from('guards').update({ photo_url: null }).eq('id', guardUuid);
    loadGuards();
  };

  const uploadDoc = async (guardUuid: string, file: File, side: 'front' | 'back', existingDocId?: string) => {
    setUploadingDoc(true);
    try {
      const urlKey = `${side}_url` as 'front_url' | 'back_url';
      const publicUrl = await uploadGuardFile(guardUuid, file, `id_${side}`);
      if (existingDocId) {
        await supabase.from('guard_documents').update({ [urlKey]: publicUrl }).eq('id', existingDocId);
      } else {
        await supabase.from('guard_documents').insert({
          guard_id: guardUuid, doc_label: docLabel, [urlKey]: publicUrl,
        });
      }
      toast.success(`${side === 'front' ? 'Front' : 'Back'} uploaded`);
      loadGuards();
    } catch {
      toast.error('Upload failed');
    } finally {
      setUploadingDoc(false);
    }
  };

  const uploadAttachments = async (guardUuid: string, files: FileList | File[]) => {
    const list = Array.from(files);
    if (!list.length) return;
    setUploadingDoc(true);
    const existing = guardAttachments[guardUuid] || [];
    let sortBase = existing.length;
    try {
      for (const file of list) {
        const publicUrl = await uploadGuardFile(guardUuid, file, 'doc');
        await supabase.from('guard_attachments').insert({
          guard_id: guardUuid,
          file_url: publicUrl,
          file_name: file.name,
          doc_label: attachLabel,
          sort_order: sortBase++,
        });
      }
      toast.success(list.length === 1 ? 'Document saved' : `${list.length} documents saved`);
      loadGuards();
    } catch {
      toast.error('Document upload failed');
    } finally {
      setUploadingDoc(false);
    }
  };

  const deleteDoc = async (docId: string) => {
    const confirmed = await confirmAction('Delete Document?', 'This ID document will be removed.', t('swal.yes'), t('swal.no'));
    if (confirmed) {
      await supabase.from('guard_documents').delete().eq('id', docId);
      loadGuards();
    }
  };

  const deleteAttachment = async (attId: string) => {
    const confirmed = await confirmAction('Delete document?', 'This file will be removed.', t('swal.yes'), t('swal.no'));
    if (confirmed) {
      await supabase.from('guard_attachments').delete().eq('id', attId);
      loadGuards();
    }
  };

  const handleProfileFile = (guardUuid: string, file: File | undefined) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      toast.error('Profile photo must be an image');
      return;
    }
    void uploadProfilePhoto(guardUuid, file);
  };

  const kycPendingGuards = guards.filter(g => g.police_verification !== 'done');

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

          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">Police Verification</label>
            <select className="input-field" value={policeVerification} onChange={e => setPoliceVerification(e.target.value)}>
              <option value="pending">Pending</option>
              <option value="done">Done</option>
            </select>
          </div>

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
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <GuardPhotoThumb photoUrl={g.photo_url} guardCode={g.guard_id} onDoubleTap={openLightbox} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-sm font-semibold truncate">{g.name}</p>
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
                  <p className="text-xs text-muted-foreground font-mono font-semibold">{g.guard_id}</p>
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
              </div>
              <div className="flex gap-1 shrink-0">
                <button onClick={() => setExpandedGuard(expandedGuard === g.id ? null : g.id)}
                  className="p-2 rounded-lg bg-blue-500/10 text-blue-600">
                  <FileImage className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  title="Edit guard details"
                  onClick={() => {
                    if (editingGuard === g.id) {
                      setEditingGuard(null);
                      setEditFields({});
                    } else {
                      setEditingGuard(g.id);
                      setEditFields({
                        name: g.name,
                        guard_id: g.guard_id,
                        auth_mode: g.auth_mode,
                        police_verification: g.police_verification,
                        kyc_alert_days: g.kyc_alert_days,
                        phone: g.phone || '',
                      });
                    }
                  }}
                  className="p-2 rounded-lg bg-primary/10 text-primary"
                >
                  <Pencil className="w-4 h-4" />
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

            {editingGuard === g.id && (
              <div className="mt-3 space-y-2 p-3 bg-muted/50 rounded-lg border border-border">
                <p className="text-xs font-semibold text-foreground">Edit guard</p>
                <input
                  className="input-field text-sm font-mono uppercase"
                  placeholder="Guard ID"
                  value={(editFields.guard_id as string) || ''}
                  onChange={e => setEditFields(f => ({ ...f, guard_id: e.target.value.toUpperCase() }))}
                />
                <input
                  className="input-field text-sm"
                  placeholder="Full name"
                  value={(editFields.name as string) || ''}
                  onChange={e => setEditFields(f => ({ ...f, name: e.target.value }))}
                />
                <div className="flex gap-2">
                  <select
                    className="input-field flex-1 text-sm"
                    value={editFields.auth_mode || 'password'}
                    onChange={e => setEditFields(f => ({ ...f, auth_mode: e.target.value }))}
                  >
                    <option value="password">Password Login</option>
                    <option value="otp">OTP Login</option>
                  </select>
                  <select
                    className="input-field flex-1 text-sm"
                    value={editFields.police_verification || 'pending'}
                    onChange={e => setEditFields(f => ({ ...f, police_verification: e.target.value }))}
                  >
                    <option value="pending">KYC Pending</option>
                    <option value="done">KYC Done</option>
                  </select>
                </div>
                <div className="flex gap-2 items-center">
                  <Phone className="w-4 h-4 shrink-0 text-muted-foreground" />
                  <input
                    className="input-field flex-1 text-sm font-mono"
                    placeholder={(editFields.auth_mode || g.auth_mode) === 'otp' ? 'Phone (10 digits, required for OTP)' : 'Phone (optional)'}
                    type="tel"
                    maxLength={10}
                    value={(editFields.phone as string) || ''}
                    onChange={e => setEditFields(f => ({ ...f, phone: e.target.value.replace(/\D/g, '') }))}
                  />
                </div>
                <div className="flex gap-2 items-center">
                  <label className="text-xs text-muted-foreground whitespace-nowrap">KYC alert (days):</label>
                  <input
                    className="input-field flex-1 text-sm"
                    type="number"
                    min={1}
                    max={365}
                    value={editFields.kyc_alert_days ?? 7}
                    onChange={e => setEditFields(f => ({ ...f, kyc_alert_days: parseInt(e.target.value, 10) || 7 }))}
                  />
                </div>
                <p className="text-[10px] text-muted-foreground">Use the key button below to change password. OTP guards use the phone number above.</p>
                <button type="button" onClick={() => updateGuard(g.id)} className="btn-primary w-full text-sm">
                  Save changes
                </button>
              </div>
            )}

            {resetId === g.id && (
              <div className="mt-3 flex gap-2">
                <input className="input-field flex-1 text-sm" placeholder={t('admin.newPassword')}
                  value={newPassword} onChange={e => setNewPassword(e.target.value)} />
                <button onClick={() => resetGuardPassword(g.id)} className="btn-primary px-4 text-sm">
                  {t('common.save')}
                </button>
              </div>
            )}

            {expandedGuard === g.id && (
              <div className="mt-3 space-y-4 p-3 bg-muted/50 rounded-lg">
                {/* Worker profile photo */}
                <div>
                  <p className="text-xs font-semibold mb-1">Worker photo</p>
                  <p className="text-[10px] text-muted-foreground mb-2">Shown in the list next to guard ID. Double-tap the thumbnail to enlarge.</p>
                  <div className="flex flex-wrap items-center gap-3">
                    <GuardPhotoThumb photoUrl={g.photo_url} guardCode={g.guard_id} size="sm" onDoubleTap={openLightbox} />
                    <div className="flex flex-wrap gap-2">
                      <label className={`btn-secondary text-xs px-3 py-2 cursor-pointer flex items-center gap-1 ${uploadingProfile === g.id ? 'opacity-50 pointer-events-none' : ''}`}>
                        <Camera className="w-3.5 h-3.5" /> Take photo
                        <input
                          type="file"
                          accept="image/*"
                          capture="environment"
                          className="hidden"
                          disabled={uploadingProfile === g.id}
                          onChange={e => {
                            handleProfileFile(g.id, e.target.files?.[0]);
                            e.target.value = '';
                          }}
                        />
                      </label>
                      <label className={`btn-secondary text-xs px-3 py-2 cursor-pointer flex items-center gap-1 ${uploadingProfile === g.id ? 'opacity-50 pointer-events-none' : ''}`}>
                        <ImagePlus className="w-3.5 h-3.5" /> Gallery
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          disabled={uploadingProfile === g.id}
                          onChange={e => {
                            handleProfileFile(g.id, e.target.files?.[0]);
                            e.target.value = '';
                          }}
                        />
                      </label>
                      {g.photo_url && (
                        <button type="button" onClick={() => void removeProfilePhoto(g.id)} className="text-xs text-destructive underline">
                          Remove photo
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                {/* Photo ID (front/back per document type) */}
                <div>
                  <p className="text-xs font-semibold mb-1">Photo ID</p>
                  <p className="text-[10px] text-muted-foreground mb-2">Add ID cards with front and back images. Double-tap a thumbnail to enlarge.</p>

                  {(guardDocs[g.id] || []).map(doc => (
                    <div key={doc.id} className="flex items-start gap-2 p-2 bg-background rounded-lg mb-2">
                      <div className="flex-1">
                        <p className="text-xs font-medium">{doc.doc_label}</p>
                        <div className="flex gap-2 mt-1 flex-wrap">
                          {doc.front_url && <DocThumb url={doc.front_url} label="Front" onEnlarge={openLightbox} />}
                          {doc.back_url && <DocThumb url={doc.back_url} label="Back" onEnlarge={openLightbox} />}
                        </div>
                        <div className="flex gap-2 mt-2 flex-wrap">
                          <label className="text-[10px] text-muted-foreground cursor-pointer underline flex items-center gap-1">
                            <Camera className="w-3 h-3" /> {doc.front_url ? 'Replace front' : 'Front (camera)'}
                            <input type="file" accept="image/*" capture="environment" className="hidden" onChange={e => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              if (f) void uploadDoc(g.id, f, 'front', doc.id);
                            }} />
                          </label>
                          <label className="text-[10px] text-muted-foreground cursor-pointer underline flex items-center gap-1">
                            <ImagePlus className="w-3 h-3" /> {doc.front_url ? 'Front (gallery)' : 'Front (gallery)'}
                            <input type="file" accept="image/*" className="hidden" onChange={e => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              if (f) void uploadDoc(g.id, f, 'front', doc.id);
                            }} />
                          </label>
                          <label className="text-[10px] text-muted-foreground cursor-pointer underline flex items-center gap-1">
                            <Camera className="w-3 h-3" /> {doc.back_url ? 'Replace back' : 'Back (camera)'}
                            <input type="file" accept="image/*" capture="environment" className="hidden" onChange={e => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              if (f) void uploadDoc(g.id, f, 'back', doc.id);
                            }} />
                          </label>
                          <label className="text-[10px] text-muted-foreground cursor-pointer underline flex items-center gap-1">
                            <ImagePlus className="w-3 h-3" /> Back (gallery)
                            <input type="file" accept="image/*" className="hidden" onChange={e => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              if (f) void uploadDoc(g.id, f, 'back', doc.id);
                            }} />
                          </label>
                        </div>
                      </div>
                      <button onClick={() => deleteDoc(doc.id)} className="p-1 text-destructive">
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  ))}

                  <div className="flex gap-2 items-end mt-2">
                    <div className="flex-1">
                      <label className="text-[10px] text-muted-foreground">ID document type</label>
                      <select className="input-field text-sm" value={docLabel} onChange={e => setDocLabel(e.target.value)}>
                        <option>Aadhaar Card</option>
                        <option>PAN Card</option>
                        <option>Driving License</option>
                        <option>Voter ID</option>
                        <option>Passport</option>
                        <option>Other</option>
                      </select>
                    </div>
                    <label className={`p-2 rounded-lg bg-primary/10 text-primary cursor-pointer ${uploadingDoc ? 'opacity-50 pointer-events-none' : ''}`} title="Add new ID (front)">
                      <Upload className="w-4 h-4" />
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        disabled={uploadingDoc}
                        onChange={e => {
                          const f = e.target.files?.[0];
                          e.target.value = '';
                          if (f) void uploadDoc(g.id, f, 'front');
                        }}
                      />
                    </label>
                  </div>
                </div>

                {/* Multiple documents */}
                <div className="border border-dashed border-border rounded-lg p-3 space-y-2">
                  <p className="text-xs font-semibold">Documents</p>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    Save multiple images or PDFs per worker. Use <strong>Browse</strong> to pick many files at once, or <strong>Take photo</strong> for the camera.
                  </p>
                  <div className="flex gap-2 items-end">
                    <div className="flex-1">
                      <label className="text-[10px] text-muted-foreground">Label</label>
                      <input
                        className="input-field text-sm"
                        value={attachLabel}
                        onChange={e => setAttachLabel(e.target.value)}
                        placeholder="e.g. Police verification, Contract"
                      />
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <label className={`btn-primary text-xs px-3 py-2 cursor-pointer ${uploadingDoc ? 'opacity-50 pointer-events-none' : ''}`}>
                      Browse files
                      <input
                        type="file"
                        multiple
                        accept={DOC_ACCEPT}
                        className="hidden"
                        disabled={uploadingDoc}
                        onChange={e => {
                          const files = e.target.files;
                          e.target.value = '';
                          if (files?.length) void uploadAttachments(g.id, files);
                        }}
                      />
                    </label>
                    <label className={`btn-secondary text-xs px-3 py-2 cursor-pointer flex items-center gap-1 ${uploadingDoc ? 'opacity-50 pointer-events-none' : ''}`}>
                      <Camera className="w-3.5 h-3.5" /> Take photo
                      <input
                        type="file"
                        accept="image/*"
                        capture="environment"
                        className="hidden"
                        disabled={uploadingDoc}
                        onChange={e => {
                          const f = e.target.files?.[0];
                          e.target.value = '';
                          if (f) void uploadAttachments(g.id, [f]);
                        }}
                      />
                    </label>
                  </div>

                  {(guardAttachments[g.id] || []).length > 0 && (
                    <div className="flex flex-wrap gap-2 mt-2">
                      {(guardAttachments[g.id] || []).map(att => (
                        <div key={att.id} className="relative group">
                          {isPdfUrl(att.file_url) ? (
                            <a
                              href={att.file_url}
                              target="_blank"
                              rel="noreferrer"
                              className="w-14 h-14 rounded-lg border border-border flex items-center justify-center bg-background text-[9px] text-primary font-medium p-1 text-center"
                            >
                              PDF
                            </a>
                          ) : (
                            <DocThumb url={att.file_url} label={att.doc_label} onEnlarge={openLightbox} />
                          )}
                          <p className="text-[9px] text-muted-foreground max-w-[56px] truncate mt-0.5">{att.doc_label}</p>
                          <button
                            type="button"
                            onClick={() => deleteAttachment(att.id)}
                            className="absolute -top-1 -right-1 bg-destructive text-destructive-foreground rounded-full p-0.5 opacity-90"
                          >
                            <X className="w-2.5 h-2.5" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {lightboxUrl && (
        <div
          className="fixed inset-0 z-[100] bg-black/90 flex items-center justify-center p-4"
          onClick={() => setLightboxUrl(null)}
          role="dialog"
          aria-label="Enlarged photo"
        >
          <button
            type="button"
            className="absolute top-4 right-4 text-white p-2 rounded-full bg-white/10"
            onClick={() => setLightboxUrl(null)}
          >
            <X className="w-6 h-6" />
          </button>
          {isPdfUrl(lightboxUrl) ? (
            <a href={lightboxUrl} target="_blank" rel="noreferrer" className="text-white underline text-lg">
              Open PDF
            </a>
          ) : (
            <img
              src={lightboxUrl}
              alt="Enlarged"
              className="max-w-full max-h-full object-contain"
              onClick={e => e.stopPropagation()}
            />
          )}
        </div>
      )}
    </div>
  );
};

export default AdminGuardManager;
