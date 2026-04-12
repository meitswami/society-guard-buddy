import { useState, useEffect } from 'react';
import { Crown, Eye, EyeOff, Fingerprint, Loader2, Shield } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import type { Database } from '@/integrations/supabase/types';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed } from '@/lib/auditLogger';
import {
  buildTotpKeyUri,
  generateTotpSecret,
  totpQrImageUrl,
  verifyTotpCode,
} from '@/lib/superadminTotp';

export type SuperadminProfile = { id: string; name: string; username: string };

type SuperAdminRow = Database['public']['Tables']['super_admins']['Row'];

type Step =
  | 'password'
  | 'totp'
  | 'setup-qr'
  | 'setup-totp-verify'
  | 'setup-recovery'
  | 'recovery-request'
  | 'recovery-verify';

interface Props {
  onLogin: (sa: SuperadminProfile) => void;
  onBack?: () => void;
  /** `embedded`: used inside UnifiedLoginPage (no crown header). */
  variant?: 'full' | 'embedded';
}

const SuperadminLoginForm = ({ onLogin, onBack, variant = 'full' }: Props) => {
  const { t } = useLanguage();
  const [step, setStep] = useState<Step>('password');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [recoveryEmailInput, setRecoveryEmailInput] = useState('');
  const [recoveryUsername, setRecoveryUsername] = useState('');
  const [recoveryEmailRequest, setRecoveryEmailRequest] = useState('');
  const [recoveryCode, setRecoveryCode] = useState('');
  const [recoveryInfo, setRecoveryInfo] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [pendingRow, setPendingRow] = useState<SuperAdminRow | null>(null);
  const [setupSecret, setSetupSecret] = useState<string | null>(null);
  const [cameFromBiometric, setCameFromBiometric] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => {
    isAvailable().then(setBioAvailable);
  }, []);

  const finishLogin = (row: Pick<SuperAdminRow, 'id' | 'name' | 'username'>, method: string) => {
    auditLoginSuccess('superadmin', row.id, row.name, method);
    onLogin({ id: row.id, name: row.name, username: row.username });
  };

  const afterPasswordOk = (row: SuperAdminRow, fromBio: boolean) => {
    setPendingRow(row);
    setCameFromBiometric(fromBio);
    setTotpCode('');
    setError('');
    if (!row.totp_secret) {
      const secret = generateTotpSecret();
      setSetupSecret(secret);
      setRecoveryEmailInput(row.recovery_email?.trim() ?? '');
      setStep('setup-qr');
      return;
    }
    setStep('totp');
  };

  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!username || !password) {
      setError(t('login.enterBoth'));
      return;
    }
    setLoading(true);
    const u = username.trim().toUpperCase();
    // Match by username only; compare password in-app so special characters (e.g. #) are not
    // sent inside PostgREST filter URLs, and credentials do not appear in query strings.
    const { data, error: qErr } = await supabase
      .from('super_admins')
      .select('*')
      .eq('username', u)
      .maybeSingle();
    setLoading(false);
    if (qErr) {
      console.error('[superadmin login] Supabase query error', qErr);
      auditLoginFailed('superadmin', u, qErr.code ?? qErr.message);
      const msg = (qErr.message ?? '').toLowerCase();
      const looksLikeNetwork =
        msg.includes('failed to fetch') ||
        msg.includes('network') ||
        msg.includes('load failed') ||
        msg.includes('err_network');
      setError(looksLikeNetwork ? t('login.connectionProblem') : t('login.invalidCredentials'));
      return;
    }
    if (!data) {
      auditLoginFailed('superadmin', u);
      setError(t('login.invalidCredentials'));
      return;
    }
    const stored = (data.password ?? '').trim();
    const typed = password.trim();
    if (stored !== typed) {
      auditLoginFailed('superadmin', u);
      setError(t('login.invalidCredentials'));
      return;
    }
    afterPasswordOk(data, false);
  };

  const handleBiometricLogin = async () => {
    setError('');
    const result = await authenticate('superadmin');
    if (!result) {
      setError(t('biometric.notRegistered'));
      return;
    }
    const { data, error: qErr } = await supabase.from('super_admins').select('*').eq('id', result.userId).maybeSingle();
    if (qErr || !data) {
      auditLoginFailed('superadmin', result.userId, 'biometric_user_not_found');
      setError(t('login.invalidCredentials'));
      return;
    }
    if (!data.totp_secret) {
      setError(t('superadmin.completeMfaWithPassword'));
      return;
    }
    afterPasswordOk(data, true);
  };

  const handleTotpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!pendingRow?.totp_secret || !verifyTotpCode(pendingRow.totp_secret, totpCode)) {
      setError(t('superadmin.invalidAuthenticatorCode'));
      return;
    }
    const method = cameFromBiometric ? 'biometric_totp' : 'password_totp';
    finishLogin(pendingRow, method);
  };

  const handleSetupTotpVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!pendingRow || !setupSecret || !verifyTotpCode(setupSecret, totpCode)) {
      setError(t('superadmin.invalidAuthenticatorCode'));
      return;
    }
    setLoading(true);
    const { error: upErr } = await supabase
      .from('super_admins')
      .update({ totp_secret: setupSecret, totp_enabled: true })
      .eq('id', pendingRow.id);
    setLoading(false);
    if (upErr) {
      setError(t('superadmin.couldNotSaveMfa'));
      return;
    }
    const next: SuperAdminRow = { ...pendingRow, totp_secret: setupSecret, totp_enabled: true };
    setPendingRow(next);
    setRecoveryEmailInput(next.recovery_email?.trim() ?? '');
    setStep('setup-recovery');
  };

  const handleSaveRecoveryAndEnter = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    const email = recoveryEmailInput.trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError(t('superadmin.invalidRecoveryEmail'));
      return;
    }
    if (!pendingRow) return;
    setLoading(true);
    const { error: upErr } = await supabase
      .from('super_admins')
      .update({ recovery_email: email })
      .eq('id', pendingRow.id);
    setLoading(false);
    if (upErr) {
      setError(t('superadmin.couldNotSaveRecovery'));
      return;
    }
    finishLogin({ ...pendingRow, recovery_email: email }, 'mfa_enrollment');
  };

  const handleSendRecovery = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    const u = recoveryUsername.trim().toUpperCase();
    const em = recoveryEmailRequest.trim().toLowerCase();
    if (!u || !em) {
      setError(t('login.enterBoth'));
      return;
    }
    setLoading(true);
    const { data, error: fnErr } = await supabase.functions.invoke('superadmin-recovery-send', {
      body: { username: u, recovery_email: em },
    });
    setLoading(false);
    if (fnErr) {
      setError(fnErr.message || t('superadmin.recoverySendFailed'));
      return;
    }
    if (data && typeof data === 'object' && data.ok === false && 'error' in data && data.error) {
      setError(String(data.error));
      return;
    }
    setRecoveryInfo(
      data?.dev_code ? `${t('superadmin.devRecoveryCode')}: ${data.dev_code}` : '',
    );
    setRecoveryUsername(u);
    setStep('recovery-verify');
  };

  const handleVerifyRecovery = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    const code = recoveryCode.replace(/\D/g, '');
    if (code.length !== 6) {
      setError(t('superadmin.enterSixDigitRecovery'));
      return;
    }
    setLoading(true);
    const { data, error: fnErr } = await supabase.functions.invoke('superadmin-recovery-verify', {
      body: { username: recoveryUsername.trim().toUpperCase(), code },
    });
    setLoading(false);
    if (fnErr || !data?.ok || !data.profile) {
      setError(t('superadmin.invalidRecoveryCode'));
      return;
    }
    const p = data.profile as SuperadminProfile;
    finishLogin(p, 'recovery_email');
  };

  const otpauthUri =
    pendingRow && setupSecret ? buildTotpKeyUri(setupSecret, pendingRow.username) : '';

  return (
    <div className="w-full max-w-sm mx-auto">
      {variant === 'full' && step === 'password' && (
        <div className="flex flex-col items-center mb-10">
          <div className="w-20 h-20 rounded-2xl bg-amber-500/10 flex items-center justify-center mb-4">
            <Crown className="w-10 h-10 text-amber-500" />
          </div>
          <h1 className="page-title text-2xl text-center">{t('app.name')}</h1>
          <p className="text-muted-foreground text-xs mt-1 text-center">{t('app.subtitle')}</p>
          <p className="text-muted-foreground/80 text-[11px] mt-0.5 text-center">{t('app.tagline')}</p>
          <h2 className="page-title text-xl mt-4">{t('superadmin.login')}</h2>
          <p className="text-muted-foreground text-sm mt-1">{t('superadmin.loginSubtitle')}</p>
        </div>
      )}

      {variant === 'embedded' && step === 'password' && (
        <div className="flex items-center gap-2 mb-4 text-amber-600">
          <Shield className="w-5 h-5" />
          <span className="text-sm font-medium">{t('superadmin.login')}</span>
        </div>
      )}

      {step === 'password' && (
        <>
          {bioAvailable && (
            <button
              type="button"
              onClick={handleBiometricLogin}
              disabled={bioLoading}
              className="w-full mb-4 py-4 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-2 hover:bg-primary/10 transition-colors"
            >
              <Fingerprint className="w-8 h-8 text-primary" />
              <span className="text-sm font-medium text-primary">{t('biometric.loginButton')}</span>
            </button>
          )}

          <form onSubmit={handlePasswordSubmit} className="flex flex-col gap-4">
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
                {t('superadmin.username')}
              </label>
              <input
                className="input-field font-mono uppercase"
                placeholder="SUPERADMIN"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
                {t('login.password')}
              </label>
              <div className="relative">
                <input
                  className="input-field pr-10"
                  type={showPassword ? 'text' : 'password'}
                  placeholder={t('login.passwordPlaceholder')}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <button
                  type="button"
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>
            {error && <p className="text-destructive text-sm text-center">{error}</p>}
            <button type="submit" className="btn-primary mt-2" disabled={loading}>
              {loading ? t('login.loggingIn') : t('superadmin.loginButton')}
            </button>
            <button
              type="button"
              className="text-xs text-muted-foreground text-center underline"
              onClick={() => {
                setError('');
                setRecoveryInfo('');
                setStep('recovery-request');
              }}
            >
              {t('superadmin.lockedOutRecovery')}
            </button>
            {onBack && (
              <button type="button" className="text-xs text-muted-foreground text-center mt-2 underline" onClick={onBack}>
                ← {t('admin.backToMain')}
              </button>
            )}
          </form>
        </>
      )}

      {step === 'totp' && pendingRow && (
        <form onSubmit={handleTotpSubmit} className="flex flex-col gap-4">
          <p className="text-sm text-muted-foreground text-center">{t('superadmin.enterAuthenticatorCode')}</p>
          <input
            className="input-field text-center text-lg tracking-[0.4em] font-mono"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={8}
            value={totpCode}
            onChange={(e) => setTotpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          />
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary">
            {t('superadmin.verifyAndContinue')}
          </button>
          <button
            type="button"
            className="text-xs text-muted-foreground text-center underline"
            onClick={() => {
              setStep('password');
              setPendingRow(null);
              setTotpCode('');
              setError('');
            }}
          >
            {t('superadmin.backToLogin')}
          </button>
        </form>
      )}

      {step === 'setup-qr' && pendingRow && setupSecret && (
        <div className="flex flex-col gap-4 items-center">
          <h3 className="text-sm font-semibold text-center">{t('superadmin.mfaSetupTitle')}</h3>
          <p className="text-xs text-muted-foreground text-center">{t('superadmin.mfaSetupSubtitle')}</p>
          <img
            src={totpQrImageUrl(otpauthUri)}
            alt=""
            className="rounded-lg border border-border bg-white p-2"
            width={196}
            height={196}
          />
          <p className="text-[10px] text-muted-foreground font-mono break-all text-center">{setupSecret}</p>
          <button type="button" className="btn-primary w-full" onClick={() => setStep('setup-totp-verify')}>
            {t('superadmin.iHaveAddedApp')}
          </button>
        </div>
      )}

      {step === 'setup-totp-verify' && pendingRow && setupSecret && (
        <form onSubmit={handleSetupTotpVerify} className="flex flex-col gap-4">
          <p className="text-sm text-muted-foreground text-center">{t('superadmin.enterCodeFromApp')}</p>
          <input
            className="input-field text-center text-lg tracking-[0.4em] font-mono"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={8}
            value={totpCode}
            onChange={(e) => setTotpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          />
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t('superadmin.verifyAndContinue')}
          </button>
          <button type="button" className="text-xs text-muted-foreground underline text-center" onClick={() => setStep('setup-qr')}>
            {t('superadmin.backToQr')}
          </button>
        </form>
      )}

      {step === 'setup-recovery' && pendingRow && (
        <form onSubmit={handleSaveRecoveryAndEnter} className="flex flex-col gap-4">
          <h3 className="text-sm font-semibold text-center">{t('superadmin.recoveryEmailStepTitle')}</h3>
          <p className="text-xs text-muted-foreground text-center">{t('superadmin.recoveryEmailStepHelp')}</p>
          <input
            type="email"
            className="input-field"
            value={recoveryEmailInput}
            onChange={(e) => setRecoveryEmailInput(e.target.value)}
            placeholder="you@example.com"
          />
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t('superadmin.finishAndEnter')}
          </button>
        </form>
      )}

      {step === 'recovery-request' && (
        <form onSubmit={handleSendRecovery} className="flex flex-col gap-4">
          <p className="text-sm text-muted-foreground text-center">{t('superadmin.recoveryRequestHelp')}</p>
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
              {t('superadmin.username')}
            </label>
            <input
              className="input-field font-mono uppercase"
              value={recoveryUsername}
              onChange={(e) => setRecoveryUsername(e.target.value)}
            />
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
              {t('superadmin.recoveryEmailLabel')}
            </label>
            <input
              type="email"
              className="input-field"
              value={recoveryEmailRequest}
              onChange={(e) => setRecoveryEmailRequest(e.target.value)}
            />
          </div>
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t('superadmin.sendRecoveryCode')}
          </button>
          <button
            type="button"
            className="text-xs text-muted-foreground underline text-center"
            onClick={() => {
              setError('');
              setStep('password');
            }}
          >
            {t('superadmin.backToLogin')}
          </button>
        </form>
      )}

      {step === 'recovery-verify' && (
        <form onSubmit={handleVerifyRecovery} className="flex flex-col gap-4">
          {recoveryInfo ? (
            <p className="text-xs text-amber-600 dark:text-amber-400 text-center bg-amber-500/10 rounded-lg p-2">
              {recoveryInfo}
            </p>
          ) : null}
          <p className="text-sm text-muted-foreground text-center">{t('superadmin.enterRecoveryCode')}</p>
          <input
            className="input-field text-center text-lg tracking-[0.4em] font-mono"
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="000000"
            maxLength={8}
            value={recoveryCode}
            onChange={(e) => setRecoveryCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          />
          {error && <p className="text-destructive text-sm text-center">{error}</p>}
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : t('superadmin.verifyAndContinue')}
          </button>
          <button
            type="button"
            className="text-xs text-muted-foreground underline text-center"
            onClick={() => {
              setError('');
              setRecoveryCode('');
              setStep('recovery-request');
            }}
          >
            {t('superadmin.resendRecovery')}
          </button>
        </form>
      )}
    </div>
  );
};

export default SuperadminLoginForm;
