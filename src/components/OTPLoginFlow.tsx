import { useState, useRef, useEffect } from 'react';
import { Phone, ArrowLeft, Loader2, MessageSquare } from 'lucide-react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';

interface Props {
  onVerified: (phone: string) => void;
  onBack?: () => void;
  title?: string;
  subtitle?: string;
}

const OTPLoginFlow = ({ onVerified, onBack, title = 'Login with OTP', subtitle = 'Enter your registered phone number' }: Props) => {
  const { t } = useLanguage();
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [countdown, setCountdown] = useState(0);
  const [devOtp, setDevOtp] = useState('');
  const otpRefs = useRef<(HTMLInputElement | null)[]>([]);

  // Countdown timer for resend
  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown(c => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  // WebOTP auto-read for mobile
  useEffect(() => {
    if (step !== 'otp') return;
    if ('OTPCredential' in window) {
      const ac = new AbortController();
      (navigator as any).credentials?.get({
        otp: { transport: ['sms'] },
        signal: ac.signal,
      }).then((otpCredential: any) => {
        if (otpCredential?.code) {
          const digits = otpCredential.code.split('').slice(0, 6);
          setOtp(digits);
          // Auto-submit
          handleVerifyOtp(digits.join(''));
        }
      }).catch(() => {});
      return () => ac.abort();
    }
  }, [step]);

  const handleSendOtp = async () => {
    if (!phone || phone.length < 10) {
      setError('Enter a valid 10-digit phone number');
      return;
    }
    setLoading(true);
    setError('');

    try {
      const { data, error: fnError } = await supabase.functions.invoke('send-otp', {
        body: { phone, countryCode: '+91' }
      });

      if (fnError) throw fnError;
      if (data?.error) { setError(data.error); setLoading(false); return; }

      // For development, show the OTP
      if (data?.dev_otp) setDevOtp(data.dev_otp);

      setStep('otp');
      setCountdown(30);
      setTimeout(() => otpRefs.current[0]?.focus(), 100);
    } catch (err: any) {
      setError(err.message || 'Failed to send OTP');
    }
    setLoading(false);
  };

  const handleOtpChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.slice(-1);
    setOtp(newOtp);

    // Auto-focus next
    if (value && index < 5) {
      otpRefs.current[index + 1]?.focus();
    }

    // Auto-submit when all filled
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

  const handleVerifyOtp = async (otpCode: string) => {
    setLoading(true);
    setError('');
    try {
      const { data, error: fnError } = await supabase.functions.invoke('verify-otp', {
        body: { phone, otp: otpCode, countryCode: '+91' }
      });

      if (fnError) throw fnError;
      if (!data?.verified) { setError(data?.error || 'Invalid OTP'); setLoading(false); return; }

      onVerified(phone);
    } catch (err: any) {
      setError(err.message || 'Verification failed');
    }
    setLoading(false);
  };

  return (
    <div className="w-full max-w-sm mx-auto">
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
            <button onClick={onBack} className="text-xs text-muted-foreground text-center mt-1 underline flex items-center justify-center gap-1">
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

          {devOtp && (
            <div className="bg-amber-500/10 border border-amber-500/30 rounded-lg p-2 text-center">
              <p className="text-xs text-amber-600 font-medium">Dev Mode OTP: <span className="font-mono font-bold">{devOtp}</span></p>
            </div>
          )}

          <div className="flex justify-center gap-2" onPaste={handleOtpPaste}>
            {otp.map((digit, i) => (
              <input
                key={i}
                ref={el => { otpRefs.current[i] = el; }}
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
            <button onClick={() => { setStep('phone'); setOtp(['','','','','','']); setError(''); }}
              className="text-muted-foreground underline flex items-center gap-1">
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
