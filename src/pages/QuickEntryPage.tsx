import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import type { Visitor } from '@/types';
import { Zap, Search, UserCheck } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';

const QuickEntryPage = () => {
  const { visitors, addVisitor, currentGuard } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [success, setSuccess] = useState<string | null>(null);

  const frequentVisitors = useMemo(() => {
    const phoneMap = new Map<string, { visitor: Visitor; count: number }>();
    visitors.forEach(v => {
      const existing = phoneMap.get(v.phone);
      if (existing) {
        existing.count++;
        if (v.entryTime > existing.visitor.entryTime) existing.visitor = v;
      } else {
        phoneMap.set(v.phone, { visitor: v, count: 1 });
      }
    });
    return Array.from(phoneMap.values()).filter(e => e.count >= 2).sort((a, b) => b.count - a.count);
  }, [visitors]);

  const filtered = useMemo(() => {
    if (!search.trim()) return frequentVisitors;
    const q = search.toLowerCase();
    return frequentVisitors.filter(e =>
      e.visitor.name.toLowerCase().includes(q) || e.visitor.phone.includes(q) || e.visitor.flatNumber.toLowerCase().includes(q)
    );
  }, [frequentVisitors, search]);

  const quickLog = async (source: Visitor) => {
    const entry: Visitor = {
      id: `Q${Date.now()}`, name: source.name, phone: source.phone,
      documentType: source.documentType, documentNumber: source.documentNumber,
      visitorPhotos: source.visitorPhotos, flatNumber: source.flatNumber,
      purpose: source.purpose || 'Regular Visit', entryTime: new Date().toISOString(),
      guardId: currentGuard?.id || '', guardName: currentGuard?.name || '',
      category: source.category, company: source.company,
    };
    await addVisitor(entry);
    setSuccess(source.name);
    setTimeout(() => setSuccess(null), 2000);
  };

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Zap className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">{t('quick.title')}</h1>
          <p className="text-xs text-muted-foreground">{t('quick.subtitle')}</p>
        </div>
      </div>

      {success && (
        <div className="card-section border-success/30 mb-4 text-center">
          <p className="text-[hsl(var(--success))] text-sm font-semibold">✓ {success} {t('quick.loggedIn')}</p>
        </div>
      )}

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('quick.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {filtered.length === 0 ? (
        <div className="text-center py-12">
          <Zap className="w-8 h-8 text-muted-foreground mx-auto mb-2" />
          <p className="text-sm text-muted-foreground">{search ? t('quick.noMatch') : t('quick.noFrequent')}</p>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {filtered.map(({ visitor: v, count }) => (
            <div key={v.phone} className="card-section flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center flex-shrink-0 overflow-hidden">
                {v.visitorPhotos.length > 0 ? (
                  <img src={v.visitorPhotos[0]} alt={v.name} className="w-full h-full object-cover" />
                ) : (
                  <span className="text-sm font-bold text-muted-foreground">{v.name.charAt(0).toUpperCase()}</span>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold truncate">{v.name}</p>
                <p className="text-xs font-mono text-muted-foreground">{v.phone}</p>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className="text-[10px] text-muted-foreground">{t('common.flat')} {v.flatNumber}</span>
                  <span className="text-[10px] text-muted-foreground">·</span>
                  <span className="text-[10px] text-primary font-medium">{count} {t('quick.visits')}</span>
                </div>
              </div>
              <button onClick={() => quickLog(v)} className="btn-primary text-xs px-3 py-2 flex items-center gap-1.5 flex-shrink-0">
                <UserCheck className="w-3.5 h-3.5" /> {t('common.enter')}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default QuickEntryPage;
