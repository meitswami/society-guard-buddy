import { useState, useRef, useEffect, useCallback } from 'react';
import { Phone, ArrowLeft, Loader2, MessageSquare } from 'lucide-react';
import {
  RecaptchaVerifier,
  signInWithPhoneNumber,
  signOut,
  type ConfirmationResult,
} from 'firebase/auth';
import { getFirebaseAuth, isFirebaseConfigured } from '@/lib/firebase';

interface Props {
  onVerified: (phone: string) => void;
  onBack?: () => void;
  title?: string;
  subtitle?: string;
}

function formatFirebaseAuthError(err: unknown): string {
  const code = err && typeof err === 'object' && 'code' in err ? String((err as { code: string }).code) : '';
  switch (code) {
    case 'auth/invalid-phone-number':
      return 'Invalid phone number.';
    case 'auth/missing-phone-number':
      return 'Enter a valid phone number.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Try again later.';
    case 'auth/invalid-verification-code':
      return 'Invalid code.';
    case 'auth/code-expired':
      return 'Code expired. Request a new one.';
    case 'auth/captcha-check-failed':
      return 'Security check failed. Try again.';
    case 'auth/quota-exceeded':
      return 'SMS quota exceeded. Contact support.';
    default:
      return 'Something went wrong. Try again.';
  }
}

const OTPLoginFlow = ({ onVerified, onBack, title = 'Login with OTP', subtitle = 'Enter your registered phone number' }: Props) => {
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [countdown, setCountdown] = useState(0);
  const otpRefs = useRef<(HTMLInputElement | null)[]>([]);
  const confirmationRef = useRef<ConfirmationResult | null>(null);

  const handleVerifyOtp = useCallback(
    async (otpCode: string) => {
      const cr = confirmationRef.current;
      if (!cr) {
        setError('Session expired. Tap Resend OTP.');
        return;
      }
      setLoading(true);
      setError('');
      try {
        await cr.confirm(otpCode);
        await signOut(getFirebaseAuth());
        confirmationRef.current = null;
        onVerified(phone);
      } catch (err: unknown) {
        setError(formatFirebaseAuthError(err));
      } finally {
        setLoading(false);
      }
    },
    [phone, onVerified]
  );

  useEffect(() => {
    if (countdown <= 0) return;
    const timer = setTimeout(() => setCountdown(c => c - 1), 1000);
    return () => clearTimeout(timer);
  }, [countdown]);

  // WebOTP auto-read for mobile (works when the SMS matches the browser’s one-time-code format)
  useEffect(() => {
    if (step !== 'otp') return;
    if (!('OTPCredential' in window)) return;
    const ac = new AbortController();
    (navigator as unknown as { credentials?: { get: (opts: object) => Promise<{ code?: string }> } }).credentials
      ?.get({
        otp: { transport: ['sms'] as const },
        signal: ac.signal,
      })
      .then((otpCredential: { code?: string }) => {
        const code = otpCredential?.code?.replace(/\D/g, '').slice(0, 6) ?? '';
        if (code.length === 6) {
          setOtp(code.split(''));
          handleVerifyOtp(code);
        }
      })
      .catch(() => {});
    return () => ac.abort();
  }, [step, handleVerifyOtp]);

  const handleSendOtp = async () => {
    if (!phone || phone.length < 10) {
      setError('Enter a valid 10-digit phone number');
      return;
    }
    if (!isFirebaseConfigured()) {
      setError('SMS login is not configured. Add VITE_FIREBASE_* variables to your environment.');
      return;
    }

    setLoading(true);
    setError('');
    confirmationRef.current = null;

    const auth = getFirebaseAuth();
    const verifier = new RecaptchaVerifier(auth, 'firebase-phone-recaptcha', { size: 'invisible' });

    try {
      const confirmation = await signInWithPhoneNumber(auth, `+91${phone}`, verifier);
      confirmationRef.current = confirmation;
      setStep('otp');
      setOtp(['', '', '', '', '', '']);
      setCountdown(30);
      setTimeout(() => otpRefs.current[0]?.focus(), 100);
    } catch (err: unknown) {
      setError(formatFirebaseAuthError(err));
    } finally {
      try {
        verifier.clear();
      } catch {
        /* ignore */
      }
      setLoading(false);
    }
  };

  const handleOtpChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.slice(-1);
    setOtp(newOtp);

    if (value && index < 5) {
      otpRefs.current[index + 1]?.focus();
    }

    if (newOtp.every(d => d !== '')) {
      handleVerifyOtp(newOtp.join(''));
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      otpRefs.current[index - 1]?.focus();
    }
  };

  const handleOtpPaste = (e: React.ClipboardEvent) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (pasted.length === 6) {
      const digits = pasted.split('');
      setOtp(digits);
      handleVerifyOtp(pasted);
    }
  };

  const goBackToPhone = () => {
    setStep('phone');
    setOtp(['', '', '', '', '', '']);
    setError('');
    confirmationRef.current = null;
    void signOut(getFirebaseAuth()).catch(() => {});
  };

  return (
    <div className="w-full max-w-sm mx-auto">
      <div id="firebase-phone-recaptcha" className="sr-only" aria-hidden="true" />

      {step === 'phone' ? (
        <div className="flex flex-col gap-4">
          <div className="flex flex-col items-center mb-4">
            <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-3">
              <Phone className="w-8 h-8 text-primary" />
            </div>
            <h2 className="text-lg font-bold">{title}</h2>
            <p className="text-xs text-muted-foreground mt-1">{subtitle}</p>
          </div>

          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
              Phone Number
            </label>
            <div className="flex gap-2">
              <div className="input-field w-16 flex items-center justify-center text-sm font-mono text-muted-foreground">
                +91
              </div>
              <input
                className="input-field flex-1 font-mono"
                placeholder="10-digit number"
                type="tel"
                maxLength={10}
                value={phone}
                onChange={e => setPhone(e.target.value.replace(/\D/g, ''))}
                autoComplete="tel"
              />
            </div>
          </div>

          {error && <p className="text-destructive text-sm text-center">{error}</p>}

          <button onClick={handleSendOtp} className="btn-primary" disabled={loading}>
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Send OTP'}
          </button>

          {onBack && (
            <button
              onClick={onBack}
              className="text-xs text-muted-foreground text-center mt-1 underline flex items-center justify-center gap-1"
            >
              <ArrowLeft className="w-3 h-3" /> Back
            </button>
          )}
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          <div className="flex flex-col items-center mb-4">
            <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-3">
              <MessageSquare className="w-8 h-8 text-primary" />
            </div>
            <h2 className="text-lg font-bold">Verify OTP</h2>
            <p className="text-xs text-muted-foreground mt-1">
              Enter the 6-digit code sent to +91 {phone}
            </p>
          </div>

          <div className="flex justify-center gap-2" onPaste={handleOtpPaste}>
            {otp.map((digit, i) => (
              <input
                key={i}
                ref={el => {
                  otpRefs.current[i] = el;
                }}
                className="w-11 h-12 text-center text-lg font-bold font-mono rounded-xl border-2 border-border bg-background focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                type="text"
                inputMode="numeric"
                autoComplete={i === 0 ? 'one-time-code' : 'off'}
                maxLength={1}
                value={digit}
                onChange={e => handleOtpChange(i, e.target.value)}
                onKeyDown={e => handleOtpKeyDown(i, e)}
              />
            ))}
          </div>

          {error && <p className="text-destructive text-sm text-center">{error}</p>}

          <button
            onClick={() => handleVerifyOtp(otp.join(''))}
            className="btn-primary"
            disabled={loading || otp.some(d => d === '')}
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Verify & Login'}
          </button>

          <div className="flex items-center justify-between text-xs">
            <button onClick={goBackToPhone} className="text-muted-foreground underline flex items-center gap-1">
              <ArrowLeft className="w-3 h-3" /> Change Number
            </button>
            <button
              onClick={handleSendOtp}
              disabled={countdown > 0}
              className={`${countdown > 0 ? 'text-muted-foreground' : 'text-primary underline'}`}
            >
              {countdown > 0 ? `Resend in ${countdown}s` : 'Resend OTP'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default OTPLoginFlow;
