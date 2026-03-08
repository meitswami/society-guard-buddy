import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { Lock, Eye, EyeOff } from 'lucide-react';
import { toast } from 'sonner';
import { auditPasswordChange } from '@/lib/auditLogger';

interface Props {
  adminId: string;
}

const AdminPasswordChange = ({ adminId }: Props) => {
  const { t } = useLanguage();
  const [current, setCurrent] = useState('');
  const [newPass, setNewPass] = useState('');
  const [confirm, setConfirm] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleChange = async () => {
    if (!current || !newPass || !confirm) { toast.error(t('admin.fillAllFields')); return; }
    if (newPass !== confirm) { toast.error(t('admin.passwordMismatch')); return; }
    if (newPass.length < 4) { toast.error(t('admin.passwordTooShort')); return; }

    setLoading(true);
    const { data } = await supabase.from('admins').select('id').eq('id', adminId).eq('password', current).single();
    if (!data) {
      toast.error(t('admin.currentPasswordWrong'));
      setLoading(false); return;
    }
    await supabase.from('admins').update({ password: newPass }).eq('id', adminId);
    auditPasswordChange('admin', adminId, 'admin');
    toast.success(t('admin.passwordChanged'));
    setCurrent(''); setNewPass(''); setConfirm('');
    setLoading(false);
  };

  return (
    <div className="page-container">
      <div className="flex items-center gap-2 mb-4">
        <Lock className="w-5 h-5 text-primary" />
        <h2 className="font-semibold">{t('admin.changePassword')}</h2>
      </div>
      <div className="card-section p-4 flex flex-col gap-3">
        <div className="relative">
          <input className="input-field pr-10" type={showPass ? 'text' : 'password'}
            placeholder={t('admin.currentPassword')} value={current} onChange={e => setCurrent(e.target.value)} />
          <button type="button" className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
            onClick={() => setShowPass(!showPass)}>
            {showPass ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
        <input className="input-field" type={showPass ? 'text' : 'password'}
          placeholder={t('admin.newPassword')} value={newPass} onChange={e => setNewPass(e.target.value)} />
        <input className="input-field" type={showPass ? 'text' : 'password'}
          placeholder={t('admin.confirmPassword')} value={confirm} onChange={e => setConfirm(e.target.value)} />
        <button onClick={handleChange} className="btn-primary" disabled={loading}>
          {loading ? t('login.loggingIn') : t('admin.changePassword')}
        </button>
      </div>
    </div>
  );
};

export default AdminPasswordChange;
