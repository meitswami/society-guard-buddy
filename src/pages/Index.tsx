import { useState } from 'react';
import { useStore } from '@/store/useStore';
import type { TabType } from '@/types';
import LoginPage from '@/pages/LoginPage';
import DashboardPage from '@/pages/DashboardPage';
import VisitorEntryPage from '@/pages/VisitorEntryPage';
import DeliveryEntryPage from '@/pages/DeliveryEntryPage';
import VehiclePage from '@/pages/VehiclePage';
import LogsPage from '@/pages/LogsPage';
import BottomNav from '@/components/BottomNav';

const Index = () => {
  const currentGuard = useStore(s => s.currentGuard);
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');

  if (!currentGuard) return <LoginPage />;

  return (
    <div className="min-h-screen bg-background">
      {activeTab === 'dashboard' && <DashboardPage />}
      {activeTab === 'visitor' && <VisitorEntryPage />}
      {activeTab === 'delivery' && <DeliveryEntryPage />}
      {activeTab === 'vehicle' && <VehiclePage />}
      {activeTab === 'logs' && <LogsPage />}
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
};

export default Index;
