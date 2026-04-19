import { useStore } from '@/store/useStore';
import { Users, Car, Truck, LogIn, ShieldAlert, LogOut, Clock, ChevronLeft, ChevronRight, DoorOpen } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';
import { useEffect, useMemo, useState } from 'react';
import { format, subDays } from 'date-fns';
import { confirmAction, showSuccess } from '@/lib/swal';
import { supabase } from '@/integrations/supabase/client';
import BiometricSetup from '@/components/BiometricSetup';

type StatFilter = 'all' | 'visitor' | 'vehicle' | 'delivery' | 'inside';

const DashboardPage = () => {
  const { visitors, currentGuard, logout, markExit } = useStore();
  const { t } = useLanguage();
  const [dayOffset, setDayOffset] = useState(0); // 0 = today, 1 = yesterday
  const [activeFilter, setActiveFilter] = useState<StatFilter>('all');
  const [guardDbId, setGuardDbId] = useState<string | null>(null);

  const selectedDate = format(subDays(new Date(), dayOffset), 'yyyy-MM-dd');
  const isToday = dayOffset === 0;

  const dayVisitors = useMemo(() => visitors.filter(v => v.entryTime.startsWith(selectedDate)), [visitors, selectedDate]);

  useEffect(() => {
    let cancelled = false;
    if (!currentGuard?.id) {
      setGuardDbId(null);
      return;
    }

    (async () => {
      const { data } = await supabase
        .from('guards')
        .select('id')
        .eq('guard_id', currentGuard.id)
        .maybeSingle();
      if (!cancelled) setGuardDbId(data?.id ?? null);
    })();

    return () => {
      cancelled = true;
    };
  }, [currentGuard?.id]);

  const stats = useMemo(() => ({
    totalVisitors: dayVisitors.filter(v => v.category === 'visitor').length,
    totalVehicles: dayVisitors.filter(v => v.vehicleNumber).length,
    totalDeliveries: dayVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
    currentlyInside: dayVisitors.filter(v => !v.exitTime).length,
  }), [dayVisitors]);

  const filteredEntries = useMemo(() => {
    let entries = dayVisitors;
    switch (activeFilter) {
      case 'visitor': entries = entries.filter(v => v.category === 'visitor'); break;
      case 'vehicle': entries = entries.filter(v => v.vehicleNumber); break;
      case 'delivery': entries = entries.filter(v => v.category === 'delivery' || v.category === 'service'); break;
      case 'inside': entries = entries.filter(v => !v.exitTime); break;
    }
    return entries.slice(0, 10);
  }, [dayVisitors, activeFilter]);

  const alerts = useMemo(() => {
    const phoneCounts: Record<string, number> = {};
    dayVisitors.forEach(v => { phoneCounts[v.phone] = (phoneCounts[v.phone] || 0) + 1; });
    return Object.entries(phoneCounts)
      .filter(([, count]) => count >= 3)
      .map(([phone, count]) => {
        const visitor = dayVisitors.find(v => v.phone === phone);
        return { phone, count, name: visitor?.name || 'Unknown' };
      });
  }, [dayVisitors]);

  const handleLogout = async () => {
    const confirmed = await confirmAction(
      t('swal.confirmLogoutGuard'),
      t('swal.confirmLogoutGuardText'),
      t('swal.yes'),
      t('swal.no'),
    );
    if (confirmed) logout();
  };

  const toggleFilter = (filter: StatFilter) => {
    setActiveFilter(prev => prev === filter ? 'all' : filter);
  };

  const handleMarkExit = async (visitorId: string, visitorName: string) => {
    const confirmed = await confirmAction(
      '🚪 Mark Exit?',
      `Are you sure you want to mark "${visitorName}" as exited?`,
      'Yes, mark exit',
      'Cancel'
    );
    if (confirmed) {
      await markExit(visitorId);
      showSuccess('Exit Recorded', `${visitorName} has been marked as exited.`);
    }
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="page-title">{t('app.name')}</h1>
          <p className="text-[10px] text-muted-foreground/80 mt-0.5">{t('app.tagline')}</p>
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
          <LanguageToggle />
          <ThemeToggle />
          <button onClick={handleLogout} className="p-2 rounded-lg bg-secondary text-muted-foreground">
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Date toggle */}
      <div className="flex items-center justify-center gap-3 mb-4">
        <button onClick={() => setDayOffset(Math.min(dayOffset + 1, 7))} className="p-1.5 rounded-lg bg-secondary text-muted-foreground">
          <ChevronLeft className="w-4 h-4" />
        </button>
        <div className="flex gap-1.5">
          <button
            onClick={() => setDayOffset(0)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${isToday ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          >{t('dashboard.todayLabel')}</button>
          <button
            onClick={() => setDayOffset(1)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${dayOffset === 1 ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          >{t('dashboard.yesterday')}</button>
        </div>
        <button onClick={() => setDayOffset(Math.max(dayOffset - 1, 0))} className="p-1.5 rounded-lg bg-secondary text-muted-foreground">
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>
      {dayOffset > 1 && (
        <p className="text-center text-xs text-muted-foreground mb-3">{format(subDays(new Date(), dayOffset), 'dd MMM yyyy')}</p>
      )}

      {/* Stats Grid — clickable */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <button onClick={() => toggleFilter('visitor')} className={`stat-card text-left transition-all ${activeFilter === 'visitor' ? 'ring-2 ring-primary' : ''}`}>
          <div className="flex items-center gap-2 text-muted-foreground">
            <Users className="w-4 h-4" /><span className="text-xs">{t('dashboard.visitors')}</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalVisitors}</span>
        </button>
        <button onClick={() => toggleFilter('vehicle')} className={`stat-card text-left transition-all ${activeFilter === 'vehicle' ? 'ring-2 ring-primary' : ''}`}>
          <div className="flex items-center gap-2 text-muted-foreground">
            <Car className="w-4 h-4" /><span className="text-xs">{t('dashboard.vehicles')}</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalVehicles}</span>
        </button>
        <button onClick={() => toggleFilter('delivery')} className={`stat-card text-left transition-all ${activeFilter === 'delivery' ? 'ring-2 ring-primary' : ''}`}>
          <div className="flex items-center gap-2 text-muted-foreground">
            <Truck className="w-4 h-4" /><span className="text-xs">{t('dashboard.deliveries')}</span>
          </div>
          <span className="text-2xl font-bold font-mono text-foreground">{stats.totalDeliveries}</span>
        </button>
        <button onClick={() => toggleFilter('inside')} className={`stat-card text-left border-primary/30 transition-all ${activeFilter === 'inside' ? 'ring-2 ring-primary' : ''}`}>
          <div className="flex items-center gap-2 text-primary">
            <LogIn className="w-4 h-4" /><span className="text-xs">{t('dashboard.insideNow')}</span>
          </div>
          <span className="text-2xl font-bold font-mono text-primary">{stats.currentlyInside}</span>
        </button>
      </div>

      {/* Active filter label */}
      {activeFilter !== 'all' && (
        <div className="flex items-center justify-between mb-3">
          <p className="text-xs text-primary font-medium">
            {activeFilter === 'visitor' && t('dashboard.visitors')}
            {activeFilter === 'vehicle' && t('dashboard.vehicles')}
            {activeFilter === 'delivery' && t('dashboard.deliveries')}
            {activeFilter === 'inside' && t('dashboard.insideNow')}
            {' '}({filteredEntries.length})
          </p>
          <button onClick={() => setActiveFilter('all')} className="text-[10px] text-muted-foreground underline">{t('dashboard.all')}</button>
        </div>
      )}

      {/* Alerts */}
      {alerts.length > 0 && activeFilter === 'all' && (
        <div className="mb-6">
          <h2 className="text-sm font-semibold mb-2 flex items-center gap-1.5">
            <ShieldAlert className="w-4 h-4 text-destructive" /> {t('dashboard.alerts')}
          </h2>
          {alerts.map(a => (
            <div key={a.phone} className="card-section border-destructive/30 mb-2 flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-destructive/20 flex items-center justify-center">
                <ShieldAlert className="w-4 h-4 text-destructive" />
              </div>
              <div>
                <p className="text-sm font-medium">{a.name}</p>
                <p className="text-xs text-muted-foreground">
                  {a.phone} — {t('dashboard.enteredXToday')} <span className="text-destructive font-semibold">{a.count}x</span> {t('dashboard.today')}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Entries */}
      <div>
        {activeFilter === 'all' && <h2 className="text-sm font-semibold mb-3">{t('dashboard.recentEntries')}</h2>}
        {filteredEntries.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">{t('dashboard.noEntries')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {filteredEntries.map(v => (
              <div key={v.id}
                onClick={() => !v.exitTime && handleMarkExit(v.id, v.name)}
                className={`card-section flex items-center gap-3 ${!v.exitTime ? 'cursor-pointer hover:bg-primary/5 active:scale-[0.98] transition-all' : ''}`}>
                <div className={`w-2 h-2 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success animate-pulse'}`} />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{v.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {t('common.flat')} {v.flatNumber} · {v.category} · {format(new Date(v.entryTime), 'hh:mm a')}
                    {v.vehicleNumber && ` · ${v.vehicleNumber}`}
                  </p>
                </div>
                {!v.exitTime ? (
                  <button className="flex items-center gap-1 px-2 py-1 rounded-lg bg-primary/10 text-primary text-[10px] font-medium">
                    <DoorOpen className="w-3 h-3" /> EXIT
                  </button>
                ) : (
                  <span className="text-[10px] text-muted-foreground">{format(new Date(v.exitTime), 'hh:mm a')}</span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {currentGuard && guardDbId && (
        <div className="mt-6">
          <BiometricSetup userType="guard" userId={guardDbId} userName={currentGuard.name} />
        </div>
      )}
    </div>
  );
};

export default DashboardPage;
