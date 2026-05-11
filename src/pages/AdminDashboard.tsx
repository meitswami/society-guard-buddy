import { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import { Shield, Users, Car, FileText, BarChart3, Settings, MapPin, LogOut, Home, UserPlus, Truck, ShieldAlert, BookUser, Zap, Lock, UserCheck, Fingerprint, ClipboardList, IndianRupee, Heart, Calendar, Vote, Bell, Split, ParkingSquare, AlertTriangle, Sparkles, ScrollText, Wrench } from 'lucide-react';
import { confirmAction } from '@/lib/swal';
import { toast } from 'sonner';
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
import AuditLogViewer from '@/components/AuditLogViewer';
import FinanceManager from '@/components/FinanceManager';
import DonationManager from '@/components/DonationManager';
import EventManager from '@/components/EventManager';
import PollManager from '@/components/PollManager';
import MeetingManager from '@/components/MeetingManager';
import ParkingManager from '@/components/ParkingManager';
import ExpenseSplitter from '@/components/ExpenseSplitter';
import NotificationCenter from '@/components/NotificationCenter';
import { useNotificationsRealtimeRevision } from '@/hooks/useNotificationsRealtimeRevision';
import { auditLogout } from '@/lib/auditLogger';
import { isAdminTabAllowed, type AdminPanelPermissions, type AdminTab } from '@/lib/adminPermissions';
import TourGuideFirstLogin from '@/components/TourGuideFirstLogin';
import TourGuideHub from '@/components/TourGuideHub';
import { ElectionResultsBanner } from '@/components/ElectionResultsBanner';

interface Props {
  admin: {
    id: string;
    name: string;
    adminId: string;
    societyId: string | null;
    permissions: AdminPanelPermissions;
  };
  onLogout: () => void;
}

const AdminDashboard = ({ admin, onLogout }: Props) => {
  const { t } = useLanguage();
  const { setSocietyId, loadVisitors, loadResidentVehicles, loadBlacklist, loadFlats, loadMembers, loadGuards } = useStore();
  const notificationFeedRevision = useNotificationsRealtimeRevision(true, `admin-${admin.id}`);
  const [activeTab, setActiveTab] = useState<AdminTab>('overview');
  const activeTabRef = useRef<AdminTab>('overview');
  const exitBackTsRef = useRef(0);
  const [stats, setStats] = useState({
    visitors: 0,
    visitorsGuest: 0,
    visitorsService: 0,
    guards: 0,
    flats: 0,
    members: 0,
    vehicles: 0,
    vehiclesCars: 0,
    vehiclesTwoWheelers: 0,
    blacklist: 0,
    meetingsHeld: 0,
    maintenanceCollected: 0,
    splitwiseExpenseTotal: 0,
  });
  const [usageVersion, setUsageVersion] = useState(0);
  const [kycPending, setKycPending] = useState<{ id: string; name: string; guard_id: string; kyc_alert_days: number; created_at: string }[]>([]);

  const loadKycPending = async () => {
    let q = supabase.from('guards').select('id, name, guard_id, kyc_alert_days, created_at').eq('police_verification', 'pending');
    if (admin.societyId) q = q.eq('society_id', admin.societyId);
    const { data } = await q;
    if (data) {
      const alerts = data.filter(g => {
        const daysElapsed = (Date.now() - new Date(g.created_at).getTime()) / (1000 * 60 * 60 * 24);
        return daysElapsed >= (g.kyc_alert_days || 7);
      });
      setKycPending(alerts as any);
    }
  };

  const loadStats = useCallback(async () => {
    const sid = admin.societyId;
    if (!sid) {
      setStats({
        visitors: 0,
        visitorsGuest: 0,
        visitorsService: 0,
        guards: 0,
        flats: 0,
        members: 0,
        vehicles: 0,
        vehiclesCars: 0,
        vehiclesTwoWheelers: 0,
        blacklist: 0,
        meetingsHeld: 0,
        maintenanceCollected: 0,
        splitwiseExpenseTotal: 0,
      });
      return;
    }

    const vQ = supabase.from('visitors').select('id', { count: 'exact', head: true }).eq('society_id', sid);
    const vGuestQ = supabase.from('visitors').select('id', { count: 'exact', head: true }).eq('society_id', sid).eq('category', 'visitor');
    const vServiceQ = supabase.from('visitors').select('id', { count: 'exact', head: true }).eq('society_id', sid).eq('category', 'service');
    const gQ = supabase.from('guards').select('id', { count: 'exact', head: true }).eq('society_id', sid);
    const fQ = supabase.from('flats').select('id', { count: 'exact', head: true }).eq('society_id', sid);
    const rvQ = supabase.from('resident_vehicles').select('id', { count: 'exact', head: true }).eq('society_id', sid);
    const rvCarQ = supabase.from('resident_vehicles').select('id', { count: 'exact', head: true }).eq('society_id', sid).eq('vehicle_type', 'car');
    const rv2wQ = supabase
      .from('resident_vehicles')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', sid)
      .in('vehicle_type', ['bike', 'cycle', 'activa']);
    const blQ = supabase.from('blacklist').select('id', { count: 'exact', head: true }).eq('society_id', sid);
    const mtQ = supabase.from('meetings').select('id', { count: 'exact', head: true }).eq('society_id', sid);

    const flatsForMembers = supabase.from('flats').select('id').eq('society_id', sid);

    const [
      v,
      vGuest,
      vService,
      g,
      f,
      rv,
      rvCar,
      rv2w,
      bl,
      mt,
      flatsData,
    ] = await Promise.all([vQ, vGuestQ, vServiceQ, gQ, fQ, rvQ, rvCarQ, rv2wQ, blQ, mtQ, flatsForMembers]);

    const flatIds = (flatsData.data ?? []).map((x: { id: string }) => x.id);
    let membersCount = 0;
    if (flatIds.length > 0) {
      const { count: mc } = await supabase.from('members').select('id', { count: 'exact', head: true }).in('flat_id', flatIds);
      membersCount = mc ?? 0;
    }

    let maintenanceCollected = 0;
    const { data: chargeRows } = await supabase.from('maintenance_charges').select('id').eq('society_id', sid);
    const chargeIds = (chargeRows ?? []).map((r: { id: string }) => r.id);
    if (chargeIds.length > 0) {
      const { data: pays } = await supabase
        .from('maintenance_payments')
        .select('amount')
        .in('charge_id', chargeIds)
        .eq('payment_status', 'verified');
      for (const p of pays ?? []) maintenanceCollected += Number((p as { amount: number }).amount ?? 0);
    }

    let splitwiseExpenseTotal = 0;
    const { data: groupRows } = await supabase.from('expense_groups').select('id').eq('society_id', sid);
    const groupIds = (groupRows ?? []).map((r: { id: string }) => r.id);
    if (groupIds.length > 0) {
      const { data: expenses } = await supabase
        .from('expenses')
        .select('total_amount')
        .in('group_id', groupIds)
        .eq('record_status', 'active');
      for (const e of expenses ?? []) splitwiseExpenseTotal += Number((e as { total_amount: number }).total_amount ?? 0);
    }

    setStats({
      visitors: v.count ?? 0,
      visitorsGuest: vGuest.count ?? 0,
      visitorsService: vService.count ?? 0,
      guards: g.count ?? 0,
      flats: f.count ?? 0,
      members: membersCount,
      vehicles: rv.count ?? 0,
      vehiclesCars: rvCar.count ?? 0,
      vehiclesTwoWheelers: rv2w.count ?? 0,
      blacklist: bl.count ?? 0,
      meetingsHeld: mt.count ?? 0,
      maintenanceCollected,
      splitwiseExpenseTotal,
    });
  }, [admin.societyId]);

  useEffect(() => {
    setSocietyId(admin.societyId);
    loadVisitors(); loadResidentVehicles(); loadBlacklist(); loadFlats(); loadMembers(); loadGuards();
    void loadStats();
    loadKycPending();
  }, [admin.societyId, loadStats]);

  const tabUsageKey = admin.societyId ? `sgb_admin_tab_use_${admin.societyId}` : null;

  const tabUsageMap = useMemo(() => {
    if (typeof window === 'undefined' || !tabUsageKey) return {} as Record<string, number>;
    try {
      return JSON.parse(localStorage.getItem(tabUsageKey) || '{}') as Record<string, number>;
    } catch {
      return {};
    }
  }, [tabUsageKey, usageVersion]);

  const recordTabUse = useCallback(
    (tab: AdminTab) => {
      if (!tabUsageKey || tab === 'overview') return;
      try {
        const raw = localStorage.getItem(tabUsageKey);
        const u: Record<string, number> = raw ? JSON.parse(raw) : {};
        u[tab] = (u[tab] ?? 0) + 1;
        localStorage.setItem(tabUsageKey, JSON.stringify(u));
        setUsageVersion((x) => x + 1);
      } catch {
        /* ignore */
      }
    },
    [tabUsageKey],
  );

  const goToTab = useCallback(
    (tab: AdminTab) => {
      recordTabUse(tab);
      setActiveTab(tab);
      if (tab === 'overview' && admin.societyId) void loadStats();
    },
    [recordTabUse, admin.societyId, loadStats],
  );

  const handleLogout = async () => {
    const confirmed = await confirmAction(
      t('swal.confirmLogoutUser'),
      t('swal.confirmLogoutUserText'),
      t('swal.yes'),
      t('swal.no'),
    );
    if (confirmed) {
      auditLogout('admin', admin.id, admin.name);
      onLogout();
    }
  };

  const tabs: { id: AdminTab; label: string; icon: React.ElementType; group?: string }[] = [
    { id: 'overview', label: 'Home', icon: Home, group: 'main' },
    // Management
    { id: 'guards', label: 'Guards', icon: Shield, group: 'manage' },
    { id: 'residents', label: 'Residents', icon: UserCheck, group: 'manage' },
    { id: 'geofence', label: 'Geofence', icon: MapPin, group: 'manage' },
    // Finance
    { id: 'finance', label: 'Finance', icon: IndianRupee, group: 'finance' },
    { id: 'meetings', label: 'Meetings', icon: ScrollText, group: 'meetings' },
    { id: 'donations', label: 'Donations', icon: Heart, group: 'finance' },
    { id: 'splits', label: 'Splitwise', icon: Split, group: 'finance' },
    // Community
    { id: 'events', label: 'Events', icon: Calendar, group: 'community' },
    { id: 'polls', label: 'Polls', icon: Vote, group: 'community' },
    { id: 'notifications', label: 'Notify', icon: Bell, group: 'community' },
    { id: 'parking', label: 'Parking', icon: ParkingSquare, group: 'community' },
    // Operations
    { id: 'visitor', label: 'Visitor', icon: UserPlus, group: 'ops' },
    { id: 'delivery', label: 'Delivery', icon: Truck, group: 'ops' },
    { id: 'vehicle', label: 'Vehicles', icon: Car, group: 'ops' },
    { id: 'blacklist', label: 'Blacklist', icon: ShieldAlert, group: 'ops' },
    { id: 'directory', label: 'Directory', icon: BookUser, group: 'ops' },
    { id: 'quick', label: 'Quick', icon: Zap, group: 'ops' },
    // Reports & Settings
    { id: 'report', label: 'REPORTS', icon: BarChart3, group: 'system' },
    { id: 'logs', label: 'Logs', icon: FileText, group: 'system' },
    { id: 'audit', label: 'Audit', icon: ClipboardList, group: 'system' },
    { id: 'password', label: 'Password', icon: Lock, group: 'system' },
    { id: 'biometric', label: 'Biometric', icon: Fingerprint, group: 'system' },
    { id: 'settings', label: 'Settings', icon: Settings, group: 'system' },
    { id: 'tour', label: t('nav.tour'), icon: Sparkles, group: 'system' },
  ];

  const visibleTabs = tabs.filter((tab) => isAdminTabAllowed(tab.id, admin.permissions));

  const quickAccessTabs = useMemo(() => {
    const list = visibleTabs.filter((t) => t.id !== 'overview');
    return [...list].sort((a, b) => {
      const ua = tabUsageMap[a.id] ?? 0;
      const ub = tabUsageMap[b.id] ?? 0;
      if (ub !== ua) return ub - ua;
      return a.label.localeCompare(b.label, undefined, { sensitivity: 'base' });
    });
  }, [visibleTabs, tabUsageMap]);

  const bottomNavTabsAlphabetical = useMemo(
    () => [...visibleTabs].sort((a, b) => a.label.localeCompare(b.label, undefined, { sensitivity: 'base' })),
    [visibleTabs],
  );

  useEffect(() => {
    if (!isAdminTabAllowed(activeTab, admin.permissions)) setActiveTab('overview');
  }, [activeTab, admin.permissions]);

  useEffect(() => {
    activeTabRef.current = activeTab;
  }, [activeTab]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.history.pushState({ sgbAdminTabTrap: true }, '');
    const onPopState = () => {
      if (activeTabRef.current !== 'overview') {
        setActiveTab('overview');
        window.history.pushState({ sgbAdminTabTrap: true }, '');
        toast.message('Press back again to exit');
        return;
      }
      const now = Date.now();
      if (now - exitBackTsRef.current < 2000) {
        window.removeEventListener('popstate', onPopState);
        window.history.back();
        return;
      }
      exitBackTsRef.current = now;
      toast.message('Press back again to exit');
      window.history.pushState({ sgbAdminTabTrap: true }, '');
    };
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  const renderContent = () => {
    switch (activeTab) {
      case 'guards': return <AdminGuardManager />;
      case 'residents': return (
        <AdminResidentManager verifyAdminId={admin.id} verifyAdminName={admin.name} />
      );
      case 'geofence': return <GeofenceSetup adminName={admin.name} />;
      case 'password': return <AdminPasswordChange adminId={admin.id} />;
      case 'biometric': return (
        <div className="page-container">
          <h2 className="font-semibold mb-4">{t('biometric.title')}</h2>
          <BiometricSetup userType="admin" userId={admin.id} userName={admin.name} />
        </div>
      );
      case 'audit': return <AuditLogViewer />;
      case 'finance': return <FinanceManager adminName={admin.name} adminId={admin.id} />;
      case 'donations': return <DonationManager adminName={admin.name} />;
      case 'events': return <EventManager adminName={admin.name} />;
      case 'meetings': return <MeetingManager adminName={admin.name} />;
      case 'polls': return <PollManager adminName={admin.name} />;
      case 'parking': return <ParkingManager />;
      case 'splits': return <ExpenseSplitter adminName={admin.name} />;
      case 'notifications': return (
        <NotificationCenter
          adminName={admin.name}
          adminId={admin.id}
          societyId={admin.societyId}
          feedRevision={notificationFeedRevision}
        />
      );
      case 'report': return <ReportPage />;
      case 'logs': return <LogsPage />;
      case 'visitor': return <VisitorEntryPage onDone={() => goToTab('overview')} />;
      case 'delivery': return <DeliveryEntryPage onDone={() => goToTab('overview')} />;
      case 'vehicle': return <VehiclePage />;
      case 'blacklist': return <BlacklistPage />;
      case 'directory': return <DirectoryPage />;
      case 'quick': return <QuickEntryPage />;
      case 'settings': return <SettingsPage />;
      case 'tour':
        return <TourGuideHub role="admin" adminPermissions={admin.permissions} t={t} />;
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
          <ElectionResultsBanner societyId={admin.societyId} />
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-4">
            <div className="card-section p-4">
              <ScrollText className="w-5 h-5 text-indigo-500 mb-2" />
              <p className="text-2xl font-bold">{stats.meetingsHeld}</p>
              <p className="text-xs text-muted-foreground">Meetings held</p>
            </div>
            <div className="card-section p-4">
              <IndianRupee className="w-5 h-5 text-emerald-600 mb-2" />
              <p className="text-xl font-bold tabular-nums">
                ₹{stats.maintenanceCollected.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
              </p>
              <p className="text-xs text-muted-foreground">Maintenance collected (verified)</p>
            </div>
            <div className="card-section p-4">
              <Split className="w-5 h-5 text-teal-600 mb-2" />
              <p className="text-xl font-bold tabular-nums">
                ₹{stats.splitwiseExpenseTotal.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
              </p>
              <p className="text-xs text-muted-foreground">Splitwise expenses (active)</p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3 mb-6">
            <div className="card-section p-4">
              <Users className="w-5 h-5 text-blue-500 mb-2" />
              <p className="text-2xl font-bold">{stats.visitors}</p>
              <p className="text-xs text-muted-foreground">{t('admin.totalVisitors')}</p>
              <div className="mt-2 pt-2 border-t border-border space-y-0.5 text-[10px] text-muted-foreground">
                <p className="flex justify-between gap-2">
                  <span>Guest visitors</span>
                  <span className="font-medium text-foreground tabular-nums">{stats.visitorsGuest}</span>
                </p>
                <p className="flex justify-between gap-2">
                  <span className="flex items-center gap-1">
                    <Wrench className="w-3 h-3 shrink-0" /> Serviceman
                  </span>
                  <span className="font-medium text-foreground tabular-nums">{stats.visitorsService}</span>
                </p>
              </div>
            </div>
            <div className="card-section p-4">
              <Car className="w-5 h-5 text-orange-500 mb-2" />
              <p className="text-2xl font-bold">{stats.vehicles}</p>
              <p className="text-xs text-muted-foreground">{t('admin.totalVehicles')}</p>
              <div className="mt-2 pt-2 border-t border-border space-y-0.5 text-[10px] text-muted-foreground">
                <p className="flex justify-between gap-2">
                  <span>Cars</span>
                  <span className="font-medium text-foreground tabular-nums">{stats.vehiclesCars}</span>
                </p>
                <p className="flex justify-between gap-2">
                  <span>Two-wheelers</span>
                  <span className="font-medium text-foreground tabular-nums">{stats.vehiclesTwoWheelers}</span>
                </p>
              </div>
            </div>
            <div className="card-section p-4">
              <Home className="w-5 h-5 text-purple-500 mb-2" />
              <p className="text-2xl font-bold">{stats.flats}</p>
              <p className="text-xs text-muted-foreground">{t('admin.totalFlats')}</p>
              <p className="mt-2 pt-2 border-t border-border text-[10px] text-muted-foreground">
                Members registered:{' '}
                <span className="font-medium text-foreground tabular-nums">{stats.members}</span>
              </p>
            </div>
            <div className="card-section p-4">
              <Shield className="w-5 h-5 text-green-500 mb-2" />
              <p className="text-2xl font-bold">{stats.guards}</p>
              <p className="text-xs text-muted-foreground">{t('admin.totalGuards')}</p>
              <p className="mt-2 pt-2 border-t border-border text-[10px] text-muted-foreground">
                Blacklist:{' '}
                <span className="font-medium text-foreground tabular-nums">{stats.blacklist}</span>
              </p>
            </div>
          </div>

          {/* KYC Pending Alerts */}
          {kycPending.length > 0 && (
            <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3 mb-4">
              <div className="flex items-center gap-2 mb-2">
                <AlertTriangle className="w-4 h-4 text-amber-600" />
                <span className="text-sm font-semibold text-amber-700">Guard KYC Pending ({kycPending.length})</span>
              </div>
              {kycPending.map(g => (
                <button key={g.id} onClick={() => goToTab('guards')}
                  className="text-xs text-amber-600 ml-6 block hover:underline">
                  • {g.name} ({g.guard_id}) - Police verification overdue
                </button>
              ))}
            </div>
          )}

          {/* Quick access — all modules, most-used first */}
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1">Quick access</p>
          <p className="text-[10px] text-muted-foreground mb-3">Tiles ordered by how often you open each screen (this device).</p>
          <div className="grid grid-cols-4 gap-2 mb-4">
            {quickAccessTabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => goToTab(tab.id)}
                  className="card-section p-3 flex flex-col items-center gap-1 hover:bg-primary/5 text-center min-h-[72px]"
                >
                  <Icon className="w-5 h-5 text-primary shrink-0" />
                  <span className="text-[9px] text-muted-foreground leading-tight line-clamp-2">{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>
      );
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <TourGuideFirstLogin role="admin" userId={admin.id} adminPermissions={admin.permissions} t={t} />
      {renderContent()}
      <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
        <p className="text-center text-[9px] text-muted-foreground pt-1 border-t border-border/60 bg-card">
          A–Z navigation
        </p>
        <div className="max-w-lg mx-auto flex items-center overflow-x-auto gap-0 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-1 scrollbar-hide">
          {bottomNavTabsAlphabetical.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button key={tab.id} type="button" onClick={() => goToTab(tab.id)}
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
