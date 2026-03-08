import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import { BookUser, Search, ChevronDown, ChevronUp, FileText } from 'lucide-react';
import { format } from 'date-fns';
import { useLanguage } from '@/i18n/LanguageContext';

const DirectoryPage = () => {
  const { visitors } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const directory = useMemo(() => {
    const phoneMap = new Map<string, { latest: typeof visitors[0]; totalVisits: number; firstVisit: string }>();
    visitors.forEach(v => {
      const existing = phoneMap.get(v.phone);
      if (existing) {
        existing.totalVisits++;
        if (v.entryTime > existing.latest.entryTime) existing.latest = v;
        if (v.entryTime < existing.firstVisit) existing.firstVisit = v.entryTime;
      } else {
        phoneMap.set(v.phone, { latest: v, totalVisits: 1, firstVisit: v.entryTime });
      }
    });
    return Array.from(phoneMap.values()).sort((a, b) => b.latest.entryTime.localeCompare(a.latest.entryTime));
  }, [visitors]);

  const filtered = useMemo(() => {
    if (!search.trim()) return directory;
    const q = search.toLowerCase();
    return directory.filter(e =>
      e.latest.name.toLowerCase().includes(q) || e.latest.phone.includes(q) ||
      e.latest.flatNumber.toLowerCase().includes(q) || (e.latest.vehicleNumber && e.latest.vehicleNumber.toLowerCase().includes(q))
    );
  }, [directory, search]);

  const exportPDF = () => {
    const rows = filtered.map(e => {
      const v = e.latest;
      const photoHtml = v.visitorPhotos.length > 0
        ? `<img src="${v.visitorPhotos[0]}" style="width:60px;height:60px;object-fit:cover;border-radius:6px;" />`
        : `<div style="width:60px;height:60px;border-radius:6px;background:#ddd;display:flex;align-items:center;justify-content:center;font-size:20px;font-weight:bold;color:#888;">${v.name.charAt(0)}</div>`;
      return `<tr><td style="padding:8px;border-bottom:1px solid #eee;">${photoHtml}</td>
        <td style="padding:8px;border-bottom:1px solid #eee;"><strong>${v.name}</strong><br/><span style="color:#666;font-size:12px;">${v.phone}</span></td>
        <td style="padding:8px;border-bottom:1px solid #eee;">${v.flatNumber}</td><td style="padding:8px;border-bottom:1px solid #eee;">${v.category}</td>
        <td style="padding:8px;border-bottom:1px solid #eee;">${v.documentType} ${v.documentNumber ? `— ${v.documentNumber}` : ''}</td>
        <td style="padding:8px;border-bottom:1px solid #eee;">${e.totalVisits}</td>
        <td style="padding:8px;border-bottom:1px solid #eee;">${format(new Date(e.firstVisit), 'dd/MM/yyyy')}</td></tr>`;
    }).join('');
    const html = `<!DOCTYPE html><html><head><title>${t('directory.title')}</title><style>body{font-family:Arial,sans-serif;padding:20px}table{width:100%;border-collapse:collapse}th{text-align:left;padding:10px 8px;background:#f5f5f5;border-bottom:2px solid #ddd;font-size:13px}td{font-size:13px;vertical-align:middle}h1{font-size:20px;margin-bottom:4px}.sub{color:#888;font-size:13px;margin-bottom:16px}</style></head><body>
      <h1>${t('directory.title')}</h1><p class="sub">${format(new Date(), 'dd MMM yyyy, hh:mm a')} · ${filtered.length} ${t('directory.registeredVisitors')}</p>
      <table><thead><tr><th>Photo</th><th>Name / Phone</th><th>Flat</th><th>Category</th><th>Document</th><th>Visits</th><th>First Visit</th></tr></thead><tbody>${rows}</tbody></table></body></html>`;
    const win = window.open('', '_blank');
    if (win) { win.document.write(html); win.document.close(); setTimeout(() => win.print(), 500); }
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BookUser className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('directory.title')}</h1>
            <p className="text-xs text-muted-foreground">{directory.length} {t('directory.registeredVisitors')}</p>
          </div>
        </div>
        <button onClick={exportPDF} className="btn-secondary text-xs px-3 py-2 flex items-center gap-1">
          <FileText className="w-3.5 h-3.5" /> PDF
        </button>
      </div>

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('directory.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-12">{t('directory.noVisitors')}</p>
      ) : (
        <div className="flex flex-col gap-2">
          {filtered.map(({ latest: v, totalVisits, firstVisit }) => {
            const isExpanded = expandedId === v.phone;
            return (
              <div key={v.phone} className="card-section">
                <button type="button" className="w-full flex items-center gap-3 text-left" onClick={() => setExpandedId(isExpanded ? null : v.phone)}>
                  <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center flex-shrink-0 overflow-hidden">
                    {v.visitorPhotos.length > 0 ? <img src={v.visitorPhotos[0]} alt={v.name} className="w-full h-full object-cover" />
                      : <span className="text-sm font-bold text-muted-foreground">{v.name.charAt(0).toUpperCase()}</span>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{v.name}</p>
                    <p className="text-xs font-mono text-muted-foreground">{v.phone}</p>
                  </div>
                  <div className="text-right flex-shrink-0 flex items-center gap-2">
                    <span className="text-[10px] text-primary font-medium">{totalVisits}x</span>
                    {isExpanded ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
                  </div>
                </button>
                {isExpanded && (
                  <div className="mt-3 pt-3 border-t border-border">
                    {v.visitorPhotos.length > 0 && (
                      <div className="flex gap-2 mb-3 flex-wrap">
                        {v.visitorPhotos.map((p, i) => <img key={i} src={p} alt={`Photo ${i + 1}`} className="w-20 h-20 rounded-lg object-cover border border-border" />)}
                      </div>
                    )}
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div><span className="text-muted-foreground">{t('common.flat')}:</span><span className="ml-1 font-medium">{v.flatNumber}</span></div>
                      <div><span className="text-muted-foreground">{t('directory.category')}:</span><span className="ml-1 font-medium capitalize">{v.category}</span></div>
                      <div><span className="text-muted-foreground">{t('directory.document')}:</span><span className="ml-1 font-medium">{v.documentType} {v.documentNumber && `— ${v.documentNumber}`}</span></div>
                      <div><span className="text-muted-foreground">{t('visitor.purpose')}:</span><span className="ml-1 font-medium">{v.purpose}</span></div>
                      {v.vehicleNumber && <div><span className="text-muted-foreground">{t('blacklist.vehicle')}:</span><span className="ml-1 font-mono font-medium">{v.vehicleNumber}</span></div>}
                      {v.company && <div><span className="text-muted-foreground">{t('delivery.company')}:</span><span className="ml-1 font-medium">{v.company}</span></div>}
                      <div><span className="text-muted-foreground">{t('directory.firstVisit')}:</span><span className="ml-1 font-medium">{format(new Date(firstVisit), 'dd MMM yyyy')}</span></div>
                      <div><span className="text-muted-foreground">{t('directory.lastVisit')}:</span><span className="ml-1 font-medium">{format(new Date(v.entryTime), 'dd MMM yyyy')}</span></div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default DirectoryPage;
