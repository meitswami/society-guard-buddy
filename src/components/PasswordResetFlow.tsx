import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Mail, KeyRound, ArrowLeft, Phone, AlertTriangle } from 'lucide-react';
import { toast } from 'sonner';
import { auditPasswordReset } from '@/lib/auditLogger';

interface Props {
  userType: 'admin' | 'resident';
  onBack: () => void;
}

const PasswordResetFlow = ({ userType, onBack }: Props) => {
  const [step, setStep] = useState<'input' | 'token' | 'done' | 'no-email'>('input');
  const [method, setMethod] = useState<'email' | 'phone'>('phone');
  const [identifier, setIdentifier] = useState('');
  const [token, setToken] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetToken, setResetToken] = useState('');
  const [userId, setUserId] = useState('');
  const [userName, setUserName] = useState('');
  const [flatNumber, setFlatNumber] = useState('');
  const [askAdminLoading, setAskAdminLoading] = useState(false);

  const requestReset = async () => {
    if (!identifier) { toast.error('Enter your ' + (method === 'email' ? 'email' : 'phone number')); return; }
    setLoading(true);

    const table = userType === 'admin' ? 'admins' : 'resident_users';

    let user: any = null;
    if (method === 'email') {
      const { data } = await supabase.from(table).select('*').eq('email', identifier).single();
      user = data;
    } else {
      if (userType === 'resident') {
        const { data } = await supabase.from('resident_users').select('*').eq('phone', identifier).single();
        user = data;
      } else {
        const { data } = await supabase.from('admins').select('*').eq('admin_id', identifier.toUpperCase()).single();
        user = data;
      }
    }

    if (!user) {
      toast.error('Account not found');
      setLoading(false); return;
    }

    setUserId(user.id);
    setUserName(user.name);
    setFlatNumber(user.flat_number || '');

    // Check if email exists
    if (!user.email) {
      setStep('no-email');
      setLoading(false);
      return;
    }

    // Generate a 6-digit token
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    await supabase.from('password_reset_tokens').insert([{
      user_type: userType, user_id: user.id, email: user.email, token: code, expires_at: expires,
    }]);

    setResetToken(code);

    // Try to send email via edge function
    try {
      await supabase.functions.invoke('send-reset-email', {
        body: { email: user.email, code, name: user.name, userType },
      });
      toast.success('Reset code sent to your email');
    } catch {
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
    const { data: tokenData } = await supabase.from('password_reset_tokens')
      .select('*').eq('token', token).eq('used', false).single();
    if (!tokenData || new Date(tokenData.expires_at) < new Date()) {
      toast.error('Token expired or invalid');
      setLoading(false); return;
    }

    const table = userType === 'admin' ? 'admins' : 'resident_users';
    
    if (userType === 'resident') {
      // Get flat_id to update all flatmates
      const { data: resUser } = await supabase.from('resident_users').select('flat_id').eq('id', userId).single();
      if (resUser) {
        await supabase.from('resident_users').update({ password: newPassword }).eq('flat_id', resUser.flat_id);
      }
    } else {
      await supabase.from(table).update({ password: newPassword }).eq('id', userId);
    }

    await supabase.from('password_reset_tokens').update({ used: true }).eq('id', tokenData.id);
    auditPasswordReset(userType, userId, identifier, 'email_reset');
    toast.success('Password reset successfully!');
    setStep('done');
    setLoading(false);
  };

  const askAdminToReset = async () => {
    setAskAdminLoading(true);

    // Find all admins for this user's society
    let societyId: string | null = null;
    if (userType === 'resident') {
      const { data: resUser } = await supabase.from('resident_users').select('flat_id').eq('id', userId).single();
      if (resUser) {
        const { data: flat } = await supabase.from('flats').select('society_id').eq('id', resUser.flat_id).single();
        if (flat) societyId = flat.society_id;
      }
    }

    // Create a notification for admin
    await supabase.from('notifications').insert({
      title: '🔑 Password Reset Request',
      message: `${userName} (${userType}, ${flatNumber ? 'Flat ' + flatNumber : 'ID: ' + identifier}) is requesting a password reset. They don't have an email set. Please reset their password from the admin panel.`,
      type: 'password_reset_request',
      target_type: 'admin',
      society_id: societyId,
    });

    toast.success('Request sent to admin! They will reset your password.');
    setAskAdminLoading(false);
    setStep('done');
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background">
      <div className="w-full max-w-sm">
        <button onClick={onBack} className="flex items-center gap-1 text-sm text-muted-foreground mb-6">
          <ArrowLeft className="w-4 h-4" /> Back to Login
        </button>

        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
            {step === 'no-email' ? <AlertTriangle className="w-8 h-8 text-warning" /> :
             step === 'input' ? <Mail className="w-8 h-8 text-primary" /> : <KeyRound className="w-8 h-8 text-primary" />}
          </div>
          <h1 className="text-xl font-bold">
            {step === 'input' ? 'Reset Password' : step === 'token' ? 'Enter Reset Code' : step === 'no-email' ? 'No Email Found' : 'Done!'}
          </h1>
          <p className="text-sm text-muted-foreground mt-1 text-center">
            {step === 'input' ? 'Find your account by email or phone' :
             step === 'token' ? 'Check your email for the code' :
             step === 'no-email' ? 'Your account has no email attached' : 'Password has been reset'}
          </p>
        </div>

        {step === 'input' && (
          <div className="flex flex-col gap-4">
            {/* Method toggle */}
            <div className="flex gap-2">
              <button onClick={() => { setMethod('phone'); setIdentifier(''); }}
                className={`flex-1 py-2 rounded-lg text-xs font-medium flex items-center justify-center gap-1.5 ${method === 'phone' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
                <Phone className="w-3.5 h-3.5" /> {userType === 'admin' ? 'Admin ID' : 'Phone'}
              </button>
              <button onClick={() => { setMethod('email'); setIdentifier(''); }}
                className={`flex-1 py-2 rounded-lg text-xs font-medium flex items-center justify-center gap-1.5 ${method === 'email' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
                <Mail className="w-3.5 h-3.5" /> Email
              </button>
            </div>

            <input className="input-field" type={method === 'email' ? 'email' : 'text'}
              placeholder={method === 'email' ? 'Email address' : (userType === 'admin' ? 'Admin ID' : '10-digit phone number')}
              value={identifier}
              onChange={e => setIdentifier(method === 'phone' && userType === 'resident' ? e.target.value.replace(/\D/g, '') : e.target.value)}
              maxLength={method === 'phone' && userType === 'resident' ? 10 : undefined}
            />
            <button onClick={requestReset} className="btn-primary" disabled={loading}>
              {loading ? 'Finding account...' : 'Find Account & Send Code'}
            </button>
          </div>
        )}

        {step === 'no-email' && (
          <div className="flex flex-col gap-4">
            <div className="bg-warning/10 border border-warning/30 rounded-xl p-4 text-center">
              <p className="text-sm text-foreground mb-1">
                <strong>{userName}</strong>{flatNumber ? ` (Flat ${flatNumber})` : ''}
              </p>
              <p className="text-xs text-muted-foreground">
                No email is linked to this account. You can ask your admin to reset your password.
              </p>
            </div>
            <button onClick={askAdminToReset} className="btn-primary flex items-center justify-center gap-2" disabled={askAdminLoading}>
              <Mail className="w-4 h-4" />
              {askAdminLoading ? 'Sending request...' : 'Ask Admin to Change Password'}
            </button>
            <button onClick={() => { setStep('input'); setIdentifier(''); }} className="text-xs text-muted-foreground text-center underline">
              Try a different account
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
