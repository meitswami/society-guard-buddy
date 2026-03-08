import { useStore } from '@/store/useStore';
import { Users, Car, Truck, LogIn, ShieldAlert, LogOut, Clock } from 'lucide-react';
import { useMemo } from 'react';
import { format } from 'date-fns';

const DashboardPage = () => {
  const { visitors, currentGuard, logout } = useStore();

  const today = format(new Date(), 'yyyy-MM-dd');

  const stats = useMemo(() => {
    const todayVisitors = visitors.filter(v => v.entryTime.startsWith(today));
    return {
      totalVisitors: todayVisitors.filter(v => v.category === 'visitor').length,
      totalVehicles: todayVisitors.filter(v => v.vehicleNumber).length,
      totalDeliveries: todayVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
      currentlyInside: todayVisitors.filter(v => !v.exitTime).length,
    };
  }, [visitors, today]);

  const recentEntries = visitors.filter(v => v.entryTime.startsWith(today)).slice(0, 5);

  // Repeat visitor alerts
  const alerts = useMemo(() => {
    const todayVisitors = visitors.filter(v => v.entryTime.startsWith(today));
    const phoneCounts: Record<string, number> = {};
    todayVisitors.forEach(v => {
      phoneCounts[v.phone] = (phoneCounts[v.phone] || 0) + 1;
    });
    return Object.entries(phoneCounts)
      .filter(([, count]) => count >= 3)
      .map(([phone, count]) => {
        const visitor = todayVisitors.find(v => v.phone === phone);
        return { phone, count, name: visitor?.name || 'Unknown' };
      });
  }, [visitors, today]);

  return (
    <div className="page-container">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="text-xs text-muted-foreground mt-0.5">
            <Clock className="w-3 h-3 inline mr-1" />
            {format(new Date(), 'dd MMM yyyy, hh:mm a')}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <div className="text-right">
            <p className="text-xs text-primary font-mono">{currentGuard?.id}</p>
            <p className="text-xs text-muted-foreground">{currentGuard?.name}</p>
          </div>
          <button onClick={logout} className="p-2 rounded-lg bg-secondary text-muted-foreground">
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-2 text-muted-foreground">
            <Users className="w-4 h-4" />
            <span className="text-xs">Visitors</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalVisitors}</span>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-2 text-muted-foreground">
            <Car className="w-4 h-4" />
            <span className="text-xs">Vehicles</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalVehicles}</span>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-2 text-muted-foreground">
            <Truck className="w-4 h-4" />
            <span className="text-xs">Deliveries</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalDeliveries}</span>
        </div>
        <div className="stat-card border-primary/30">
          <div className="flex items-center gap-2 text-primary">
            <LogIn className="w-4 h-4" />
            <span className="text-xs">Inside Now</span>
          </div>
          <span className="text-2xl font-bold font-mono text-primary">{stats.currentlyInside}</span>
        </div>
      </div>

      {/* Alerts */}
      {alerts.length > 0 && (
        <div className="mb-6">
          <h2 className="text-sm font-semibold mb-2 flex items-center gap-1.5">
            <ShieldAlert className="w-4 h-4 text-destructive" />
            Alerts
          </h2>
          {alerts.map(a => (
            <div key={a.phone} className="card-section border-destructive/30 mb-2 flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-destructive/20 flex items-center justify-center">
                <ShieldAlert className="w-4 h-4 text-destructive" />
              </div>
              <div>
                <p className="text-sm font-medium">{a.name}</p>
                <p className="text-xs text-muted-foreground">
                  {a.phone} — entered <span className="text-destructive font-semibold">{a.count}x</span> today
                </p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Recent Entries */}
      <div>
        <h2 className="text-sm font-semibold mb-3">Recent Entries</h2>
        {recentEntries.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">No entries today</p>
        ) : (
          <div className="flex flex-col gap-2">
            {recentEntries.map(v => (
              <div key={v.id} className="card-section flex items-center gap-3">
                <div className={`w-2 h-2 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success animate-pulse'}`} />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{v.name}</p>
                  <p className="text-xs text-muted-foreground">
                    Flat {v.flatNumber} · {v.category} · {format(new Date(v.entryTime), 'hh:mm a')}
                  </p>
                </div>
                {!v.exitTime && (
                  <span className="status-inside text-[10px]">Inside</span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default DashboardPage;
