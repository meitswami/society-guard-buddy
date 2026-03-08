import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import { Shield, Users, Car, FileText, BarChart3, Settings, MapPin, LogOut, Home, UserPlus, Truck, ShieldAlert, BookUser, Zap, Lock, UserCheck, Fingerprint } from 'lucide-react';
import { confirmAction } from '@/lib/swal';
import DashboardPage from '@/pages/DashboardPage';
import VisitorEntryPage from '@/pages/VisitorEntryPage';
import DeliveryEntryPage from '@/pages/DeliveryEntryPage';
import VehiclePage from '@/pages/VehiclePage';
import LogsPage from '@/pages/LogsPage';
import QuickEntryPage from '@/pages/QuickEntryPage';
import DirectoryPage from '@/pages/DirectoryPage';
import BlacklistPage from '@/pages/BlacklistPage';
import ReportPage from '@/pages/ReportPage';
import SettingsPage from '@/pages/SettingsPage';
import GeofenceSetup from '@/components/GeofenceSetup';
import AdminGuardManager from '@/components/AdminGuardManager';
import AdminResidentManager from '@/components/AdminResidentManager';
import AdminPasswordChange from '@/components/AdminPasswordChange';
import BiometricSetup from '@/components/BiometricSetup';

interface Props {
  admin: { id: string; name: string; adminId: string };
  onLogout: () => void;
}

type AdminTab = 'overview' | 'guards' | 'residents' | 'geofence' | 'password' | 'biometric' | 'visitor' | 'delivery' | 'vehicle' | 'blacklist' | 'directory' | 'quick' | 'report' | 'logs' | 'settings';

const AdminDashboard = ({ admin, onLogout }: Props) => {
  const { t } = useLanguage();
  const { loadVisitors, loadResidentVehicles, loadBlacklist, loadFlats, loadMembers, loadGuards } = useStore();
  const [activeTab, setActiveTab] = useState<AdminTab>('overview');
  const [stats, setStats] = useState({ visitors: 0, guards: 0, flats: 0, vehicles: 0, blacklist: 0 });

  useEffect(() => {
    loadVisitors(); loadResidentVehicles(); loadBlacklist(); loadFlats(); loadMembers(); loadGuards();
    loadStats();
  }, []);

  const loadStats = async () => {
    const [v, g, f, rv, bl] = await Promise.all([
      supabase.from('visitors').select('id', { count: 'exact', head: true }),
      supabase.from('guards').select('id', { count: 'exact', head: true }),
      supabase.from('flats').select('id', { count: 'exact', head: true }),
      supabase.from('resident_vehicles').select('id', { count: 'exact', head: true }),
      supabase.from('blacklist').select('id', { count: 'exact', head: true }),
    ]);
    setStats({
      visitors: v.count || 0, guards: g.count || 0, flats: f.count || 0,
      vehicles: rv.count || 0, blacklist: bl.count || 0,
    });
  };

  const handleLogout = async () => {
    const confirmed = await confirmAction(t('swal.confirmLogout'), t('swal.confirmLogoutText'), t('swal.yes'), t('swal.no'));
    if (confirmed) onLogout();
  };

  const tabs: { id: AdminTab; label: string; icon: React.ElementType }[] = [
    { id: 'overview', label: t('admin.overview'), icon: Home },
    { id: 'guards', label: t('admin.manageGuards'), icon: Shield },
    { id: 'residents', label: t('admin.manageResidents'), icon: UserCheck },
    { id: 'geofence', label: t('admin.geofence'), icon: MapPin },
    { id: 'password', label: t('admin.changePassword'), icon: Lock },
    { id: 'biometric', label: t('biometric.title'), icon: Fingerprint },
    { id: 'report', label: t('nav.report'), icon: BarChart3 },
    { id: 'logs', label: t('nav.logs'), icon: FileText },
    { id: 'visitor', label: t('nav.visitor'), icon: UserPlus },
    { id: 'delivery', label: t('nav.delivery'), icon: Truck },
    { id: 'vehicle', label: t('nav.vehicles'), icon: Car },
    { id: 'blacklist', label: t('nav.blacklist'), icon: ShieldAlert },
    { id: 'directory', label: t('nav.directory'), icon: BookUser },
    { id: 'quick', label: t('nav.quick'), icon: Zap },
    { id: 'settings', label: t('nav.settings'), icon: Settings },
  ];

  const renderContent = () => {
    switch (activeTab) {
      case 'guards': return <AdminGuardManager />;
      case 'residents': return <AdminResidentManager />;
      case 'geofence': return <GeofenceSetup adminName={admin.name} />;
      case 'password': return <AdminPasswordChange adminId={admin.id} />;
      case 'biometric': return (
        <div className="page-container">
          <h2 className="font-semibold mb-4">{t('biometric.title')}</h2>
          <BiometricSetup userType="admin" userId={admin.id} userName={admin.name} />
        </div>
      );
      case 'report': return <ReportPage />;
      case 'logs': return <LogsPage />;
      case 'visitor': return <VisitorEntryPage onDone={() => setActiveTab('overview')} />;
      case 'delivery': return <DeliveryEntryPage onDone={() => setActiveTab('overview')} />;
      case 'vehicle': return <VehiclePage />;
      case 'blacklist': return <BlacklistPage />;
      case 'directory': return <DirectoryPage />;
      case 'quick': return <QuickEntryPage />;
      case 'settings': return <SettingsPage />;
      default: return (
        <div className="page-container">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-destructive/10 flex items-center justify-center">
                <Shield className="w-5 h-5 text-destructive" />
              </div>
              <div>
                <h1 className="page-title">{t('admin.panel')}</h1>
                <p className="text-xs text-muted-foreground">{admin.name} ({admin.adminId})</p>
              </div>
            </div>
            <button onClick={handleLogout} className="p-2 rounded-lg bg-destructive/10 text-destructive">
              <LogOut className="w-5 h-5" />
            </button>
          </div>
          <div className="grid grid-cols-2 gap-3 mb-6">
            {[
              { label: t('admin.totalVisitors'), value: stats.visitors, icon: Users, color: 'text-blue-500' },
              { label: t('admin.totalGuards'), value: stats.guards, icon: Shield, color: 'text-green-500' },
              { label: t('admin.totalFlats'), value: stats.flats, icon: Home, color: 'text-purple-500' },
              { label: t('admin.totalVehicles'), value: stats.vehicles, icon: Car, color: 'text-orange-500' },
            ].map(s => (
              <div key={s.label} className="card-section p-4">
                <s.icon className={`w-5 h-5 ${s.color} mb-2`} />
                <p className="text-2xl font-bold">{s.value}</p>
                <p className="text-xs text-muted-foreground">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      );
    }
  };

  return (
    <div className="min-h-screen bg-background">
      {renderContent()}
      <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
        <div className="max-w-lg mx-auto flex items-center overflow-x-auto gap-0 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-1 scrollbar-hide">
          {tabs.map(tab => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button key={tab.id} onClick={() => setActiveTab(tab.id)}
                className={`${isActive ? 'nav-item-active' : 'nav-item'} min-w-[3rem] flex-1`}>
                <Icon className="w-4 h-4" />
                <span className="text-[9px] font-medium leading-tight">{tab.label}</span>
              </button>
            );
          })}
        </div>
        <p className="text-center text-[8px] text-muted-foreground pb-1">{t('app.footer')}</p>
      </nav>
    </div>
  );
};

export default AdminDashboard;
