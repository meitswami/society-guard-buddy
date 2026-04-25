import { useState, useEffect } from 'react';
import { Shield, Eye, EyeOff, Fingerprint, Phone } from 'lucide-react';
import SuperadminLoginForm from '@/components/SuperadminLoginForm';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useBiometric } from '@/hooks/useBiometric';
import { auditLoginSuccess, auditLoginFailed, auditBiometricLogin } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';
import PasswordResetFlow from '@/components/PasswordResetFlow';
import OTPLoginFlow from '@/components/OTPLoginFlow';
import { LoginFooter } from '@/components/LoginFooter';
import { fetchActiveSocietiesByName, getResidentByPhoneInSociety, type LoginSocietyRow } from '@/lib/societiesLogin';
import { permissionsFromAdminJoin, type AdminPanelPermissions } from '@/lib/adminPermissions';
import { useShowSuperadminLogin } from '@/hooks/use-show-superadmin-login';
import { completeResidentOtpOnboarding, normalizeLoginPhone } from '@/lib/residentLoginOnboarding';

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

type LoginRole = '' | 'guard' | 'admin' | 'resident';

const UnifiedLoginPage = ({ onGuardLogin, onResidentLogin, onAdminLogin, onSuperadminLogin }: Props) => {
  const { t } = useLanguage();
  const { login, setSocietyId, loadGuards } = useStore();
  const showSuperadminEntry = useShowSuperadminLogin();
  const [societies, setSocieties] = useState<LoginSocietyRow[]>([]);
  const [selectedSocietyId, setSelectedSocietyId] = useState('');
  const [loginRole, setLoginRole] = useState<LoginRole>('');
  const [societyFlats, setSocietyFlats] = useState<{ id: string; flat_number: string }[]>([]);
  const [selectedFlatId, setSelectedFlatId] = useState('');
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

  useEffect(() => {
    if (!selectedSocietyId || loginRole !== 'resident') {
      setSocietyFlats([]);
      setSelectedFlatId('');
      return;
    }
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('flats')
        .select('id, flat_number')
        .eq('society_id', selectedSocietyId)
        .order('flat_number', { ascending: true });
      if (!cancelled) setSocietyFlats(data ?? []);
    })();
    return () => {
      cancelled = true;
    };
  }, [selectedSocietyId, loginRole]);

  const checkGeofence = (): Promise<boolean> => {
    return new Promise(async (resolve) => {
      if (!selectedSocietyId) {
        resolve(true);
        return;
      }
      const { data: geoData } = await supabase
        .from('geofence_settings')
        .select('*')
        .eq('society_id', selectedSocietyId)
        .order('created_at', { ascending: false })
        .limit(1);
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
    if (!loginRole) {
      setError(t('login.pickRoleFirst'));
      return;
    }
    if (loginRole === 'admin') {
      setError(t('login.adminUsePassword'));
      return;
    }

    const normalized = normalizeLoginPhone(phone);

    if (loginRole === 'guard') {
      const { data: guard } = await supabase
        .from('guards')
        .select('*')
        .eq('phone', normalized)
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
      return;
    }

    if (!selectedFlatId) {
      setError(t('login.pickFlatFirst'));
      return;
    }

    const { data: flatsInSoc } = await supabase.from('flats').select('id').eq('society_id', selectedSocietyId);
    const flatIds = (flatsInSoc ?? []).map((f) => f.id);
    if (flatIds.length > 0) {
      const { data: otherFlatUser } = await supabase
        .from('resident_users')
        .select('flat_id')
        .eq('phone', normalized)
        .in('flat_id', flatIds)
        .maybeSingle();
      if (otherFlatUser && otherFlatUser.flat_id !== selectedFlatId) {
        setError(t('login.onboard.phoneOtherFlat'));
        return;
      }
    }

    const resident = await getResidentByPhoneInSociety(normalized, selectedSocietyId);
    if (resident) {
      if (resident.flat_id !== selectedFlatId) {
        setError(t('login.onboard.phoneOtherFlat'));
        return;
      }
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

    const flatRow = societyFlats.find((f) => f.id === selectedFlatId);
    if (!flatRow) {
      setError(t('login.pickFlatFirst'));
      return;
    }

    const onboarded = await completeResidentOtpOnboarding(normalized, selectedFlatId, flatRow.flat_number, t);
    if (!onboarded) return;

    if (onboarded.openFamilyTab) {
      try {
        sessionStorage.setItem('sgb_open_family_tab', '1');
      } catch {
        /* ignore */
      }
    }

    auditLoginSuccess('resident', onboarded.id, onboarded.name);
    registerOneSignalUser({
      userType: 'resident',
      userId: onboarded.id,
      userName: onboarded.name,
      flatNumber: onboarded.flatNumber,
      societyId: selectedSocietyId,
    });
    promptPushPermission();
    setSocietyId(selectedSocietyId);
    onResidentLogin({
      id: onboarded.id,
      name: onboarded.name,
      phone: onboarded.phone,
      flatId: onboarded.flatId,
      flatNumber: onboarded.flatNumber,
    });
  };

  const handleCredentialLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!selectedSocietyId) {
      setError(t('login.pickSocietyFirst'));
      return;
    }
    if (!loginRole) {
      setError(t('login.pickRoleFirst'));
      return;
    }
    if (!identifier || !password) {
      setError(t('login.enterBoth'));
      return;
    }
    setLoading(true);

    const idRaw = identifier.trim();
    const id = loginRole === 'resident' ? normalizeLoginPhone(idRaw) : idRaw;

    if (loginRole === 'admin') {
      const { data: admin } = await supabase
        .from('admins')
        .select('*, society_roles(permissions, slug, role_name)')
        .eq('admin_id', idRaw.toUpperCase())
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
      auditLoginFailed('admin', idRaw);
      setError(t('login.invalidCredentials'));
      setLoading(false);
      return;
    }

    if (loginRole === 'guard') {
      const { data: guard } = await supabase
        .from('guards')
        .select('*')
        .eq('guard_id', idRaw.toUpperCase())
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
      auditLoginFailed('guard', idRaw);
      setError(t('login.invalidCredentials'));
      setLoading(false);
      return;
    }

    if (!selectedFlatId) {
      setError(t('login.pickFlatFirst'));
      setLoading(false);
      return;
    }

    let flatNumber = societyFlats.find((f) => f.id === selectedFlatId)?.flat_number ?? '';
    if (!flatNumber) {
      const { data: fr } = await supabase.from('flats').select('flat_number').eq('id', selectedFlatId).single();
      flatNumber = fr?.flat_number ?? '';
    }

    const { data: flatsInSoc } = await supabase.from('flats').select('id').eq('society_id', selectedSocietyId);
    const societyFlatIds = (flatsInSoc ?? []).map((f) => f.id);
    if (societyFlatIds.length > 0) {
      const { data: otherFlatUser } = await supabase
        .from('resident_users')
        .select('flat_id')
        .eq('phone', id)
        .in('flat_id', societyFlatIds)
        .maybeSingle();
      if (otherFlatUser && otherFlatUser.flat_id !== selectedFlatId) {
        setError(t('login.onboard.phoneOtherFlat'));
        setLoading(false);
        return;
      }
    }

    const { data: resident } = await supabase
      .from('resident_users')
      .select('*')
      .eq('phone', id)
      .eq('password', password)
      .eq('flat_id', selectedFlatId)
      .maybeSingle();

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

    const { data: phoneRowOnFlat } = await supabase
      .from('resident_users')
      .select('id, password')
      .eq('flat_id', selectedFlatId)
      .eq('phone', id)
      .maybeSingle();
    if (phoneRowOnFlat && phoneRowOnFlat.password !== password) {
      auditLoginFailed('guard', idRaw);
      setError(t('login.invalidCredentials'));
      setLoading(false);
      return;
    }

    const { data: flatPasswordRow } = await supabase
      .from('resident_users')
      .select('id')
      .eq('flat_id', selectedFlatId)
      .eq('password', password)
      .limit(1)
      .maybeSingle();

    if (!flatPasswordRow) {
      auditLoginFailed('guard', idRaw);
      setError(t('login.invalidCredentials'));
      setLoading(false);
      return;
    }

    const onboarded = await completeResidentOtpOnboarding(id, selectedFlatId, flatNumber, t);
    if (!onboarded) {
      setLoading(false);
      return;
    }

    if (onboarded.openFamilyTab) {
      try {
        sessionStorage.setItem('sgb_open_family_tab', '1');
      } catch {
        /* ignore */
      }
    }

    auditLoginSuccess('resident', onboarded.id, onboarded.name);
    registerOneSignalUser({
      userType: 'resident',
      userId: onboarded.id,
      userName: onboarded.name,
      flatNumber: onboarded.flatNumber,
      societyId: selectedSocietyId,
    });
    promptPushPermission();
    setSocietyId(selectedSocietyId);
    setLoading(false);
    onResidentLogin({
      id: onboarded.id,
      name: onboarded.name,
      phone: onboarded.phone,
      flatId: onboarded.flatId,
      flatNumber: onboarded.flatNumber,
    });
  };

  const handleUnifiedBiometricLogin = async () => {
    setError('');
    if (!selectedSocietyId) {
      setError(t('login.pickSocietyFirst'));
      return;
    }
    if (!loginRole) {
      setError(t('login.pickRoleFirst'));
      return;
    }
    if (loginRole === 'admin') {
      setError(t('login.adminUsePassword'));
      return;
    }
    if (loginRole === 'resident' && !selectedFlatId) {
      setError(t('login.pickFlatFirst'));
      return;
    }

    if (loginRole === 'guard') {
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
      setError(t('biometric.notRegistered'));
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
    if (resident.flat_id !== selectedFlatId) {
      setError(t('login.onboard.phoneOtherFlat'));
      return;
    }
    auditBiometricLogin('resident', resident.id, resident.name);
    setSocietyId(selectedSocietyId);
    registerOneSignalUser({
      userType: 'resident',
      userId: resident.id,
      userName: resident.name,
      flatNumber: resident.flat_number,
      societyId: selectedSocietyId,
    });
    promptPushPermission();
    onResidentLogin({
      id: resident.id,
      name: resident.name,
      phone: resident.phone,
      flatId: resident.flat_id,
      flatNumber: resident.flat_number,
    });
  };

  const showBiometric =
    bioAvailable &&
    !!selectedSocietyId &&
    !superadminMode &&
    !!loginRole &&
    (loginRole !== 'resident' || !!selectedFlatId);

  useEffect(() => {
    if (loginRole === 'admin') setLoginMode('credentials');
  }, [loginRole]);

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
                setLoginRole('');
                setSelectedFlatId('');
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
                  setLoginRole('');
                  setSelectedFlatId('');
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
              {showSuperadminEntry && (
                <button type="button" className="text-[11px] text-muted-foreground text-center underline" onClick={() => setSuperadminMode(true)}>
                  {t('login.superadminPlatform')}
                </button>
              )}
            </div>

            {!selectedSocietyId && <p className="text-muted-foreground text-xs text-center mb-3">{t('login.pickSocietyFirst')}</p>}

            {selectedSocietyId && (
              <>
                <div className="mb-3 flex flex-col gap-2">
                  <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">{t('login.roleLabel')}</label>
                  <select
                    className="input-field w-full"
                    value={loginRole}
                    onChange={(e) => {
                      setLoginRole(e.target.value as LoginRole);
                      setSelectedFlatId('');
                      setError('');
                    }}
                  >
                    <option value="">{t('login.rolePlaceholder')}</option>
                    <option value="guard">{t('login.roleGuard')}</option>
                    <option value="admin">{t('login.roleAdmin')}</option>
                    <option value="resident">{t('login.roleResident')}</option>
                  </select>
                </div>

                {!loginRole && <p className="text-muted-foreground text-xs text-center mb-3">{t('login.pickRoleFirst')}</p>}

                {loginRole === 'resident' && (
                  <div className="mb-3 flex flex-col gap-2">
                    <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">{t('login.flatLabel')}</label>
                    <select
                      className="input-field w-full"
                      value={selectedFlatId}
                      onChange={(e) => {
                        setSelectedFlatId(e.target.value);
                        setError('');
                      }}
                    >
                      <option value="">{t('login.flatPlaceholder')}</option>
                      {societyFlats.map((f) => (
                        <option key={f.id} value={f.id}>
                          {f.flat_number}
                        </option>
                      ))}
                    </select>
                    {!selectedFlatId && <p className="text-muted-foreground text-[11px]">{t('login.pickFlatFirst')}</p>}
                  </div>
                )}

                {loginRole === 'admin' && (
                  <p className="text-xs text-muted-foreground text-center mb-3 leading-relaxed">{t('login.adminUsePassword')}</p>
                )}

                {loginRole && (
                <div className="flex gap-1 p-1 bg-muted rounded-xl mb-4">
                  <button
                    type="button"
                    disabled={loginRole === 'admin'}
                    onClick={() => {
                      setLoginMode('otp');
                      setError('');
                    }}
                    className={`flex-1 py-2 px-3 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${
                      loginMode === 'otp' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground'
                    } ${loginRole === 'admin' ? 'opacity-40 pointer-events-none' : ''}`}
                  >
                    <Phone className="w-3.5 h-3.5" /> OTP Login
                  </button>
                  <button
                    type="button"
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
                )}

                {loginRole && loginMode === 'otp' && loginRole !== 'admin' && (
                  <>
                    {showBiometric && (
                      <button
                        type="button"
                        onClick={handleUnifiedBiometricLogin}
                        disabled={bioLoading}
                        className="w-full mb-4 py-3 rounded-xl border-2 border-dashed border-primary/30 bg-primary/5 flex flex-col items-center gap-1 hover:bg-primary/10 transition-colors"
                      >
                        <Fingerprint className="w-7 h-7 text-primary" />
                        <span className="text-xs font-medium text-primary">{t('biometric.loginButton')}</span>
                      </button>
                    )}
                    <OTPLoginFlow
                      embedded
                      onVerified={handleOtpVerified}
                      title="Login with OTP"
                      subtitle={loginRole === 'resident' ? t('resident.loginSubtitle') : t('login.guardLogin')}
                    />
                  </>
                )}

                {loginRole && (loginMode === 'credentials' || loginRole === 'admin') && (
                  <>
                    {showBiometric && loginRole !== 'admin' && (
                      <button
                        type="button"
                        onClick={handleUnifiedBiometricLogin}
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
                          {loginRole === 'resident'
                            ? t('common.phone')
                            : loginRole === 'admin'
                              ? t('admin.adminId')
                              : t('login.guardId')}
                        </label>
                        <input
                          className="input-field font-mono"
                          placeholder={
                            loginRole === 'resident'
                              ? t('resident.loginSubtitle')
                              : loginRole === 'admin'
                                ? t('admin.adminId')
                                : t('login.guardIdPlaceholder')
                          }
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
                      <p className="text-[10px] text-muted-foreground text-center">
                        {loginRole === 'resident' ? t('resident.enterBoth') : t('login.enterBoth')}
                      </p>
                      {loginRole === 'resident' && (
                        <p className="text-[10px] text-muted-foreground/90 text-center leading-snug">{t('login.passwordSameHouseholdFlow')}</p>
                      )}
                      {error && <p className="text-destructive text-sm text-center">{error}</p>}
                      <button type="submit" className="btn-primary mt-1" disabled={loading}>
                        {loading ? t('login.loggingIn') : t('resident.login')}
                      </button>
                      {loginRole === 'resident' && (
                        <button type="button" className="text-xs text-primary text-center mt-1 underline" onClick={() => setShowResetFlow(true)}>
                          Forgot Password?
                        </button>
                      )}
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
      {showResetFlow && selectedSocietyId && loginRole === 'resident' && (
        <div className="fixed inset-0 z-50 bg-background">
          <PasswordResetFlow userType="resident" societyId={selectedSocietyId} onBack={() => setShowResetFlow(false)} />
        </div>
      )}
    </div>
  );
};

export default UnifiedLoginPage;
