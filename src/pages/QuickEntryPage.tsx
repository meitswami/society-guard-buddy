import { useMemo, useState } from 'react';
import { useStore } from '@/store/useStore';
import type { Visitor } from '@/types';
import { Zap, Search, UserCheck, LogOut } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { confirmAction, showToast } from '@/lib/swal';
import {
  isQuickEntryStaffMember,
  memberToQuickVisitorTemplate,
} from '@/lib/memberStaff';

type QuickRow = {
  key: string;
  visitor: Visitor;
  visitCount: number;
  isStaff: boolean;
};

function findActiveVisit(visitors: Visitor[], template: Visitor): Visitor | undefined {
  const inside = visitors.filter(v => !v.exitTime);
  const byPhone = inside.find(v => v.phone === template.phone);
  if (byPhone) return byPhone;
  const nameLc = template.name.trim().toLowerCase();
  const flat = template.flatNumber.trim().toLowerCase();
  return inside.find(
    v =>
      v.flatNumber.trim().toLowerCase() === flat &&
      v.name.trim().toLowerCase() === nameLc
  );
}

function rowMatchesSearch(row: QuickRow, q: string): boolean {
  const v = row.visitor;
  return (
    v.name.toLowerCase().includes(q) ||
    v.phone.includes(q) ||
    v.flatNumber.toLowerCase().includes(q) ||
    v.purpose.toLowerCase().includes(q)
  );
}

const QuickEntryPage = () => {
  const { visitors, members, flats, addVisitor, markExit, currentGuard } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [success, setSuccess] = useState<string | null>(null);

  const flatNumberById = useMemo(
    () => new Map(flats.map(f => [f.id, f.flatNumber])),
    [flats]
  );

  const quickRows = useMemo((): QuickRow[] => {
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
    const frequent = Array.from(phoneMap.values())
      .filter(e => e.count >= 2)
      .sort((a, b) => b.count - a.count);

    const byPhone = new Map<string, QuickRow>();

    for (const m of members) {
      if (!isQuickEntryStaffMember(m)) continue;
      const flatNumber = flatNumberById.get(m.flatId);
      if (!flatNumber) continue;
      const visitor = memberToQuickVisitorTemplate(m, flatNumber);
      byPhone.set(visitor.phone, {
        key: `staff-${m.id}`,
        visitor,
        visitCount: 0,
        isStaff: true,
      });
    }

    for (const { visitor: v, count } of frequent) {
      const existing = byPhone.get(v.phone);
      if (existing) {
        existing.visitCount = count;
        if (existing.visitor.visitorPhotos.length === 0 && v.visitorPhotos.length > 0) {
          existing.visitor = {
            ...existing.visitor,
            visitorPhotos: v.visitorPhotos,
          };
        }
      } else {
        byPhone.set(v.phone, {
          key: `freq-${v.phone}`,
          visitor: v,
          visitCount: count,
          isStaff: false,
        });
      }
    }

    return Array.from(byPhone.values()).sort((a, b) =>
      a.visitor.name.localeCompare(b.visitor.name)
    );
  }, [visitors, members, flats]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return quickRows;
    return quickRows.filter(row => rowMatchesSearch(row, q));
  }, [quickRows, search]);

  const quickLog = async (source: Visitor) => {
    const entry: Visitor = {
      id: `Q${Date.now()}`,
      name: source.name,
      phone: source.phone,
      documentType: source.documentType,
      documentNumber: source.documentNumber,
      visitorPhotos: source.visitorPhotos,
      flatNumber: source.flatNumber,
      purpose: source.purpose || 'Regular Visit',
      entryTime: new Date().toISOString(),
      guardId: currentGuard?.id || '',
      guardName: currentGuard?.name || '',
      category: source.category,
      company: source.company,
    };
    await addVisitor(entry);
    setSuccess(`${source.name} ${t('quick.loggedIn')}`);
    setTimeout(() => setSuccess(null), 2000);
  };

  const quickExit = async (template: Visitor) => {
    const active = findActiveVisit(visitors, template);
    if (!active) return;
    const confirmed = await confirmAction(
      t('swal.confirmExit'),
      t('swal.confirmExitText'),
      t('swal.yes'),
      t('swal.no')
    );
    if (!confirmed) return;
    await markExit(active.id);
    showToast(t('swal.exitMarked'));
    setSuccess(`${active.name} ${t('quick.exited')}`);
    setTimeout(() => setSuccess(null), 2000);
  };

  const emptyMessage = search.trim()
    ? t('quick.noMatch')
    : t('quick.emptyHint');

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
          <p className="text-[hsl(var(--success))] text-sm font-semibold">
            ✓ {success}
          </p>
        </div>
      )}

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input
          className="input-field pl-9"
          placeholder={t('quick.searchPlaceholder')}
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {filtered.length === 0 ? (
        <div className="text-center py-12">
          <Zap className="w-8 h-8 text-muted-foreground mx-auto mb-2" />
          <p className="text-sm text-muted-foreground">{emptyMessage}</p>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {filtered.map(row => {
            const v = row.visitor;
            const active = findActiveVisit(visitors, v);
            return (
              <div key={row.key} className="card-section flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center flex-shrink-0 overflow-hidden">
                  {v.visitorPhotos.length > 0 ? (
                    <img
                      src={v.visitorPhotos[0]}
                      alt={v.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <span className="text-sm font-bold text-muted-foreground">
                      {v.name.charAt(0).toUpperCase()}
                    </span>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-sm font-semibold truncate">{v.name}</p>
                    {row.isStaff && (
                      <span className="text-[9px] px-1.5 py-0.5 rounded bg-secondary text-secondary-foreground font-medium shrink-0">
                        {t('quick.staffBadge')}
                      </span>
                    )}
                    {active && (
                      <span className="text-[9px] px-1.5 py-0.5 rounded bg-success/20 text-[hsl(var(--success))] font-medium shrink-0">
                        {t('common.inside')}
                      </span>
                    )}
                  </div>
                  <p className="text-xs font-mono text-muted-foreground">
                    {v.phone.startsWith('staff-') ? t('quick.noPhoneOnFile') : v.phone}
                  </p>
                  <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                    <span className="text-[10px] text-muted-foreground">
                      {t('common.flat')} {v.flatNumber}
                    </span>
                    {row.visitCount >= 2 && (
                      <>
                        <span className="text-[10px] text-muted-foreground">·</span>
                        <span className="text-[10px] text-primary font-medium">
                          {row.visitCount} {t('quick.visits')}
                        </span>
                      </>
                    )}
                  </div>
                </div>
                <div className="flex flex-col gap-1.5 flex-shrink-0">
                  {active ? (
                    <button
                      type="button"
                      onClick={() => quickExit(v)}
                      className="btn-primary text-xs px-3 py-2 flex items-center justify-center gap-1.5"
                    >
                      <LogOut className="w-3.5 h-3.5" /> {t('common.exit')}
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => quickLog(v)}
                      className="btn-primary text-xs px-3 py-2 flex items-center justify-center gap-1.5"
                    >
                      <UserCheck className="w-3.5 h-3.5" /> {t('common.enter')}
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default QuickEntryPage;
