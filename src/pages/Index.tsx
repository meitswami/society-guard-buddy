import { useState, useEffect, useCallback } from 'react';
import { useStore } from '@/store/useStore';
import type { TabType } from '@/types';
import LoginPage from '@/pages/LoginPage';
import ResidentLoginPage from '@/pages/ResidentLoginPage';
import ResidentDashboard from '@/pages/ResidentDashboard';
import AdminLoginPage from '@/pages/AdminLoginPage';
import AdminDashboard from '@/pages/AdminDashboard';
import SuperadminLoginPage from '@/pages/SuperadminLoginPage';
import SuperadminDashboard from '@/pages/SuperadminDashboard';
import DashboardPage from '@/pages/DashboardPage';
import VisitorEntryPage from '@/pages/VisitorEntryPage';
import DeliveryEntryPage from '@/pages/DeliveryEntryPage';
import VehiclePage from '@/pages/VehiclePage';
import LogsPage from '@/pages/LogsPage';
import QuickEntryPage from '@/pages/QuickEntryPage';
import DirectoryPage from '@/pages/DirectoryPage';
import BlacklistPage from '@/pages/BlacklistPage';
import SettingsPage from '@/pages/SettingsPage';
import BottomNav from '@/components/BottomNav';
import { LanguageProvider, useLanguage } from '@/i18n/LanguageContext';

type UserMode = 'choosing' | 'guard' | 'resident' | 'admin' | 'superadmin';

const AppContent = () => {
  const { currentGuard, theme, loadGuards, loadVisitors, loadResidentVehicles, loadBlacklist, loadFlats, loadMembers } = useStore();
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [loaded, setLoaded] = useState(false);
  const [userMode, setUserMode] = useState<UserMode>('choosing');
  const [residentUser, setResidentUser] = useState<{ id: string; name: string; phone: string; flatId: string; flatNumber: string } | null>(null);
  const [adminUser, setAdminUser] = useState<{ id: string; name: string; adminId: string } | null>(null);
  const [superadminUser, setSuperadminUser] = useState<{ id: string; name: string; username: string } | null>(null);

  const goHome = useCallback(() => setActiveTab('dashboard'), []);

  useEffect(() => {
    const init = async () => {
      await loadGuards();
      setLoaded(true);
    };
    init();
  }, []);

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

  if (!loaded) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm animate-pulse">{t('app.loading')}</p>
      </div>
    );
  }

  // Superadmin logged in
  if (superadminUser) {
    return <SuperadminDashboard superadmin={superadminUser} onLogout={() => { setSuperadminUser(null); setUserMode('choosing'); }} />;
  }

  // Admin logged in
  if (adminUser) {
    return <AdminDashboard admin={adminUser} onLogout={() => { setAdminUser(null); setUserMode('choosing'); }} />;
  }

  // Resident logged in
  if (residentUser) {
    return <ResidentDashboard resident={residentUser} onLogout={() => { setResidentUser(null); setUserMode('choosing'); }} />;
  }

  // Show login chooser or specific login
  if (!currentGuard) {
    if (userMode === 'choosing') {
      return (
        <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background">
          <div className="w-full max-w-sm flex flex-col items-center gap-4">
            <div className="flex flex-col items-center mb-4">
              <h1 className="page-title text-2xl">{t('app.name')}</h1>
              <p className="text-muted-foreground text-sm mt-1">{t('app.subtitle')}</p>
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
            <button onClick={() => setUserMode('superadmin')}
              className="w-full py-2 text-xs rounded-xl text-muted-foreground/60 font-medium hover:text-muted-foreground transition-colors">
              👑 {t('login.superadminLogin')}
            </button>
          </div>
          <p className="absolute bottom-4 left-0 right-0 text-center text-[10px] text-muted-foreground">
            {t('app.footer')}
          </p>
        </div>
      );
    }

    if (userMode === 'admin') {
      return <AdminLoginPage onLogin={setAdminUser} onBack={() => setUserMode('choosing')} />;
    }

    if (userMode === 'resident') {
      return <ResidentLoginPage onLogin={setResidentUser} onSwitchToGuard={() => setUserMode('guard')} />;
    }

    return <LoginPage onSwitchToResident={() => setUserMode('resident')} />;
  }

  // Guard tabs - no report or logs
  const guardTabs: TabType[] = ['dashboard', 'quick', 'visitor', 'delivery', 'vehicle', 'blacklist', 'directory', 'settings'];

  return (
    <div className="min-h-screen bg-background">
      {activeTab === 'dashboard' && <DashboardPage />}
      {activeTab === 'quick' && <QuickEntryPage />}
      {activeTab === 'visitor' && <VisitorEntryPage onDone={goHome} />}
      {activeTab === 'delivery' && <DeliveryEntryPage onDone={goHome} />}
      {activeTab === 'vehicle' && <VehiclePage />}
      {activeTab === 'blacklist' && <BlacklistPage />}
      {activeTab === 'directory' && <DirectoryPage />}
      {activeTab === 'settings' && <SettingsPage />}
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
