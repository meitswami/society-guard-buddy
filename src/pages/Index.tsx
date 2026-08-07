import { useState, useEffect, useCallback, useRef, lazy, Suspense } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { readPersistedSession, writePersistedSession, clearPersistedSession } from '@/lib/appSession';
import type { TabType } from '@/types';
import { permissionsFromAdminJoin, type AdminPanelPermissions } from '@/lib/adminPermissions';
import UnifiedLoginPage from '@/pages/UnifiedLoginPage';
import SocietyLoginGate from '@/components/SocietyLoginGate';
import { useUnifiedLoginFlow } from '@/hooks/use-unified-login-flow';
import { useShowSuperadminLogin } from '@/hooks/use-show-superadmin-login';
import BottomNav from '@/components/BottomNav';
import { LoginFooter } from '@/components/LoginFooter';
import { useLanguage } from '@/i18n/LanguageContext';
import { useGuardGeofenceMonitor } from '@/hooks/useGuardGeofenceMonitor';
import { toast } from 'sonner';

const AdminDashboard = lazy(() => import('@/pages/AdminDashboard'));
const ResidentDashboard = lazy(() => import('@/pages/ResidentDashboard'));
const SuperadminDashboard = lazy(() => import('@/pages/SuperadminDashboard'));

const LoginPage = lazy(() => import('@/pages/LoginPage'));
const ResidentLoginPage = lazy(() => import('@/pages/ResidentLoginPage'));
const AdminLoginPage = lazy(() => import('@/pages/AdminLoginPage'));
const SuperadminLoginPage = lazy(() => import('@/pages/SuperadminLoginPage'));
const GuardLoginPreview = lazy(() => import('@/components/GuardLoginPreview'));

const DashboardPage = lazy(() => import('@/pages/DashboardPage'));
const VisitorEntryPage = lazy(() => import('@/pages/VisitorEntryPage'));
const DeliveryEntryPage = lazy(() => import('@/pages/DeliveryEntryPage'));
const VehiclePage = lazy(() => import('@/pages/VehiclePage'));
const QuickEntryPage = lazy(() => import('@/pages/QuickEntryPage'));
const DirectoryPage = lazy(() => import('@/pages/DirectoryPage'));
const BlacklistPage = lazy(() => import('@/pages/BlacklistPage'));
const SettingsPage = lazy(() => import('@/pages/SettingsPage'));
const EmergencyAlertPanel = lazy(() => import('@/components/EmergencyAlertPanel'));
const GuardDutyPage = lazy(() => import('@/pages/GuardDutyPage'));
const TourGuideFirstLogin = lazy(() => import('@/components/TourGuideFirstLogin'));
const TourGuideHub = lazy(() => import('@/components/TourGuideHub'));

const RouteFallback = () => (
  <div className="min-h-screen bg-background flex items-center justify-center">
    <p className="text-muted-foreground text-sm animate-pulse">Loading…</p>
  </div>
);

type UserMode = 'choosing' | 'guard' | 'resident' | 'admin' | 'superadmin';

const AppContent = () => {
  const { currentGuard, theme, societyId, setSocietyId, loadVisitors, loadResidentVehicles, loadBlacklist, loadFlats, loadMembers, hydrateGuardSession } = useStore();
  const { t } = useLanguage();
  useGuardGeofenceMonitor(currentGuard);
  const useUnifiedLogin = useUnifiedLoginFlow();
  const [guardPreviewOpen, setGuardPreviewOpen] = useState(false);
  const showSuperadminEntry = useShowSuperadminLogin();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const guardTabRef = useRef<TabType>('dashboard');
  const guardExitBackTsRef = useRef(0);
  const [sessionChecked, setSessionChecked] = useState(false);
  const [userMode, setUserMode] = useState<UserMode>('choosing');
  const [residentUser, setResidentUser] = useState<{ id: string; name: string; phone: string; flatId: string; flatNumber: string } | null>(null);
  const [adminUser, setAdminUser] = useState<{
    id: string;
    name: string;
    adminId: string;
    societyId: string | null;
    permissions: AdminPanelPermissions;
  } | null>(null);
  const [superadminUser, setSuperadminUser] = useState<{ id: string; name: string; username: string } | null>(null);
  const [loginSociety, setLoginSociety] = useState<{ id: string; name: string } | null>(null);

  const goHome = useCallback(() => setActiveTab('dashboard'), []);

  useEffect(() => {
    guardTabRef.current = activeTab;
  }, [activeTab]);

  // Restore session immediately — do not wait on loadGuards before first paint.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const s = readPersistedSession();
      if (!s) {
        if (!cancelled) setSessionChecked(true);
        return;
      }
      if (s.role === 'superadmin') {
        const { data } = await supabase.from('super_admins').select('id').eq('id', s.superadmin.id).maybeSingle();
        if (!cancelled && data) setSuperadminUser(s.superadmin);
        else if (!cancelled) clearPersistedSession();
        if (!cancelled) setSessionChecked(true);
        return;
      }
      if (s.role === 'admin') {
        const { data } = await supabase
          .from('admins')
          .select('*, society_roles(permissions, slug, role_name)')
          .eq('id', s.admin.id)
          .maybeSingle();
        if (!cancelled && data) {
          const sid = (data.society_id ?? s.societyId) as string;
          setSocietyId(sid);
          const admin = {
            id: data.id,
            name: data.name,
            adminId: data.admin_id,
            societyId: data.society_id,
            permissions: permissionsFromAdminJoin(data),
          };
          setAdminUser(admin);
          writePersistedSession({ v: 1, role: 'admin', societyId: sid, admin });
        } else if (!cancelled) clearPersistedSession();
        if (!cancelled) setSessionChecked(true);
        return;
      }
      if (s.role === 'resident') {
        const { data } = await supabase.from('resident_users').select('id').eq('id', s.resident.id).maybeSingle();
        if (!cancelled && data) {
          setSocietyId(s.societyId);
          setResidentUser(s.resident);
        } else if (!cancelled) clearPersistedSession();
        if (!cancelled) setSessionChecked(true);
        return;
      }
      if (s.role === 'guard') {
        const ok = await hydrateGuardSession({
          societyId: s.societyId,
          shiftId: s.shiftId,
          guardId: s.guardId,
        });
        if (!cancelled && !ok) clearPersistedSession();
        if (!cancelled) setSessionChecked(true);
        return;
      }
      if (!cancelled) setSessionChecked(true);
    })();
    return () => {
      cancelled = true;
    };
  }, [hydrateGuardSession, setSocietyId]);

  useEffect(() => {
    if (currentGuard) {
      loadVisitors();
      loadResidentVehicles();
      loadBlacklist();
      loadFlats();
      loadMembers();
    }
  }, [currentGuard]);

  useEffect(() => {
    if (!currentGuard || typeof window === 'undefined') return;
    window.history.pushState({ sgbGuardTabTrap: true }, '');
    const onPopState = () => {
      if (guardTabRef.current !== 'dashboard') {
        setActiveTab('dashboard');
        window.history.pushState({ sgbGuardTabTrap: true }, '');
        toast.message('Press back again to exit');
        return;
      }
      const now = Date.now();
      if (now - guardExitBackTsRef.current < 2000) {
        window.removeEventListener('popstate', onPopState);
        window.history.back();
        return;
      }
      guardExitBackTsRef.current = now;
      toast.message('Press back again to exit');
      window.history.pushState({ sgbGuardTabTrap: true }, '');
    };
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, [currentGuard]);

  useEffect(() => {
    const resolved = theme === 'system'
      ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
      : theme;
    document.documentElement.setAttribute('data-theme', resolved);

    if (theme === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = (e: MediaQueryListEvent) => {
        document.documentElement.setAttribute('data-theme', e.matches ? 'dark' : 'light');
      };
      mq.addEventListener('change', handler);
      return () => mq.removeEventListener('change', handler);
    }
  }, [theme]);

  if (!sessionChecked) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm animate-pulse">{t('app.loading')}</p>
      </div>
    );
  }

  // Superadmin logged in
  if (superadminUser) {
    return (
      <Suspense fallback={<RouteFallback />}>
        <SuperadminDashboard
          superadmin={superadminUser}
          onLogout={() => {
            clearPersistedSession();
            setSuperadminUser(null);
            setUserMode('choosing');
            setLoginSociety(null);
          }}
        />
      </Suspense>
    );
  }

  // Admin logged in
  if (adminUser) {
    return (
      <Suspense fallback={<RouteFallback />}>
        <AdminDashboard
          admin={adminUser}
          onLogout={() => {
            clearPersistedSession();
            setAdminUser(null);
            setSocietyId(null);
            setUserMode('choosing');
          }}
        />
      </Suspense>
    );
  }

  // Resident logged in
  if (residentUser) {
    return (
      <Suspense fallback={<RouteFallback />}>
        <ResidentDashboard
          resident={residentUser}
          onLogout={() => {
            clearPersistedSession();
            setResidentUser(null);
            setSocietyId(null);
            setUserMode('choosing');
          }}
        />
      </Suspense>
    );
  }

  // Show login chooser or specific login
  if (!currentGuard) {
    // Phone & tablet: single unified login page
    if (useUnifiedLogin) {
      return (
        <UnifiedLoginPage
          onGuardLogin={() => {}}
          onResidentLogin={(resident) => {
            const sid = useStore.getState().societyId;
            if (sid) {
              setSocietyId(sid);
              writePersistedSession({ v: 1, role: 'resident', societyId: sid, resident });
            }
            setResidentUser(resident);
          }}
          onAdminLogin={(admin) => {
            const sid = admin.societyId ?? useStore.getState().societyId;
            setSocietyId(sid ?? admin.societyId);
            if (sid) writePersistedSession({ v: 1, role: 'admin', societyId: sid, admin });
            setAdminUser(admin);
          }}
          onSuperadminLogin={(sa) => {
            writePersistedSession({ v: 1, role: 'superadmin', superadmin: sa });
            setSuperadminUser(sa);
          }}
        />
      );
    }

    if (userMode === 'superadmin') {
      return (
        <Suspense fallback={<RouteFallback />}>
          <SuperadminLoginPage
            onLogin={(sa) => {
              writePersistedSession({ v: 1, role: 'superadmin', superadmin: sa });
              setSuperadminUser(sa);
            }}
            onBack={() => setUserMode('choosing')}
          />
        </Suspense>
      );
    }

    if (!loginSociety) {
      return (
        <SocietyLoginGate
          onContinue={(s) => setLoginSociety(s)}
          onSuperadmin={showSuperadminEntry ? () => setUserMode('superadmin') : undefined}
        />
      );
    }

    if (userMode === 'choosing') {
      return (
        <div className="relative flex min-h-screen flex-col items-center justify-center bg-background px-6 pb-36">
          <div className="flex w-full max-w-sm flex-col items-center gap-4">
            <div className="flex flex-col items-center mb-4">
              <h1 className="page-title text-2xl text-center">{t('app.name')}</h1>
              <p className="text-muted-foreground text-sm mt-1 text-center">{t('app.subtitle')}</p>
              <p className="text-muted-foreground/80 text-xs mt-1 text-center">{t('app.tagline')}</p>
              <p className="text-xs text-primary font-medium mt-3 text-center px-2">{loginSociety.name}</p>
              <button
                type="button"
                className="text-[11px] text-muted-foreground underline mt-1"
                onClick={() => setLoginSociety(null)}
              >
                {t('login.changeSociety')}
              </button>
            </div>
            <button onClick={() => setUserMode('guard')}
              className="btn-primary w-full py-4 text-base">
              🛡️ {t('login.guardLogin')}
            </button>
            <button
              type="button"
              onClick={() => setGuardPreviewOpen(true)}
              className="w-full py-3 text-sm rounded-xl border border-primary/30 text-primary font-medium hover:bg-primary/5 transition-colors"
            >
              {t('guard.preview.open')}
            </button>
            <button onClick={() => setUserMode('resident')}
              className="w-full py-4 text-base rounded-xl bg-secondary text-secondary-foreground font-semibold hover:opacity-90 transition-opacity">
              🏠 {t('resident.loginTitle')}
            </button>
            <button onClick={() => setUserMode('admin')}
              className="w-full py-3 text-sm rounded-xl border border-border text-muted-foreground font-medium hover:bg-muted transition-colors">
              ⚙️ {t('login.adminLogin')}
            </button>
            {showSuperadminEntry && (
            <button onClick={() => setUserMode('superadmin')}
              className="w-full py-2 text-xs rounded-xl text-muted-foreground/60 font-medium hover:text-muted-foreground transition-colors">
              👑 {t('login.superadminLogin')}
            </button>
            )}
          </div>
          <LoginFooter />
          {guardPreviewOpen && (
            <Suspense fallback={null}>
              <GuardLoginPreview variant="fullscreen" onClose={() => setGuardPreviewOpen(false)} />
            </Suspense>
          )}
        </div>
      );
    }

    if (userMode === 'admin') {
      return (
        <Suspense fallback={<RouteFallback />}>
          <AdminLoginPage
            societyId={loginSociety.id}
            onLogin={(admin) => {
              const sid = admin.societyId ?? loginSociety.id;
              setSocietyId(sid);
              writePersistedSession({ v: 1, role: 'admin', societyId: sid, admin });
              setAdminUser(admin);
            }}
            onBack={() => setUserMode('choosing')}
          />
        </Suspense>
      );
    }

    if (userMode === 'resident') {
      return (
        <Suspense fallback={<RouteFallback />}>
          <ResidentLoginPage
            societyId={loginSociety.id}
            onLogin={(resident) => {
              setSocietyId(loginSociety.id);
              writePersistedSession({ v: 1, role: 'resident', societyId: loginSociety.id, resident });
              setResidentUser(resident);
            }}
            onSwitchToGuard={() => setUserMode('guard')}
          />
        </Suspense>
      );
    }

    return (
      <Suspense fallback={<RouteFallback />}>
        <LoginPage
          societyId={loginSociety.id}
          onSwitchToResident={() => setUserMode('resident')}
        />
      </Suspense>
    );
  }

  // Guard tabs (tour last — full in-app guide)
  const guardTabs: TabType[] = ['dashboard', 'duty', 'quick', 'visitor', 'delivery', 'vehicle', 'blacklist', 'emergency', 'directory', 'settings', 'tour'];

  return (
    <div className="min-h-screen bg-background">
      <Suspense fallback={<RouteFallback />}>
        {currentGuard && <TourGuideFirstLogin role="guard" userId={currentGuard.id} t={t} />}
        {activeTab === 'dashboard' && <DashboardPage />}
        {activeTab === 'duty' && <GuardDutyPage />}
        {activeTab === 'quick' && <QuickEntryPage />}
        {activeTab === 'visitor' && <VisitorEntryPage onDone={goHome} />}
        {activeTab === 'delivery' && <DeliveryEntryPage onDone={goHome} />}
        {activeTab === 'vehicle' && <VehiclePage />}
        {activeTab === 'blacklist' && <BlacklistPage />}
        {activeTab === 'emergency' && societyId && currentGuard && (
          <EmergencyAlertPanel
            societyId={societyId}
            senderName={currentGuard.name}
            senderRole="guard"
          />
        )}
        {activeTab === 'directory' && <DirectoryPage />}
        {activeTab === 'settings' && <SettingsPage />}
        {activeTab === 'tour' && currentGuard && <TourGuideHub role="guard" t={t} />}
      </Suspense>
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} guardTabs={guardTabs} />
    </div>
  );
};

const Index = () => <AppContent />;

export default Index;
