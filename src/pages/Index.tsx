import { useState, useEffect } from 'react';
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

const Index = () => {
  const { currentGuard, theme, loadGuards, loadVisitors, loadResidentVehicles, loadBlacklist } = useStore();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [loaded, setLoaded] = useState(false);

  // Load all data on mount
  useEffect(() => {
    const init = async () => {
      await loadGuards();
      setLoaded(true);
    };
    init();
  }, []);

  // Load data when logged in
  useEffect(() => {
    if (currentGuard) {
      loadVisitors();
      loadResidentVehicles();
      loadBlacklist();
    }
  }, [currentGuard]);

  // Apply theme
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
        <p className="text-muted-foreground text-sm animate-pulse">Loading...</p>
      </div>
    );
  }

  if (!currentGuard) return <LoginPage />;

  return (
    <div className="min-h-screen bg-background">
      {activeTab === 'dashboard' && <DashboardPage />}
      {activeTab === 'quick' && <QuickEntryPage />}
      {activeTab === 'visitor' && <VisitorEntryPage />}
      {activeTab === 'delivery' && <DeliveryEntryPage />}
      {activeTab === 'vehicle' && <VehiclePage />}
      {activeTab === 'blacklist' && <BlacklistPage />}
      {activeTab === 'directory' && <DirectoryPage />}
      {activeTab === 'report' && <ReportPage />}
      {activeTab === 'logs' && <LogsPage />}
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
};

export default Index;
