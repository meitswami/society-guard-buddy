import { useState } from 'react';
import { Lock, Fingerprint, Smartphone, X } from 'lucide-react';
import { useBiometric } from '@/hooks/useBiometric';
import { verifyAdminPassword } from '@/lib/adminVerify';
import { logAuditEvent } from '@/lib/auditLogger';
import { toast } from 'sonner';

type Props = {
  open: boolean;
  title: string;
  adminId: string;
  adminName: string;
  actionLabel: string;
  onClose: () => void;
  onVerified: () => void;
};

/**
 * Re-authentication before sensitive resident-directory changes.
 * Supports password re-entry and device biometric (if registered for this admin).
 * SMS OTP is reserved for when admin phone + backend sender exist.
 */
const SensitiveAdminVerifyModal = ({
  open,
  title,
  adminId,
  adminName,
  actionLabel,
  onClose,
  onVerified,
}: Props) => {
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const { authenticate, loading: bioLoading } = useBiometric();

  if (!open) return null;

  const handlePassword = async () => {
    setBusy(true);
    const ok = await verifyAdminPassword(adminId, password);
    setBusy(false);
    if (!ok) {
      toast.error('Incorrect password');
      await logAuditEvent({
        event_type: 'sensitive_action_denied',
        user_type: 'admin',
        user_id: adminId,
        user_name: adminName,
        details: { action: actionLabel, method: 'password' },
        severity: 'warning',
      });
      return;
    }
    await logAuditEvent({
      event_type: 'sensitive_action_verified',
      user_type: 'admin',
      user_id: adminId,
      user_name: adminName,
      details: { action: actionLabel, method: 'password' },
      severity: 'info',
    });
    setPassword('');
    onVerified();
    onClose();
  };

  const handleBiometric = async () => {
    setBusy(true);
    const result = await authenticate('admin');
    setBusy(false);
    if (!result || result.userId !== adminId) {
      toast.error('Biometric verification failed');
      await logAuditEvent({
        event_type: 'sensitive_action_denied',
        user_type: 'admin',
        user_id: adminId,
        user_name: adminName,
        details: { action: actionLabel, method: 'biometric' },
        severity: 'warning',
      });
      return;
    }
    await logAuditEvent({
      event_type: 'sensitive_action_verified',
      user_type: 'admin',
      user_id: adminId,
      user_name: adminName,
      details: { action: actionLabel, method: 'biometric' },
      severity: 'info',
    });
    onVerified();
    onClose();
  };

  const handleOtpStub = () => {
    toast.info('SMS OTP requires admin phone on file and SMS setup (not enabled in this build). Use password or biometric.');
  };

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/50">
      <div className="bg-card border border-border rounded-xl shadow-lg w-full max-w-sm p-4 relative">
        <button
          type="button"
          className="absolute top-3 right-3 p-1 rounded-lg text-muted-foreground hover:bg-muted"
          onClick={onClose}
          aria-label="Close"
        >
          <X className="w-4 h-4" />
        </button>
        <div className="flex items-center gap-2 mb-2 pr-8">
          <Lock className="w-5 h-5 text-primary" />
          <h3 className="font-semibold text-sm">{title}</h3>
        </div>
        <p className="text-xs text-muted-foreground mb-3">
          Confirm your identity to {actionLabel}. This is logged for security.
        </p>

        <div className="space-y-2 mb-3">
          <input
            type="password"
            className="input-field text-sm"
            placeholder="Admin password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
          />
          <button
            type="button"
            disabled={busy}
            onClick={() => void handlePassword()}
            className="btn-primary w-full text-sm py-2"
          >
            Continue with password
          </button>
        </div>

        <div className="flex gap-2">
          <button
            type="button"
            disabled={busy || bioLoading}
            onClick={() => void handleBiometric()}
            className="flex-1 btn-secondary text-xs py-2 flex items-center justify-center gap-1"
          >
            <Fingerprint className="w-3.5 h-3.5" />
            Biometric
          </button>
          <button
            type="button"
            onClick={handleOtpStub}
            className="flex-1 btn-secondary text-xs py-2 flex items-center justify-center gap-1 opacity-80"
          >
            <Smartphone className="w-3.5 h-3.5" />
            SMS OTP
          </button>
        </div>
        <p className="text-[10px] text-muted-foreground mt-2 text-center">
          Biometric only works if you registered it in Admin → Biometric.
        </p>
      </div>
    </div>
  );
};

export default SensitiveAdminVerifyModal;
