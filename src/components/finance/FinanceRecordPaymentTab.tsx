import { Scale } from 'lucide-react';
import ExpenseSplitter from '@/components/ExpenseSplitter';
import HeadFundReconciliation from '@/components/HeadFundReconciliation';

interface Props {
  adminName: string;
  headReconciliationKey: number;
  showHeadFundRecon: boolean;
  onToggleHeadFundRecon: () => void;
  onRecordsChanged: () => void;
  onOpenRecordReceipt: () => void;
}

export function FinanceRecordPaymentTab({
  adminName,
  headReconciliationKey,
  showHeadFundRecon,
  onToggleHeadFundRecon,
  onRecordsChanged,
  onOpenRecordReceipt,
}: Props) {
  return (
    <div>
      <p className="text-xs text-muted-foreground mb-3 leading-snug">
        Record society outflows (electricity, vendors, repairs) and split across flats — same pattern as{' '}
        <span className="text-foreground font-medium">Record receipt</span> for inflows. Event food/catering →{' '}
        <span className="text-foreground font-medium">Events &amp; food</span>.
      </p>
      <ExpenseSplitter adminName={adminName} paymentOnly embedded onRecordsChanged={onRecordsChanged} />
      <div className="mt-4 pt-3 border-t border-border/60">
        <button
          type="button"
          className="btn-secondary w-full flex items-center justify-center gap-2"
          onClick={onToggleHeadFundRecon}
        >
          <Scale className="w-4 h-4" />
          {showHeadFundRecon ? 'Hide head fund reconciliation' : 'Head fund reconciliation'}
        </button>
        {showHeadFundRecon && (
          <div className="mt-3">
            <HeadFundReconciliation
              adminName={adminName}
              refreshKey={headReconciliationKey}
              onOpenRecordReceipt={onOpenRecordReceipt}
            />
          </div>
        )}
      </div>
    </div>
  );
}
