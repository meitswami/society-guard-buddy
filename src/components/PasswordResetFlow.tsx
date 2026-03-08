import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Mail, KeyRound, ArrowLeft } from 'lucide-react';
import { toast } from 'sonner';
import { auditPasswordReset } from '@/lib/auditLogger';

interface Props {
  userType: 'admin' | 'resident';
  onBack: () => void;
}

const PasswordResetFlow = ({ userType, onBack }: Props) => {
  const [step, setStep] = useState<'email' | 'token' | 'done'>('email');
  const [email, setEmail] = useState('');
  const [token, setToken] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetToken, setResetToken] = useState('');
  const [userId, setUserId] = useState('');

  const requestReset = async () => {
    if (!email) { toast.error('Enter your email'); return; }
    setLoading(true);

    // Find user by email
    const table = userType === 'admin' ? 'admins' : 'resident_users';
    const { data: user } = await supabase.from(table).select('id, email, name').eq('email', email).single();
    if (!user) {
      toast.error('Email not found');
      setLoading(false); return;
    }

    // Generate a 6-digit token
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString(); // 30 min

    await supabase.from('password_reset_tokens').insert([{
      user_type: userType, user_id: user.id, email, token: code, expires_at: expires,
    }]);

    setResetToken(code);
    setUserId(user.id);

    // Try to send email via edge function
    try {
      await supabase.functions.invoke('send-reset-email', {
        body: { email, code, name: user.name, userType },
      });
      toast.success('Reset code sent to your email');
    } catch {
      // If edge function doesn't exist yet, show code on screen
      toast.success(`Reset code: ${code} (email sending not configured yet)`);
    }

    setStep('token');
    setLoading(false);
  };

  const verifyAndReset = async () => {
    if (token !== resetToken) { toast.error('Invalid code'); return; }
    if (!newPassword || newPassword.length < 4) { toast.error('Password must be at least 4 characters'); return; }
    if (newPassword !== confirmPassword) { toast.error('Passwords do not match'); return; }

    setLoading(true);
    // Check token validity
    const { data: tokenData } = await supabase.from('password_reset_tokens')
      .select('*').eq('token', token).eq('used', false).single();
    if (!tokenData || new Date(tokenData.expires_at) < new Date()) {
      toast.error('Token expired or invalid');
      setLoading(false); return;
    }

    // Update password
    const table = userType === 'admin' ? 'admins' : 'resident_users';
    await supabase.from(table).update({ password: newPassword }).eq('id', userId);

    // Mark token as used
    await supabase.from('password_reset_tokens').update({ used: true }).eq('id', tokenData.id);

    auditPasswordReset(userType, userId, email, 'email_reset');
    toast.success('Password reset successfully!');
    setStep('done');
    setLoading(false);
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background">
      <div className="w-full max-w-sm">
        <button onClick={onBack} className="flex items-center gap-1 text-sm text-muted-foreground mb-6">
          <ArrowLeft className="w-4 h-4" /> Back to Login
        </button>

        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
            {step === 'email' ? <Mail className="w-8 h-8 text-primary" /> : <KeyRound className="w-8 h-8 text-primary" />}
          </div>
          <h1 className="text-xl font-bold">
            {step === 'email' ? 'Reset Password' : step === 'token' ? 'Enter Reset Code' : 'Done!'}
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            {step === 'email' ? `Enter your ${userType} email` : step === 'token' ? 'Check your email for the code' : 'Password has been reset'}
          </p>
        </div>

        {step === 'email' && (
          <div className="flex flex-col gap-4">
            <input className="input-field" type="email" placeholder="Email address" value={email} onChange={e => setEmail(e.target.value)} />
            <button onClick={requestReset} className="btn-primary" disabled={loading}>
              {loading ? 'Sending...' : 'Send Reset Code'}
            </button>
          </div>
        )}

        {step === 'token' && (
          <div className="flex flex-col gap-4">
            <input className="input-field font-mono text-center text-lg tracking-widest" placeholder="6-digit code" maxLength={6}
              value={token} onChange={e => setToken(e.target.value.replace(/\D/g, ''))} />
            <input className="input-field" type="password" placeholder="New Password" value={newPassword} onChange={e => setNewPassword(e.target.value)} />
            <input className="input-field" type="password" placeholder="Confirm Password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} />
            <button onClick={verifyAndReset} className="btn-primary" disabled={loading}>
              {loading ? 'Resetting...' : 'Reset Password'}
            </button>
          </div>
        )}

        {step === 'done' && (
          <button onClick={onBack} className="btn-primary w-full">Back to Login</button>
        )}
      </div>
    </div>
  );
};

export default PasswordResetFlow;
