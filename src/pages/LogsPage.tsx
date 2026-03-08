import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import { Search, FileText, LogOut, Download } from 'lucide-react';
import { format } from 'date-fns';
import { useLanguage } from '@/i18n/LanguageContext';
import { confirmAction, showToast } from '@/lib/swal';

const LogsPage = () => {
  const { visitors, markExit } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [dateFilter, setDateFilter] = useState(format(new Date(), 'yyyy-MM-dd'));

  const filtered = useMemo(() => {
    return visitors.filter(v => {
      const matchSearch = !search ||
        v.name.toLowerCase().includes(search.toLowerCase()) || v.phone.includes(search) ||
        v.flatNumber.toLowerCase().includes(search.toLowerCase()) ||
        (v.vehicleNumber && v.vehicleNumber.toLowerCase().includes(search.toLowerCase())) ||
        v.guardName.toLowerCase().includes(search.toLowerCase());
      const matchCategory = categoryFilter === 'all' || v.category === categoryFilter;
      const matchDate = !dateFilter || v.entryTime.startsWith(dateFilter);
      return matchSearch && matchCategory && matchDate;
    });
  }, [visitors, search, categoryFilter, dateFilter]);

  const handleExit = async (id: string) => {
    const confirmed = await confirmAction(t('swal.confirmExit'), t('swal.confirmExitText'), t('swal.yes'), t('swal.no'));
    if (confirmed) {
      await markExit(id);
      showToast(t('swal.exitMarked'));
    }
  };

  const exportCSV = () => {
    const headers = ['Name', 'Phone', 'Flat', 'Category', 'Purpose', 'Entry', 'Exit', 'Guard', 'Vehicle'];
    const rows = filtered.map(v => [
      v.name, v.phone, v.flatNumber, v.category, v.purpose,
      format(new Date(v.entryTime), 'dd/MM/yyyy HH:mm'),
      v.exitTime ? format(new Date(v.exitTime), 'dd/MM/yyyy HH:mm') : 'Inside',
      v.guardName, v.vehicleNumber || '-',
    ]);
    const csv = [headers, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `evergreen-heights-log-${dateFilter}.csv`; a.click();
  };

  const categoryLabels: Record<string, string> = {
    all: t('logs.all'), visitor: t('blacklist.visitor'), delivery: t('delivery.tab.delivery'), service: t('delivery.tab.service'),
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <FileText className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('logs.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('logs.subtitle')}</p>
          </div>
        </div>
        <button onClick={exportCSV} className="btn-secondary text-xs px-3 py-2 flex items-center gap-1">
          <Download className="w-3.5 h-3.5" /> CSV
        </button>
      </div>

      <div className="flex flex-col gap-3 mb-4">
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input className="input-field pl-9" placeholder={t('logs.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <div className="flex gap-2">
          <input type="date" className="input-field text-xs flex-1" value={dateFilter} onChange={e => setDateFilter(e.target.value)} />
          <div className="flex gap-1">
            {['all', 'visitor', 'delivery', 'service'].map(c => (
              <button key={c}
                className={`px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all ${categoryFilter === c ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => setCategoryFilter(c)}>
                {categoryLabels[c]}
              </button>
            ))}
          </div>
        </div>
      </div>

      <p className="text-xs text-muted-foreground mb-3">{filtered.length} {t('common.records')}</p>

      <div className="flex flex-col gap-2">
        {filtered.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">{t('logs.noRecords')}</p>
        ) : (
          filtered.map(v => (
            <div key={v.id} className="card-section">
              <div className="flex items-start gap-3">
                <div className={`w-2 h-2 rounded-full mt-1.5 flex-shrink-0 ${v.exitTime ? 'bg-muted-foreground' : 'bg-success animate-pulse'}`} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <p className="text-sm font-semibold truncate">{v.name}</p>
                    <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${
                      v.category === 'visitor' ? 'bg-primary/20 text-primary' :
                      v.category === 'delivery' ? 'bg-warning/20 text-warning' : 'bg-secondary text-secondary-foreground'
                    }`}>{v.category}</span>
                  </div>
                  <p className="text-xs text-muted-foreground"><span className="font-mono">{v.phone}</span> · {t('common.flat')} {v.flatNumber}</p>
                  <p className="text-xs text-muted-foreground">{v.purpose}</p>
                  <div className="flex items-center gap-3 mt-1.5 text-xs text-muted-foreground">
                    <span>In: {format(new Date(v.entryTime), 'hh:mm a')}</span>
                    {v.exitTime && <span>Out: {format(new Date(v.exitTime), 'hh:mm a')}</span>}
                    {v.vehicleNumber && <span className="font-mono">{v.vehicleNumber}</span>}
                  </div>
                  <p className="text-[10px] text-muted-foreground mt-1">{t('logs.guard')}: {v.guardName}</p>
                </div>
                {!v.exitTime && (
                  <button onClick={() => handleExit(v.id)} className="btn-secondary text-xs px-2.5 py-1.5 flex items-center gap-1 flex-shrink-0">
                    <LogOut className="w-3 h-3" /> {t('common.exit')}
                  </button>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default LogsPage;
