import { cn } from '@/lib/utils';
import { DescriptiveValueButton } from '@/components/DescriptiveStatCard';
import { SUM_INSIGHT_METRICS } from '@/lib/descriptiveMetricCopy';
import {
  type ChannelTotals,
  channelTotal,
  normalizePaymentChannel,
  netChannels,
} from '@/lib/cashBankChannel';

interface Props {
  receipts: ChannelTotals;
  payments: ChannelTotals;
  /** inline = one-line summary; table = cash/bank/other rows; compact = small grid under headings */
  variant?: 'inline' | 'table' | 'compact';
  className?: string;
  receiptLabel?: string;
  paymentLabel?: string;
}

const fmt = (n: number) => `₹${n.toLocaleString('en-IN')}`;

function TotalsStrip({
  receipts,
  payments,
  net,
  className,
}: {
  receipts: ChannelTotals;
  payments: ChannelTotals;
  net: ChannelTotals;
  className?: string;
}) {
  const receiptTotal = channelTotal(receipts);
  const paymentTotal = channelTotal(payments);
  const netTotal = channelTotal(net);
  return (
    <div
      className={cn(
        'flex flex-wrap items-center justify-center gap-x-4 gap-y-1 text-[10px] border-t border-border/60 pt-1.5 mt-1.5',
        className,
      )}
    >
      <span className="text-green-700">
        Receipts total{' '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankReceiptTotal}
          value={fmt(receiptTotal)}
          valueClassName="text-[10px] font-semibold text-green-700"
          className="inline-flex px-0.5 py-0"
        />
        <span className="text-muted-foreground font-normal">
          {' '}
          (Cash {fmt(receipts.cash)} · Bank {fmt(receipts.bank)}
          {receipts.other > 0 ? ` · Other ${fmt(receipts.other)}` : ''})
        </span>
      </span>
      <span className="text-orange-700">
        Payments total{' '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankPaymentTotal}
          value={fmt(paymentTotal)}
          valueClassName="text-[10px] font-semibold text-orange-700"
          className="inline-flex px-0.5 py-0"
        />
        <span className="text-muted-foreground font-normal">
          {' '}
          (Cash {fmt(payments.cash)} · Bank {fmt(payments.bank)}
          {payments.other > 0 ? ` · Other ${fmt(payments.other)}` : ''})
        </span>
      </span>
      <span className={cn('font-medium', netTotal >= 0 ? 'text-foreground' : 'text-destructive')}>
        Net total{' '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankNetTotal}
          value={fmt(netTotal)}
          valueClassName={cn('text-[10px] font-semibold', netTotal >= 0 ? 'text-foreground' : 'text-destructive')}
          className="inline-flex px-0.5 py-0"
        />
        <span className="text-muted-foreground font-normal">
          {' '}
          (Cash {fmt(net.cash)} · Bank {fmt(net.bank)}
          {net.other !== 0 ? ` · Other ${fmt(net.other)}` : ''})
        </span>
      </span>
    </div>
  );
}

const CashBankBreakdown = ({
  receipts,
  payments,
  variant = 'table',
  className,
  receiptLabel = 'Receipts (in)',
  paymentLabel = 'Payments (out)',
}: Props) => {
  const net = netChannels(receipts, payments);

  if (variant === 'inline') {
    const rParts = [
      receipts.cash > 0 && `cash ${fmt(receipts.cash)}`,
      receipts.bank > 0 && `bank ${fmt(receipts.bank)}`,
      receipts.other > 0 && `other ${fmt(receipts.other)}`,
    ].filter(Boolean);
    const pParts = [
      payments.cash > 0 && `cash ${fmt(payments.cash)}`,
      payments.bank > 0 && `bank ${fmt(payments.bank)}`,
      payments.other > 0 && `other ${fmt(payments.other)}`,
    ].filter(Boolean);
    return (
      <p className={cn('text-[10px] text-muted-foreground leading-snug', className)}>
        <span className="text-green-700">{receiptLabel}:</span> {rParts.length ? rParts.join(' · ') : fmt(0)}
        {' · '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankReceiptTotal}
          value={`Total ${fmt(channelTotal(receipts))}`}
          valueClassName="text-[10px] font-semibold text-green-800"
          className="inline-flex px-0.5 py-0"
        />
        {' · '}
        <span className="text-orange-700">{paymentLabel}:</span> {pParts.length ? pParts.join(' · ') : fmt(0)}
        {' · '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankPaymentTotal}
          value={`Total ${fmt(channelTotal(payments))}`}
          valueClassName="text-[10px] font-semibold text-orange-800"
          className="inline-flex px-0.5 py-0"
        />
        {' · '}
        <DescriptiveValueButton
          {...SUM_INSIGHT_METRICS.cashBankNetTotal}
          value={`Net ${fmt(channelTotal(net))}`}
          valueClassName={cn('text-[10px] font-semibold', channelTotal(net) >= 0 ? 'text-foreground' : 'text-destructive')}
          className="inline-flex px-0.5 py-0"
        />
      </p>
    );
  }

  if (variant === 'compact') {
    return (
      <div className={cn('rounded-lg border border-border/60 bg-muted/10 p-2', className)}>
        <div className="grid grid-cols-3 gap-1 text-[10px]">
          {(['cash', 'bank', 'other'] as const).map((ch) => {
            const label = ch === 'cash' ? 'Cash' : ch === 'bank' ? 'Bank' : 'Other';
            const rin = receipts[ch];
            const rout = payments[ch];
            const n = net[ch];
            return (
              <div key={ch} className="rounded bg-muted/40 px-1.5 py-1 text-center">
                <p className="font-medium text-muted-foreground">{label}</p>
                <p className="text-green-700">+{fmt(rin)}</p>
                <p className="text-orange-700">−{fmt(rout)}</p>
                <p className={cn('font-semibold', n >= 0 ? 'text-foreground' : 'text-destructive')}>{fmt(n)}</p>
              </div>
            );
          })}
        </div>
        <TotalsStrip receipts={receipts} payments={payments} net={net} />
      </div>
    );
  }

  const rows: { key: string; label: string; r: ChannelTotals; bold?: boolean }[] = [
    { key: 'receipts', label: receiptLabel, r: receipts },
    { key: 'payments', label: paymentLabel, r: payments },
    { key: 'net', label: 'Net (receipts − payments)', r: net, bold: true },
  ];

  return (
    <div className={cn('overflow-x-auto rounded-lg border border-border/60 bg-muted/10 p-2', className)}>
      <table className="w-full text-[10px] border border-border rounded-md overflow-hidden">
        <thead>
          <tr className="bg-muted/50 text-left">
            <th className="p-1.5 border-b border-border" />
            <th className="p-1.5 border-b border-border text-right">Cash</th>
            <th className="p-1.5 border-b border-border text-right">Bank / UPI</th>
            <th className="p-1.5 border-b border-border text-right">Other</th>
            <th className="p-1.5 border-b border-border text-right font-semibold">Total</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(({ key, label, r, bold }) => (
            <tr key={key} className={bold ? 'bg-muted/20 font-semibold' : undefined}>
              <td className="p-1.5 border-b border-border/80">{label}</td>
              <td className="p-1.5 border-b border-border/80 text-right">
                <DescriptiveValueButton
                  {...SUM_INSIGHT_METRICS.channelCash}
                  title={`${label} — cash`}
                  value={fmt(r.cash)}
                  valueClassName="text-[10px] font-mono"
                  className="justify-end w-full px-0.5 py-0"
                />
              </td>
              <td className="p-1.5 border-b border-border/80 text-right">
                <DescriptiveValueButton
                  {...SUM_INSIGHT_METRICS.channelBank}
                  title={`${label} — bank / UPI`}
                  value={fmt(r.bank)}
                  valueClassName="text-[10px] font-mono"
                  className="justify-end w-full px-0.5 py-0"
                />
              </td>
              <td className="p-1.5 border-b border-border/80 text-right">
                <DescriptiveValueButton
                  {...SUM_INSIGHT_METRICS.channelOther}
                  title={`${label} — other`}
                  value={fmt(r.other)}
                  valueClassName="text-[10px] font-mono"
                  className="justify-end w-full px-0.5 py-0"
                />
              </td>
              <td className="p-1.5 border-b border-border/80 text-right">
                <DescriptiveValueButton
                  {...SUM_INSIGHT_METRICS.rowTotal}
                  title={`${label} — total`}
                  value={fmt(channelTotal(r))}
                  valueClassName={cn('text-[10px] font-mono', bold && 'font-semibold')}
                  className="justify-end w-full px-0.5 py-0"
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <TotalsStrip receipts={receipts} payments={payments} net={net} className="border-t-0 mt-2 pt-2" />
    </div>
  );
};

/** Badge for a single row's payment method */
export function ChannelBadge({ method, className }: { method: unknown; className?: string }) {
  const ch = normalizePaymentChannel(method);
  const label = ch === 'cash' ? 'Cash' : ch === 'bank' ? 'Bank' : 'Other';
  const colors =
    ch === 'cash'
      ? 'bg-amber-500/15 text-amber-800 dark:text-amber-300'
      : ch === 'bank'
        ? 'bg-blue-500/15 text-blue-800 dark:text-blue-300'
        : 'bg-muted text-muted-foreground';
  return (
    <span className={cn('text-[9px] px-1.5 py-0.5 rounded-full font-medium uppercase', colors, className)}>
      {label}
    </span>
  );
}

export default CashBankBreakdown;
