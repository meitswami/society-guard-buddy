import { useState, useEffect } from 'react';
import { Fingerprint, Check } from 'lucide-react';
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
  const { isAvailable, register, hasCredential, getCredentialCount, listCredentials, removeCredential, maxCredentialsPerUser, loading } = useBiometric();
  const [available, setAvailable] = useState(false);
  const [registered, setRegistered] = useState(false);
  const [credentialCount, setCredentialCount] = useState(0);
  const [credentials, setCredentials] = useState<{ id: string; createdAt: string; shortId: string }[]>([]);
  const [removingId, setRemovingId] = useState<string | null>(null);

  const refreshCredentials = async () => {
    const [isRegistered, count, list] = await Promise.all([
      hasCredential(userType, userId),
      getCredentialCount(userType, userId),
      listCredentials(userType, userId),
    ]);
    setRegistered(isRegistered);
    setCredentialCount(count);
    setCredentials(list);
  };

  useEffect(() => {
    isAvailable().then(setAvailable);
    refreshCredentials();
  }, [getCredentialCount, hasCredential, isAvailable, listCredentials, userType, userId]);

  if (!available) return null;

  const handleRegister = async () => {
    const ok = await register(userType, userId, userName);
    if (ok) {
      await refreshCredentials();
      toast.success(t('biometric.registered'));
    } else {
      toast.error(t('biometric.registerFailed'));
    }
  };

  const handleRemoveCredential = async (id: string) => {
    setRemovingId(id);
    const ok = await removeCredential(id);
    setRemovingId(null);
    if (ok) {
      await refreshCredentials();
      toast.success('Biometric device removed');
    } else {
      toast.error('Could not remove biometric device');
    }
  };

  return (
    <div className="card-section p-4">
      <div className="flex items-center gap-3 mb-3">
        <Fingerprint className="w-5 h-5 text-primary" />
        <div>
          <p className="font-medium text-sm">{t('biometric.title')}</p>
          <p className="text-xs text-muted-foreground">
            {t('biometric.subtitle')} ({credentialCount}/{maxCredentialsPerUser} devices)
          </p>
        </div>
      </div>
      {registered ? (
        <div className="space-y-2">
          <div className="flex items-center gap-2 text-sm text-green-600">
            <Check className="w-4 h-4" />
            <span>{t('biometric.enabled')}</span>
          </div>
          <button onClick={handleRegister} disabled={loading} className="btn-secondary w-full text-sm">
            {loading ? t('biometric.registering') : `Add another device (${credentialCount}/${maxCredentialsPerUser})`}
          </button>
          {credentials.length > 0 && (
            <div className="rounded-lg border border-border divide-y divide-border">
              {credentials.map((cred, idx) => (
                <div key={cred.id} className="px-3 py-2 flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-xs font-medium truncate">Device {idx + 1} ({cred.shortId}...)</p>
                    <p className="text-[10px] text-muted-foreground">
                      Added {new Date(cred.createdAt).toLocaleString()}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRemoveCredential(cred.id)}
                    disabled={removingId === cred.id}
                    className="text-xs text-destructive underline disabled:opacity-60"
                  >
                    {removingId === cred.id ? 'Removing...' : 'Remove'}
                  </button>
                </div>
              ))}
            </div>
          )}
          {credentialCount >= maxCredentialsPerUser && (
            <p className="text-[11px] text-muted-foreground">
              Max {maxCredentialsPerUser} biometrics reached. Adding one more will replace the oldest device.
            </p>
          )}
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
