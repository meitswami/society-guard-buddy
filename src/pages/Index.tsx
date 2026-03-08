import { useState, useEffect, useCallback } from 'react';
import { useStore } from '@/store/useStore';
import type { TabType } from '@/types';
import LoginPage from '@/pages/LoginPage';
import DashboardPage from '@/pages/DashboardPage';
import VisitorEntryPage from '@/pages/VisitorEntryPage';
import DeliveryEntryPage from '@/pages/DeliveryEntryPage';
import VehiclePage from '@/pages/VehiclePage';
import LogsPage from '@/pages/LogsPage';
import QuickEntryPage from '@/pages/QuickEntryPage';
import DirectoryPage from '@/pages/DirectoryPage';
import BlacklistPage from '@/pages/BlacklistPage';
import ReportPage from '@/pages/ReportPage';
import BottomNav from '@/components/BottomNav';
import { LanguageProvider, useLanguage } from '@/i18n/LanguageContext';

const AppContent = () => {
  const { currentGuard, theme, loadGuards, loadVisitors, loadResidentVehicles, loadBlacklist } = useStore();
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [loaded, setLoaded] = useState(false);

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

  if (!currentGuard) return <LoginPage />;

  return (
    <div className="min-h-screen bg-background">
      {activeTab === 'dashboard' && <DashboardPage />}
      {activeTab === 'quick' && <QuickEntryPage />}
      {activeTab === 'visitor' && <VisitorEntryPage onDone={goHome} />}
      {activeTab === 'delivery' && <DeliveryEntryPage onDone={goHome} />}
      {activeTab === 'vehicle' && <VehiclePage />}
      {activeTab === 'blacklist' && <BlacklistPage />}
      {activeTab === 'directory' && <DirectoryPage />}
      {activeTab === 'report' && <ReportPage />}
      {activeTab === 'logs' && <LogsPage />}
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
};

const Index = () => (
  <LanguageProvider>
    <AppContent />
  </LanguageProvider>
);

export default Index;
