import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Shield, Plus, Trash2, Eye, EyeOff, KeyRound } from 'lucide-react';
import { confirmAction, showSuccess } from '@/lib/swal';
import { toast } from 'sonner';

import { auditPasswordReset } from '@/lib/auditLogger';

interface GuardRow { id: string; guard_id: string; name: string; password: string; }

const AdminGuardManager = () => {
  const { t } = useLanguage();
  const { societyId } = useStore();
  const [guards, setGuards] = useState<GuardRow[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [guardId, setGuardId] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});
  const [resetId, setResetId] = useState<string | null>(null);
  const [newPassword, setNewPassword] = useState('');

  useEffect(() => { loadGuards(); }, []);

  const loadGuards = async () => {
    let query = supabase.from('guards').select('*').order('guard_id');
    if (societyId) query = query.eq('society_id', societyId);
    const { data } = await query;
    if (data) setGuards(data);
  };

  const addGuard = async () => {
    if (!guardId || !name || !password) return;
    await supabase.from('guards').insert({ guard_id: guardId.toUpperCase(), name, password, society_id: societyId || null });
    setGuardId(''); setName(''); setPassword(''); setShowForm(false);
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
    if (!newPassword || newPassword.length < 4) {
      toast.error(t('admin.passwordTooShort'));
      return;
    }
    await supabase.from('guards').update({ password: newPassword }).eq('id', id);
    auditPasswordReset('guard', id, 'guard', 'admin');
    toast.success(t('admin.passwordChanged'));
    setResetId(null);
    setNewPassword('');
    loadGuards();
  };

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

      {showForm && (
        <div className="card-section p-4 mb-4 space-y-3">
          <input className="input-field font-mono uppercase" placeholder="Guard ID (e.g. G002)" value={guardId} onChange={e => setGuardId(e.target.value)} />
          <input className="input-field" placeholder="Full Name" value={name} onChange={e => setName(e.target.value)} />
          <input className="input-field" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)} />
          <button onClick={addGuard} className="btn-primary w-full">{t('common.add')}</button>
        </div>
      )}

      <div className="space-y-2">
        {guards.map(g => (
          <div key={g.id} className="card-section p-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold">{g.name}</p>
                <p className="text-xs text-muted-foreground font-mono">{g.guard_id}</p>
                <div className="flex items-center gap-1 mt-1">
                  <p className="text-xs text-muted-foreground">
                    {showPasswords[g.id] ? g.password : '••••••'}
                  </p>
                  <button onClick={() => setShowPasswords(p => ({ ...p, [g.id]: !p[g.id] }))} className="text-muted-foreground">
                    {showPasswords[g.id] ? <EyeOff className="w-3 h-3" /> : <Eye className="w-3 h-3" />}
                  </button>
                </div>
              </div>
              <div className="flex gap-1">
                <button onClick={() => { setResetId(resetId === g.id ? null : g.id); setNewPassword(''); }}
                  className="p-2 rounded-lg bg-amber-500/10 text-amber-600">
                  <KeyRound className="w-4 h-4" />
                </button>
                <button onClick={() => deleteGuard(g.id, g.guard_id)} className="p-2 rounded-lg bg-destructive/10 text-destructive">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
            {resetId === g.id && (
              <div className="mt-3 flex gap-2">
                <input className="input-field flex-1 text-sm" placeholder={t('admin.newPassword')}
                  value={newPassword} onChange={e => setNewPassword(e.target.value)} />
                <button onClick={() => resetGuardPassword(g.id)} className="btn-primary px-4 text-sm">
                  {t('common.save')}
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default AdminGuardManager;
