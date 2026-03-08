import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { KeyRound, Check, X, Loader2 } from 'lucide-react';
import { format } from 'date-fns';

interface Props {
  onResult: (valid: boolean, passData?: { guestName: string; flatNumber: string; guestPhone: string }) => void;
  onCancel: () => void;
}

const OTPVerifyModal = ({ onResult, onCancel }: Props) => {
  const { t } = useLanguage();
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleVerify = async () => {
    if (otp.length !== 6) {
      setError(t('otp.enterSixDigit'));
      return;
    }
    setLoading(true);
    setError('');
    const today = format(new Date(), 'yyyy-MM-dd');
    const now = format(new Date(), 'HH:mm:ss');

    const { data } = await supabase
      .from('visitor_passes')
      .select('*')
      .eq('otp_code', otp)
      .eq('status', 'active')
      .eq('valid_date', today)
      .single();

    setLoading(false);

    if (!data) {
      setError(t('otp.invalid'));
      return;
    }

    // Check time slot
    if (data.time_slot_start && data.time_slot_end) {
      if (now < data.time_slot_start || now > data.time_slot_end) {
        setError(t('otp.outsideTimeSlot'));
        return;
      }
    }

    // Mark as used
    await supabase.from('visitor_passes').update({
      status: 'used', used_at: new Date().toISOString(),
    }).eq('id', data.id);

    onResult(true, {
      guestName: data.guest_name || 'Guest',
      flatNumber: data.flat_number,
      guestPhone: data.guest_phone || '',
    });
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center px-4">
      <div className="bg-card rounded-2xl p-6 w-full max-w-sm border border-border shadow-xl">
        <div className="flex flex-col items-center text-center gap-4">
          <div className="w-14 h-14 rounded-full bg-primary/10 flex items-center justify-center">
            <KeyRound className="w-7 h-7 text-primary" />
          </div>
          <div>
            <p className="font-semibold text-foreground">{t('otp.verifyTitle')}</p>
            <p className="text-xs text-muted-foreground mt-1">{t('otp.verifySubtitle')}</p>
          </div>

          <input
            className="input-field text-center text-2xl font-mono tracking-[0.5em] font-bold"
            placeholder="000000"
            maxLength={6}
            value={otp}
            onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
            autoFocus
          />

          {error && <p className="text-destructive text-sm">{error}</p>}

          <div className="flex gap-3 w-full">
            <button onClick={onCancel} className="flex-1 py-2.5 rounded-lg bg-secondary text-secondary-foreground text-sm font-medium">
              {t('common.cancel')}
            </button>
            <button onClick={handleVerify} disabled={loading}
              className="flex-1 py-2.5 rounded-lg bg-primary text-primary-foreground text-sm font-medium flex items-center justify-center gap-2">
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
              {t('otp.verify')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default OTPVerifyModal;
