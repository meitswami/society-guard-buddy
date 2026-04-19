import { useState, useEffect, useCallback } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { readPersistedSession, writePersistedSession, clearPersistedSession } from '@/lib/appSession';
import type { TabType } from '@/types';
import LoginPage from '@/pages/LoginPage';
import ResidentLoginPage from '@/pages/ResidentLoginPage';
import ResidentDashboard from '@/pages/ResidentDashboard';
import AdminLoginPage from '@/pages/AdminLoginPage';
import AdminDashboard from '@/pages/AdminDashboard';
import SuperadminLoginPage from '@/pages/SuperadminLoginPage';
import SuperadminDashboard from '@/pages/SuperadminDashboard';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import DashboardPage from '@/pages/DashboardPage';
import UnifiedLoginPage from '@/pages/UnifiedLoginPage';
import SocietyLoginGate from '@/components/SocietyLoginGate';
import { useIsMobile } from '@/hooks/use-mobile';
import { useShowSuperadminLogin } from '@/hooks/use-show-superadmin-login';
import VisitorEntryPage from '@/pages/VisitorEntryPage';
import DeliveryEntryPage from '@/pages/DeliveryEntryPage';
import VehiclePage from '@/pages/VehiclePage';
import LogsPage from '@/pages/LogsPage';
import QuickEntryPage from '@/pages/QuickEntryPage';
import DirectoryPage from '@/pages/DirectoryPage';
import BlacklistPage from '@/pages/BlacklistPage';
import SettingsPage from '@/pages/SettingsPage';
import BottomNav from '@/components/BottomNav';
import TourGuideFirstLogin from '@/components/TourGuideFirstLogin';
import TourGuideHub from '@/components/TourGuideHub';
import { LoginFooter } from '@/components/LoginFooter';
import { LanguageProvider, useLanguage } from '@/i18n/LanguageContext';
import { useGuardGeofenceMonitor } from '@/hooks/useGuardGeofenceMonitor';

type UserMode = 'choosing' | 'guard' | 'resident' | 'admin' | 'superadmin';

const AppContent = () => {
  const { currentGuard, theme, setSocietyId, loadGuards, loadVisitors, loadResidentVehicles, loadBlacklist, loadFlats, loadMembers, hydrateGuardSession } = useStore();
  const { t } = useLanguage();
  useGuardGeofenceMonitor(currentGuard);
  const isMobile = useIsMobile();
  const showSuperadminEntry = useShowSuperadminLogin();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [loaded, setLoaded] = useState(false);
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
    const init = async () => {
      await loadGuards();
      setLoaded(true);
    };
    init();
  }, []);

  useEffect(() => {
    if (!loaded) return;
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
        const { data } = await supabase.from('admins').select('id').eq('id', s.admin.id).maybeSingle();
        if (!cancelled && data) {
          setSocietyId(s.admin.societyId ?? s.societyId);
          setAdminUser(s.admin);
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
  }, [loaded, hydrateGuardSession, setSocietyId]);

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

  if (!loaded || !sessionChecked) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm animate-pulse">{t('app.loading')}</p>
      </div>
    );
  }

  // Superadmin logged in
  if (superadminUser) {
    return (
      <SuperadminDashboard
        superadmin={superadminUser}
        onLogout={() => {
          clearPersistedSession();
          setSuperadminUser(null);
          setUserMode('choosing');
          setLoginSociety(null);
        }}
      />
    );
  }

  // Admin logged in
  if (adminUser) {
    return (
      <AdminDashboard
        admin={adminUser}
        onLogout={() => {
          clearPersistedSession();
          setAdminUser(null);
          setSocietyId(null);
          setUserMode('choosing');
        }}
      />
    );
  }

  // Resident logged in
  if (residentUser) {
    return (
      <ResidentDashboard
        resident={residentUser}
        onLogout={() => {
          clearPersistedSession();
          setResidentUser(null);
          setSocietyId(null);
          setUserMode('choosing');
        }}
      />
    );
  }

  // Show login chooser or specific login
  if (!currentGuard) {
    // Mobile: single unified login page
    if (isMobile) {
      return (
        <UnifiedLoginPage
          onGuardLogin={() => {}}
          onResidentLogin={(resident) => {
            const sid = useStore.getState().societyId;
            if (sid) writePersistedSession({ v: 1, role: 'resident', societyId: sid, resident });
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
        <SuperadminLoginPage
          onLogin={(sa) => {
            writePersistedSession({ v: 1, role: 'superadmin', superadmin: sa });
            setSuperadminUser(sa);
          }}
          onBack={() => setUserMode('choosing')}
        />
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
        </div>
      );
    }

    if (userMode === 'admin') {
      return (
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
      );
    }

    if (userMode === 'resident') {
      return (
        <ResidentLoginPage
          societyId={loginSociety.id}
          onLogin={(resident) => {
            writePersistedSession({ v: 1, role: 'resident', societyId: loginSociety.id, resident });
            setResidentUser(resident);
          }}
          onSwitchToGuard={() => setUserMode('guard')}
        />
      );
    }

    return (
      <LoginPage
        societyId={loginSociety.id}
        onSwitchToResident={() => setUserMode('resident')}
      />
    );
  }

  // Guard tabs (tour last — full in-app guide)
  const guardTabs: TabType[] = ['dashboard', 'quick', 'visitor', 'delivery', 'vehicle', 'blacklist', 'directory', 'settings', 'tour'];

  return (
    <div className="min-h-screen bg-background">
      {currentGuard && <TourGuideFirstLogin role="guard" userId={currentGuard.id} t={t} />}
      {activeTab === 'dashboard' && <DashboardPage />}
      {activeTab === 'quick' && <QuickEntryPage />}
      {activeTab === 'visitor' && <VisitorEntryPage onDone={goHome} />}
      {activeTab === 'delivery' && <DeliveryEntryPage onDone={goHome} />}
      {activeTab === 'vehicle' && <VehiclePage />}
      {activeTab === 'blacklist' && <BlacklistPage />}
      {activeTab === 'directory' && <DirectoryPage />}
      {activeTab === 'settings' && <SettingsPage />}
      {activeTab === 'tour' && currentGuard && <TourGuideHub role="guard" t={t} />}
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} guardTabs={guardTabs} />
    </div>
  );
};

const Index = () => (
  <LanguageProvider>
    <AppContent />
  </LanguageProvider>
);

export default Index;
