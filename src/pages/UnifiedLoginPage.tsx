import { useState, useEffect } from 'react';
import { Shield, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import SuperadminLoginForm from '@/components/SuperadminLoginForm';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';
import PasswordResetFlow from '@/components/PasswordResetFlow';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import { LoginFooter } from '@/components/LoginFooter';
import { fetchActiveSocietiesByName, getResidentByPhoneInSociety, type LoginSocietyRow } from '@/lib/societiesLogin';
import { permissionsFromAdminJoin, type AdminPanelPermissions } from '@/lib/adminPermissions';

interface Props {
  onGuardLogin: () => void;
  onResidentLogin: (resident: { id: string; name: string; phone: string; flatId: string; flatNumber: string }) => void;
  onAdminLogin: (admin: {
    id: string;
    name: string;
    adminId: string;
    societyId: string | null;
    permissions: AdminPanelPermissions;
  }) => void;
  onSuperadminLogin: (sa: { id: string; name: string; username: string }) => void;
}

function getDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const UnifiedLoginPage = ({ onGuardLogin, onResidentLogin, onAdminLogin, onSuperadminLogin }: Props) => {
  const { t } = useLanguage();
  const { login, setSocietyId, loadGuards } = useStore();
  const [societies, setSocieties] = useState<LoginSocietyRow[]>([]);
  const [selectedSocietyId, setSelectedSocietyId] = useState('');
  const [superadminMode, setSuperadminMode] = useState(false);
  const [loginMode, setLoginMode] = useState<'credentials' | 'otp'>('otp');
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showResetFlow, setShowResetFlow] = useState(false);
  const { isAvailable, authenticate, loading: bioLoading } = useBiometric();
  const [bioAvailable, setBioAvailable] = useState(false);

  useEffect(() => {
    isAvailable().then(setBioAvailable);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const list = await fetchActiveSocietiesByName();
      if (!cancelled) setSocieties(list);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const setSocietyFromFlat = async (flatId: string) => {
    const { data: flat } = await supabase.from('flats').select('society_id').eq('id', flatId).single();
    if (flat?.society_id) setSocietyId(flat.society_id);
  };

  const checkGeofence = (): Promise<boolean> => {
    return new Promise(async (resolve) => {
      const { data: geoData } = await supabase.from('geofence_settings').select('*').order('created_at', { ascending: false }).limit(1);
      if (!geoData || geoData.length === 0) {
        resolve(true);
        return;
      }
      const geo = geoData[0];
      if (!navigator.geolocation) {
        resolve(true);
        return;
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const dist = getDistanceMeters(pos.coords.latitude, pos.coords.longitude, geo.latitude, geo.longitude);
          resolve(dist <= geo.radius_meters);
        },
        () => resolve(true),
        { enableHighAccuracy: true, timeout: 10000 }
      );
    });
  };

  const handleOtpVerified = async (phone: string) => {
    if (!selectedSocietyId) {
      setError(t('login.pickSocietyFirst'));
      return;
    }

    const resident = await getResidentByPhoneInSociety(phone, selectedSocietyId);
    if (resident) {
      auditLoginSuccess('resident', resident.id, resident.name);
      registerOneSignalUser({
        userType: 'resident',
        userId: resident.id,
        userName: resident.name,
        flatNumber: resident.flat_number,
        societyId: selectedSocietyId,
      });
      promptPushPermission();
      setSocietyId(selectedSocietyId);
      onResidentLogin({
        id: resident.id,
        name: resident.name,
        phone: resident.phone,
        flatId: resident.flat_id,
        flatNumber: resident.flat_number,
      });
      return;
    }

    const { data: guard } = await supabase
      .from('guards')
      .select('*')
      .eq('phone', phone)
      .eq('auth_mode', 'otp')
      .eq('society_id', selectedSocietyId)
      .maybeSingle();
    if (guard) {
      const withinFence = await checkGeofence();
      if (!withinFence) {
        setError(t('admin.geofenceBlocked'));
        return;
      }
      setSocietyId(selectedSocietyId);
      await loadGuards();
      const success = await login(guard.guard_id, guard.password);
      if (success) {
        auditLoginSuccess('guard', guard.guard_id, guard.name);
        registerOneSignalUser({
          userType: 'guard',
          userId: guard.guard_id,
          userName: guard.name,
          societyId: selectedSocietyId,
        });
        promptPushPermission();
        onGuardLogin();
      }
      return;
    }

    setError(t('login.invalidCredentials'));
  };

  const handleCredentialLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!selectedSocietyId) {
      setError(t('login.pickSocietyFirst'));
      return;
    }
    if (!identifier || !password) {
      setError(t('login.enterBoth'));
      return;
    }
    setLoading(true);

    const id = identifier.trim();

    const { data: admin } = await supabase
      .from('admins')
      .select('*, society_roles(permissions, slug, role_name)')
      .eq('admin_id', id.toUpperCase())
      .eq('password', password)
      .eq('society_id', selectedSocietyId)
      .maybeSingle();
    if (admin) {
      auditLoginSuccess('admin', admin.id, admin.name);
      setSocietyId(selectedSocietyId);
      setLoading(false);
      registerOneSignalUser({
        userType: 'admin',
        userId: admin.id,
        userName: admin.name,
        societyId: selectedSocietyId,
      });
      promptPushPermission();
      onAdminLogin({
        id: admin.id,
        name: admin.name,
        adminId: admin.admin_id,
        societyId: admin.society_id,
        permissions: permissionsFromAdminJoin(admin),
      });
      return;
    }

    const { data: guard } = await supabase
      .from('guards')
      .select('*')
      .eq('guard_id', id.toUpperCase())
      .eq('password', password)
      .eq('society_id', selectedSocietyId)
      .maybeSingle();
    if (guard) {
      const withinFence = await checkGeofence();
      if (!withinFence) {
        setError(t('admin.geofenceBlocked'));
        setLoading(false);
        return;
      }
      setSocietyId(selectedSocietyId);
      await loadGuards();
      const success = await login(guard.guard_id, guard.password);
      setLoading(false);
      if (success) {
        auditLoginSuccess('guard', guard.guard_id, guard.name);
        registerOneSignalUser({
          userType: 'guard',
          userId: guard.guard_id,
          userName: guard.name,
          societyId: selectedSocietyId,
        });
        promptPushPermission();
        onGuardLogin();
      } else {
        setError(t('login.invalidCredentials'));
      }
      return;
    }

    const { data: flats } = await supabase.from('flats').select('id').eq('society_id', selectedSocietyId);
    const flatIds = (flats ?? []).map((f) => f.id);
    let resident = null;
    if (flatIds.length > 0) {
      const { data: r } = await supabase
        .from('resident_users')
        .select('*')
        .eq('phone', id)
        .eq('password', password)
        .in('flat_id', flatIds)
        .maybeSingle();
      resident = r;
    }
    if (resident) {
      auditLoginSuccess('resident', resident.id, resident.name);
      registerOneSignalUser({
        userType: 'resident',
        userId: resident.id,
        userName: resident.name,
        flatNumber: resident.flat_number,
        societyId: selectedSocietyId,
      });
      promptPushPermission();
      setSocietyId(selectedSocietyId);
      setLoading(false);
      onResidentLogin({
        id: resident.id,
        name: resident.name,
        phone: resident.phone,
        flatId: resident.flat_id,
        flatNumber: resident.flat_number,
      });
      return;
    }

    auditLoginFailed('guard', id);
    setError(t('login.invalidCredentials'));
    setLoading(false);
  };

  const showBiometric = bioAvailable && !!selectedSocietyId && !superadminMode;

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
      <div className="absolute top-4 right-4 flex items-center gap-2">
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-3">
            <Shield className="w-8 h-8 text-primary" />
          </div>
          <h1 className="page-title text-xl text-center">{t('app.name')}</h1>
          <p className="text-muted-foreground text-xs mt-1 text-center">{t('app.subtitle')}</p>
          <p className="text-muted-foreground/80 text-[11px] mt-0.5 text-center">{t('app.tagline')}</p>
        </div>

        {superadminMode ? (
          <div className="mb-4">
            <button
              type="button"
              className="text-xs text-muted-foreground underline mb-3"
              onClick={() => {
                setSuperadminMode(false);
                setError('');
                setIdentifier('');
                setPassword('');
              }}
            >
              {t('login.backToSociety')}
            </button>
            <SuperadminLoginForm variant="embedded" onLogin={onSuperadminLogin} />
          </div>
        ) : (
          <>
            <div className="mb-4 flex flex-col gap-2">
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">{t('login.selectSociety')}</label>
              <select
                className="input-field w-full"
                value={selectedSocietyId}
                onChange={(e) => {
                  setSelectedSocietyId(e.target.value);
                  setError('');
                }}
              >
                <option value="">{t('login.societyPlaceholder')}</option>
                {societies.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
              <button type="button" className="text-[11px] text-muted-foreground text-center underline" onClick={() => setSuperadminMode(true)}>
                {t('login.superadminPlatform')}
              </button>
            </div>

            {!selectedSocietyId && <p className="text-muted-foreground text-xs text-center mb-3">{t('login.pickSocietyFirst')}</p>}

            {selectedSocietyId && (
              <>
                <div className="flex gap-1 p-1 bg-muted rounded-xl mb-4">
                  <button
                    onClick={() => {
                      setLoginMode('otp');
                      setError('');
                    }}
                    className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
                      loginMode === 'otp' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
                    }`}
                  >
                    <Phone className="w-3.5 h-3.5" /> OTP Login
                  </button>
                  <button
                    onClick={() => {
                      setLoginMode('credentials');
                      setError('');
                    }}
                    className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
                      loginMode === 'credentials' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
                    }`}
                  >
                    <Shield className="w-3.5 h-3.5" /> ID & Password
                  </button>
                </div>

                {loginMode === 'otp' ? (
                  <OTPLoginFlow
                    embedded
                    onVerified={handleOtpVerified}
                    title="Login with OTP"
                    subtitle="Residents & OTP-enabled guards"
                  />
                ) : (
                  <>
                    {showBiometric && (
                      <button
                        onClick={async () => {
                          setError('');
                          const adminResult = await authenticate('admin');
                          if (adminResult) {
                            const { data: admin } = await supabase
                              .from('admins')
                              .select('*, society_roles(permissions, slug, role_name)')
                              .eq('id', adminResult.userId)
                              .maybeSingle();
                            if (admin && admin.society_id === selectedSocietyId) {
                              setSocietyId(selectedSocietyId);
                              registerOneSignalUser({
                                userType: 'admin',
                                userId: admin.id,
                                userName: admin.name,
                                societyId: selectedSocietyId,
                              });
                              promptPushPermission();
                              onAdminLogin({
                                id: admin.id,
                                name: admin.name,
                                adminId: admin.admin_id,
                                societyId: admin.society_id,
                                permissions: permissionsFromAdminJoin(admin),
                              });
                              return;
                            }
                          }

                          const guardResult = await authenticate('guard');
                          if (guardResult) {
                            const { data: guard } = await supabase.from('guards').select('*').eq('id', guardResult.userId).single();
                            if (!guard || guard.society_id !== selectedSocietyId) {
                              setError(t('login.invalidCredentials'));
                              return;
                            }
                            setSocietyId(selectedSocietyId);
                            await loadGuards();
                            const withinFence = await checkGeofence();
                            if (!withinFence) {
                              setError(t('admin.geofenceBlocked'));
                              return;
                            }
                            const success = await login(guard.guard_id, guard.password);
                            if (success) onGuardLogin();
                            return;
                          }

                          const residentResult = await authenticate('resident');
                          if (!residentResult) {
                            setError(t('biometric.notRegistered'));
                            return;
                          }
                          const { data: resident } = await supabase.from('resident_users').select('*').eq('id', residentResult.userId).single();
                          if (!resident) {
                            setError(t('login.invalidCredentials'));
                            return;
                          }
                          const { data: flat } = await supabase.from('flats').select('society_id').eq('id', resident.flat_id).single();
                          if (flat?.society_id !== selectedSocietyId) {
                            setError(t('login.invalidCredentials'));
                            return;
                          }
                          setSocietyId(selectedSocietyId);
                          onResidentLogin({
                            id: resident.id,
                            name: resident.name,
                            phone: resident.phone,
                            flatId: resident.flat_id,
                            flatNumber: resident.flat_number,
                          });
                        }}
                        disabled={bioLoading}
                        className="w-full mb-4 py-3 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-1 hover:bg-primary/10 transition-colors"
                      >
                        <Fingerprint className="w-7 h-7 text-primary" />
                        <span className="text-xs font-medium text-primary">{t('biometric.loginButton')}</span>
                      </button>
                    )}

                    <form onSubmit={handleCredentialLogin} className="flex flex-col gap-3">
                      <div>
                        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">
                          ID / Phone / Username
                        </label>
                        <input
                          className="input-field font-mono"
                          placeholder="Guard ID, Admin ID, Phone..."
                          value={identifier}
                          onChange={(e) => setIdentifier(e.target.value)}
                        />
                      </div>
                      <div>
                        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1 block">{t('login.password')}</label>
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
                      <p className="text-[10px] text-muted-foreground text-center">Guards, Admins & Residents (this society)</p>
                      {error && <p className="text-destructive text-sm text-center">{error}</p>}
                      <button type="submit" className="btn-primary mt-1" disabled={loading}>
                        {loading ? t('login.loggingIn') : 'Login'}
                      </button>
                      <button type="button" className="text-xs text-primary text-center mt-1 underline" onClick={() => setShowResetFlow(true)}>
                        Forgot Password?
                      </button>
                    </form>
                  </>
                )}

                {loginMode === 'otp' && error && <p className="text-destructive text-sm text-center mt-2">{error}</p>}
              </>
            )}
          </>
        )}
      </div>
      <LoginFooter />
      {showResetFlow && selectedSocietyId && (
        <div className="fixed inset-0 z-50 bg-background">
          <PasswordResetFlow userType="resident" societyId={selectedSocietyId} onBack={() => setShowResetFlow(false)} />
        </div>
      )}
    </div>
  );
};

export default UnifiedLoginPage;
