import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';

interface AuditEvent {
  event_type: string;
  user_type: 'guard' | 'admin' | 'resident' | 'superadmin';
  user_id?: string;
  user_name?: string;
  details?: Record<string, unknown>;
  severity?: 'info' | 'warning' | 'critical';
}

function getDeviceInfo() {
  const ua = navigator.userAgent;
  const isMobile = /Mobi|Android|iPhone|iPad/i.test(ua);
  const platform = navigator.platform || 'unknown';
  const language = navigator.language || 'unknown';
  
  let browser = 'Unknown';
  if (ua.includes('Firefox')) browser = 'Firefox';
  else if (ua.includes('Edg')) browser = 'Edge';
  else if (ua.includes('Chrome')) browser = 'Chrome';
  else if (ua.includes('Safari')) browser = 'Safari';

  let os = 'Unknown';
  if (ua.includes('Windows')) os = 'Windows';
  else if (ua.includes('Mac')) os = 'macOS';
  else if (ua.includes('Linux')) os = 'Linux';
  else if (ua.includes('Android')) os = 'Android';
  else if (ua.includes('iPhone') || ua.includes('iPad')) os = 'iOS';

  return {
    browser,
    os,
    platform,
    language,
    isMobile,
    screenWidth: window.screen?.width,
    screenHeight: window.screen?.height,
  };
}

async function getClientIP(): Promise<string> {
  try {
    const res = await fetch('https://api.ipify.org?format=json', { signal: AbortSignal.timeout(3000) });
    const data = await res.json();
    return data.ip || 'unknown';
  } catch {
    return 'unknown';
  }
}

export async function logAuditEvent(event: AuditEvent) {
  try {
    const [ip] = await Promise.all([getClientIP()]);
    const deviceInfo = getDeviceInfo();

    await supabase.from('audit_logs').insert([{
      society_id: useStore.getState().societyId,
      event_type: event.event_type,
      user_type: event.user_type,
      user_id: event.user_id || null,
      user_name: event.user_name || null,
      ip_address: ip,
      user_agent: navigator.userAgent,
      device_info: deviceInfo as any,
      details: (event.details || {}) as any,
      severity: event.severity || 'info',
    }]);
  } catch (err) {
    console.error('Audit log failed:', err);
  }
}

// Convenience helpers
export const auditLoginSuccess = (userType: AuditEvent['user_type'], userId: string, userName: string, method = 'password') =>
  logAuditEvent({ event_type: 'login_success', user_type: userType, user_id: userId, user_name: userName, details: { method }, severity: 'info' });

export const auditLoginFailed = (userType: AuditEvent['user_type'], attemptedId: string, reason = 'invalid_credentials') =>
  logAuditEvent({ event_type: 'login_failed', user_type: userType, user_id: attemptedId, details: { reason }, severity: 'warning' });

export const auditPasswordChange = (userType: AuditEvent['user_type'], userId: string, userName: string, changedBy?: string) =>
  logAuditEvent({ event_type: 'password_change', user_type: userType, user_id: userId, user_name: userName, details: { changed_by: changedBy || 'self' }, severity: 'info' });

export const auditPasswordReset = (userType: AuditEvent['user_type'], userId: string, userName: string, resetBy: string) =>
  logAuditEvent({ event_type: 'password_reset', user_type: userType, user_id: userId, user_name: userName, details: { reset_by: resetBy }, severity: 'warning' });

export const auditLogout = (userType: AuditEvent['user_type'], userId: string, userName: string) =>
  logAuditEvent({ event_type: 'logout', user_type: userType, user_id: userId, user_name: userName, severity: 'info' });

export const auditBiometricRegister = (userType: AuditEvent['user_type'], userId: string, userName: string) =>
  logAuditEvent({ event_type: 'biometric_register', user_type: userType, user_id: userId, user_name: userName, severity: 'info' });

export const auditBiometricLogin = (userType: AuditEvent['user_type'], userId: string, userName: string) =>
  logAuditEvent({ event_type: 'login_success', user_type: userType, user_id: userId, user_name: userName, details: { method: 'biometric' }, severity: 'info' });
