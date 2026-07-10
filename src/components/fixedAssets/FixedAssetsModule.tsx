import { useEffect, useState } from 'react';
import { Building2, ClipboardList, BarChart3, Sparkles } from 'lucide-react';
import { toast } from 'sonner';
import { useStore } from '@/store/useStore';
import {
  useFixedAssetExpenseGroups,
  useFixedAssetMutations,
  useFixedAssets,
} from '@/hooks/useFixedAssets';
import FixedAssetRegister from '@/components/fixedAssets/FixedAssetRegister';
import FixedAssetReports from '@/components/fixedAssets/FixedAssetReports';
import type { AdminTab } from '@/lib/adminPermissions';
import type { FinanceSubTab } from '@/components/FinanceManager';

type SubTab = 'register' | 'reports';

type Props = {
  adminName?: string;
  onNavigateTab?: (tab: AdminTab, opts?: { financeSubTab?: FinanceSubTab }) => void;
};

const SUB_TABS: { id: SubTab; label: string; icon: React.ElementType }[] = [
  { id: 'register', label: 'Asset register', icon: ClipboardList },
  { id: 'reports', label: 'Reports', icon: BarChart3 },
];

export default function FixedAssetsModule({ adminName = 'Admin', onNavigateTab }: Props) {
  const societyName = useStore((s) => s.societyName) ?? 'Society';
  const [subTab, setSubTab] = useState<SubTab>('register');
  const [seeded, setSeeded] = useState(false);

  const { data: assets = [], isLoading, refetch } = useFixedAssets();
  const { data: expenseGroups = [] } = useFixedAssetExpenseGroups();
  const { seedTemplates, create, update, remove } = useFixedAssetMutations(adminName);

  useEffect(() => {
    if (seeded || isLoading) return;
    if (assets.length > 0) {
      setSeeded(true);
      return;
    }
    seedTemplates.mutateAsync()
      .then((count) => {
        setSeeded(true);
        if (count > 0) {
          toast.message(`Loaded ${count} standard society assets — fill in builder handover details`);
          refetch();
        }
      })
      .catch(() => setSeeded(true));
  }, [assets.length, isLoading, seeded, seedTemplates, refetch]);

  const handleSeedTemplates = async () => {
    try {
      const count = await seedTemplates.mutateAsync();
      if (count > 0) {
        toast.success(`Added ${count} standard asset templates`);
      } else {
        toast.message('Standard templates already exist');
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not load templates');
    }
  };

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-violet-500/10 flex items-center justify-center">
          <Building2 className="w-5 h-5 text-violet-600" />
        </div>
        <div>
          <h1 className="page-title">Fixed Assets</h1>
          <p className="text-xs text-muted-foreground leading-snug">
            Society asset register — builder handover, manual entry, and auto-sync from Finance payments.
          </p>
        </div>
      </div>

      <div className="card-section p-3 mb-4 border-primary/20 bg-primary/5">
        <p className="text-xs text-foreground leading-relaxed">
          <Sparkles className="w-3.5 h-3.5 inline mr-1 text-primary align-text-bottom" />
          Standard assets (garden, gym, DG, lift, fire fighting, boring, water softener, etc.) are pre-loaded as templates.
          Record purchases in{' '}
          {onNavigateTab ? (
            <button
              type="button"
              className="text-primary underline font-medium"
              onClick={() => onNavigateTab('finance', { financeSubTab: 'record_payment' })}
            >
              Finance → Record Payment
            </button>
          ) : (
            <span className="font-medium">Finance → Record Payment</span>
          )}{' '}
          under <span className="font-medium">FIXED ASSETS</span> to auto-add them here.
        </p>
      </div>

      <div className="flex gap-1 mb-4 p-1 bg-muted/40 rounded-xl">
        {SUB_TABS.map((t) => {
          const Icon = t.icon;
          const active = subTab === t.id;
          return (
            <button
              key={t.id}
              type="button"
              onClick={() => setSubTab(t.id)}
              className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-2 rounded-lg text-xs font-medium transition-colors ${
                active ? 'bg-background shadow-sm text-foreground' : 'text-muted-foreground'
              }`}
            >
              <Icon className="w-3.5 h-3.5" />
              {t.label}
            </button>
          );
        })}
      </div>

      {subTab === 'register' && (
        <>
          <div className="flex justify-end mb-2">
            <button type="button" className="btn-secondary text-[10px] px-2 py-1" onClick={handleSeedTemplates}>
              Reload standard templates
            </button>
          </div>
          <FixedAssetRegister
            assets={assets}
            expenseGroups={expenseGroups}
            loading={isLoading}
            onCreate={(input) => create.mutateAsync(input)}
            onUpdate={(id, input) => update.mutateAsync({ id, input })}
            onDelete={(id) => remove.mutateAsync(id)}
            onNavigateFinance={
              onNavigateTab ? () => onNavigateTab('finance', { financeSubTab: 'record_payment' }) : undefined
            }
          />
        </>
      )}

      {subTab === 'reports' && <FixedAssetReports societyName={societyName} assets={assets} />}
    </div>
  );
}
