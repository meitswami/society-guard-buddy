import { useState, useCallback } from 'react';
import { Calendar, UtensilsCrossed, Scale } from 'lucide-react';
import EventManager from '@/components/EventManager';
import ExpenseSplitter from '@/components/ExpenseSplitter';
import EventFoodReconciliation from '@/components/EventFoodReconciliation';
import type { AdminTab } from '@/lib/adminPermissions';
import type { FinanceSubTab } from '@/components/FinanceManager';

type Props = {
  adminName?: string;
  onNavigateTab?: (tab: AdminTab, opts?: { financeSubTab?: FinanceSubTab }) => void;
};

/**
 * Single module: calendar events + food/catering costs split by family headcount.
 * All other society payments → Finance → Record Payment.
 */
const EventsModule = ({ adminName = 'Admin', onNavigateTab }: Props) => {
  const [receiptRefreshKey, setReceiptRefreshKey] = useState(0);
  const bumpReceipts = useCallback(() => setReceiptRefreshKey((k) => k + 1), []);

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
          <Calendar className="w-5 h-5 text-blue-500" />
        </div>
        <div>
          <h1 className="page-title">Events &amp; food expenses</h1>
          <p className="text-xs text-muted-foreground leading-snug">
            Record event contribution receipts and food/catering bills here — reconcile in one place (not Finance → Transactions).
          </p>
        </div>
      </div>

      <div className="card-section p-3 mb-4 border-primary/20 bg-primary/5">
        <p className="text-xs text-foreground leading-relaxed">
          <UtensilsCrossed className="w-3.5 h-3.5 inline mr-1 text-primary align-text-bottom" />
          <span className="font-medium">Record receipts:</span> contribution payments on each event card; food bills with attachment in Food expenses.
          For electricity, vendors, repairs →{' '}
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
          )}
          .
        </p>
      </div>

      <section className="mb-6">
        <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
          <Calendar className="w-4 h-4 text-blue-500" />
          Events — record contribution receipts
        </h2>
        <p className="text-[11px] text-muted-foreground mb-3 leading-snug">
          Open an event and tap <span className="font-medium text-foreground">Record contribution receipt</span>. Choose{' '}
          <span className="font-medium text-foreground">flat-wise</span> (per flat, headcount, or lump split) or{' '}
          <span className="font-medium text-foreground">without flat</span> (single outsider or collective receipt). Payment proof optional.
        </p>
        <EventManager adminName={adminName} embedded onRecordsChanged={bumpReceipts} />
      </section>

      <section className="mb-6">
        <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
          <UtensilsCrossed className="w-4 h-4 text-orange-500" />
          Food expenses — record bill receipts
        </h2>
        <p className="text-[11px] text-muted-foreground mb-3 leading-snug">
          Create a food group linked to a calendar event, add the bill, and attach the caterer receipt (image/PDF).
        </p>
        <ExpenseSplitter
          adminName={adminName}
          foodOnly
          embedded
          onRecordsChanged={bumpReceipts}
          onOpenFinance={
            onNavigateTab ? () => onNavigateTab('finance', { financeSubTab: 'record_payment' }) : undefined
          }
        />
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
          <Scale className="w-4 h-4 text-emerald-600" />
          Receipts &amp; reconciliation
        </h2>
        <p className="text-[11px] text-muted-foreground mb-3 leading-snug">
          Summary of all contribution and food receipts recorded above — contributions in vs food bills out.
        </p>
        <EventFoodReconciliation adminName={adminName} refreshKey={receiptRefreshKey} />
      </section>
    </div>
  );
};

export default EventsModule;
