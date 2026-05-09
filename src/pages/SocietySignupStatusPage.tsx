import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { toast } from 'sonner';
import { useLanguage } from '@/i18n/LanguageContext';
import { phonepePollStatus } from '@/lib/phonepeClient';

export default function SocietySignupStatusPage() {
  const { t } = useLanguage();
  const [sp] = useSearchParams();
  const signupId = sp.get('signupId') || '';
  const token = sp.get('token') || '';

  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState<string>('');
  const [societyName, setSocietyName] = useState<string>('');

  const title = useMemo(() => {
    const s = status.toLowerCase();
    if (s === 'pending' || s === 'paid') return t('signup.successPending');
    if (s === 'provisioned') return t('signup.successDone');
    if (s === 'failed' || s === 'cancelled') return s.toUpperCase();
    return t('signup.successProvisioning');
  }, [status, t]);

  useEffect(() => {
    if (!signupId || !token) {
      setLoading(false);
      setStatus('failed');
      return;
    }
    let cancelled = false;
    const poll = async () => {
      try {
        const res = await phonepePollStatus({ signupId, token });
        if (cancelled) return;
        setStatus(res.status);
        setSocietyName(res.societyName);
        setLoading(false);
        if (res.status !== 'provisioned' && res.status !== 'failed' && res.status !== 'cancelled') {
          setTimeout(poll, 2500);
        }
      } catch (e) {
        if (cancelled) return;
        console.error(e);
        toast.error(t('signup.errorGeneric'));
        setLoading(false);
      }
    };
    poll();
    return () => {
      cancelled = true;
    };
  }, [signupId, token, t]);

  return (
    <div className="min-h-screen bg-background px-6 pb-24 flex items-center justify-center">
      <div className="w-full max-w-md">
        <div className="card-section p-5">
          <h1 className="page-title text-xl">{title}</h1>
          {societyName && <p className="text-sm text-muted-foreground mt-1">{societyName}</p>}
          {loading && <p className="text-sm text-muted-foreground mt-4">{t('signup.processing')}</p>}

          {status.toLowerCase() === 'provisioned' && (
            <div className="mt-4 space-y-2">
              <p className="text-sm text-muted-foreground">
                {t('signup.successDone')}
              </p>
              <Link to="/" className="btn-primary w-full text-center py-3">
                {t('signup.gotoHome')}
              </Link>
            </div>
          )}

          {(status.toLowerCase() === 'failed' || status.toLowerCase() === 'cancelled') && (
            <div className="mt-4 space-y-2">
              <p className="text-sm text-muted-foreground">{t('signup.errorGeneric')}</p>
              <Link to="/society-signup" className="btn-secondary w-full text-center py-3">
                {t('signup.payNow')}
              </Link>
              <Link to="/" className="text-xs text-muted-foreground text-center underline block">
                {t('signup.gotoHome')}
              </Link>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

