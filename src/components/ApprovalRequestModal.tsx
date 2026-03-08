import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { Send, Clock, Check, X, Loader2 } from 'lucide-react';

interface Props {
  visitorName: string;
  visitorPhone: string;
  flatNumber: string;
  purpose: string;
  onResult: (status: 'approved' | 'rejected' | 'timeout') => void;
  onCancel: () => void;
}

const ApprovalRequestModal = ({ visitorName, visitorPhone, flatNumber, purpose, onResult, onCancel }: Props) => {
  const { t } = useLanguage();
  const { currentGuard } = useStore();
  const [status, setStatus] = useState<'sending' | 'waiting' | 'approved' | 'rejected' | 'timeout'>('sending');
  const [requestId, setRequestId] = useState<string | null>(null);
  const [timer, setTimer] = useState(120); // 2 min timeout

  useEffect(() => {
    const sendRequest = async () => {
      const { data, error } = await supabase.from('approval_requests').insert({
        visitor_name: visitorName,
        visitor_phone: visitorPhone || null,
        flat_number: flatNumber,
        flat_id: '00000000-0000-0000-0000-000000000000', // Will be resolved
        guard_id: currentGuard?.id || '',
        guard_name: currentGuard?.name || '',
        purpose: purpose || null,
        status: 'pending',
      }).select().single();

      if (data) {
        setRequestId(data.id);
        setStatus('waiting');
      } else {
        console.error('Failed to create approval request', error);
        onCancel();
      }
    };

    // Find flat_id first
    const init = async () => {
      const { data: flat } = await supabase
        .from('flats')
        .select('id')
        .eq('flat_number', flatNumber)
        .single();

      if (flat) {
        const { data, error } = await supabase.from('approval_requests').insert({
          visitor_name: visitorName,
          visitor_phone: visitorPhone || null,
          flat_number: flatNumber,
          flat_id: flat.id,
          guard_id: currentGuard?.id || '',
          guard_name: currentGuard?.name || '',
          purpose: purpose || null,
          status: 'pending',
        }).select().single();

        if (data) {
          setRequestId(data.id);
          setStatus('waiting');
        }
      } else {
        // No flat found, just create with dummy
        const { data } = await supabase.from('approval_requests').insert({
          visitor_name: visitorName,
          visitor_phone: visitorPhone || null,
          flat_number: flatNumber,
          flat_id: '4906a9a4-1b5b-404d-90bc-d5f9ab1c4637', // fallback
          guard_id: currentGuard?.id || '',
          guard_name: currentGuard?.name || '',
          purpose: purpose || null,
          status: 'pending',
        }).select().single();

        if (data) {
          setRequestId(data.id);
          setStatus('waiting');
        }
      }
    };

    init();
  }, []);

  // Listen for realtime updates on this request
  useEffect(() => {
    if (!requestId) return;

    const channel = supabase
      .channel(`approval-${requestId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'approval_requests',
        filter: `id=eq.${requestId}`,
      }, (payload) => {
        const newStatus = payload.new.status;
        if (newStatus === 'approved' || newStatus === 'rejected') {
          setStatus(newStatus);
          setTimeout(() => onResult(newStatus), 1500);
        }
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [requestId, onResult]);

  // Countdown timer
  useEffect(() => {
    if (status !== 'waiting') return;
    if (timer <= 0) {
      setStatus('timeout');
      onResult('timeout');
      return;
    }
    const interval = setInterval(() => setTimer(t => t - 1), 1000);
    return () => clearInterval(interval);
  }, [status, timer, onResult]);

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center px-4">
      <div className="bg-card rounded-2xl p-6 w-full max-w-sm border border-border shadow-xl">
        <div className="flex flex-col items-center text-center gap-4">
          {status === 'sending' && (
            <>
              <Loader2 className="w-10 h-10 text-primary animate-spin" />
              <p className="text-sm text-muted-foreground">{t('approval.sending')}</p>
            </>
          )}

          {status === 'waiting' && (
            <>
              <div className="relative">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                  <Send className="w-7 h-7 text-primary" />
                </div>
                <span className="absolute -top-1 -right-1 bg-warning text-warning-foreground text-xs px-1.5 py-0.5 rounded-full font-mono">
                  {Math.floor(timer / 60)}:{(timer % 60).toString().padStart(2, '0')}
                </span>
              </div>
              <div>
                <p className="font-semibold text-foreground">{t('approval.waitingTitle')}</p>
                <p className="text-xs text-muted-foreground mt-1">
                  {t('approval.waitingFor')} {flatNumber}
                </p>
                <p className="text-xs text-muted-foreground mt-1">{visitorName} · {purpose}</p>
              </div>
              <div className="flex gap-3 w-full">
                <button onClick={onCancel} className="flex-1 py-2 rounded-lg bg-secondary text-secondary-foreground text-sm font-medium">
                  {t('common.cancel')}
                </button>
              </div>
            </>
          )}

          {status === 'approved' && (
            <>
              <div className="w-16 h-16 rounded-full bg-green-500/20 flex items-center justify-center">
                <Check className="w-8 h-8 text-green-600" />
              </div>
              <p className="font-semibold text-green-600">{t('approval.approved')}</p>
            </>
          )}

          {status === 'rejected' && (
            <>
              <div className="w-16 h-16 rounded-full bg-destructive/20 flex items-center justify-center">
                <X className="w-8 h-8 text-destructive" />
              </div>
              <p className="font-semibold text-destructive">{t('approval.rejected')}</p>
            </>
          )}

          {status === 'timeout' && (
            <>
              <div className="w-16 h-16 rounded-full bg-secondary flex items-center justify-center">
                <Clock className="w-8 h-8 text-muted-foreground" />
              </div>
              <p className="font-semibold text-muted-foreground">{t('approval.timeout')}</p>
              <button onClick={onCancel} className="btn-primary w-full text-sm">{t('common.cancel')}</button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default ApprovalRequestModal;
