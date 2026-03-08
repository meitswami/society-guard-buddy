import { useState, useEffect } from 'react';
import { Fingerprint, Check, X } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { useBiometric } from '@/hooks/useBiometric';
import { toast } from 'sonner';

interface Props {
  userType: string;
  userId: string;
  userName: string;
}

const BiometricSetup = ({ userType, userId, userName }: Props) => {
  const { t } = useLanguage();
  const { isAvailable, register, hasCredential, loading } = useBiometric();
  const [available, setAvailable] = useState(false);
  const [registered, setRegistered] = useState(false);

  useEffect(() => {
    isAvailable().then(setAvailable);
    hasCredential(userType, userId).then(setRegistered);
  }, [userType, userId]);

  if (!available) return null;

  const handleRegister = async () => {
    const ok = await register(userType, userId, userName);
    if (ok) {
      setRegistered(true);
      toast.success(t('biometric.registered'));
    } else {
      toast.error(t('biometric.registerFailed'));
    }
  };

  return (
    <div className="card-section p-4">
      <div className="flex items-center gap-3 mb-3">
        <Fingerprint className="w-5 h-5 text-primary" />
        <div>
          <p className="font-medium text-sm">{t('biometric.title')}</p>
          <p className="text-xs text-muted-foreground">{t('biometric.subtitle')}</p>
        </div>
      </div>
      {registered ? (
        <div className="flex items-center gap-2 text-sm text-green-600">
          <Check className="w-4 h-4" />
          <span>{t('biometric.enabled')}</span>
        </div>
      ) : (
        <button onClick={handleRegister} disabled={loading} className="btn-primary w-full text-sm">
          {loading ? t('biometric.registering') : t('biometric.enable')}
        </button>
      )}
    </div>
  );
};

export default BiometricSetup;
