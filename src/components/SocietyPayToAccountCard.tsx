import { Copy, Landmark, Smartphone } from 'lucide-react';
import { toast } from 'sonner';
import {
  buildUpiPayUrl,
  copyableBankDetails,
  type SocietyBankAccount,
} from '@/lib/societyBankAccount';

type Props = {
  account: SocietyBankAccount;
  amount?: number;
  note?: string;
  compact?: boolean;
};

function copyField(label: string, value: string) {
  void navigator.clipboard.writeText(value).then(
    () => toast.success(`${label} copied`),
    () => toast.error('Could not copy'),
  );
}

export default function SocietyPayToAccountCard({ account, amount, note, compact }: Props) {
  const openUpi = () => {
    if (!account.upi_vpa?.trim()) {
      toast.error('Society UPI ID is not configured yet. Use bank transfer with account number & IFSC.');
      return;
    }
    if (!amount || amount <= 0) {
      toast.error('Enter amount first');
      return;
    }
    window.location.href = buildUpiPayUrl({
      upiVpa: account.upi_vpa,
      payeeName: account.account_holder_name,
      amount,
      note,
    });
  };

  const copyAll = () => {
    void navigator.clipboard.writeText(copyableBankDetails(account)).then(
      () => toast.success('All bank details copied'),
      () => toast.error('Could not copy'),
    );
  };

  return (
    <div className={`rounded-xl border border-primary/20 bg-primary/5 ${compact ? 'p-2.5' : 'p-3'} space-y-2`}>
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2">
          <Landmark className="w-4 h-4 text-primary shrink-0" />
          <div>
            <p className="text-xs font-semibold text-foreground">Pay to society account</p>
            <p className="text-[10px] text-muted-foreground">{account.bank_name}</p>
          </div>
        </div>
        <button type="button" className="btn-secondary text-[10px] px-2 py-1 inline-flex items-center gap-1" onClick={copyAll}>
          <Copy className="w-3 h-3" /> Copy all
        </button>
      </div>

      <div className="space-y-1.5 text-xs">
        <DetailRow label="Account name" value={account.account_holder_name} />
        <DetailRow label="Account no." value={account.account_number} mono />
        <DetailRow label="IFSC" value={account.ifsc} mono />
        {account.branch_name && <DetailRow label="Branch" value={account.branch_name} />}
        {account.upi_vpa && <DetailRow label="UPI ID" value={account.upi_vpa} mono />}
      </div>

      <div className="flex flex-wrap gap-2 pt-1">
        {account.upi_vpa && (
          <button type="button" className="btn-primary text-xs inline-flex items-center gap-1" onClick={openUpi}>
            <Smartphone className="w-3.5 h-3.5" /> Open UPI app
          </button>
        )}
        <p className="text-[10px] text-muted-foreground leading-snug w-full">
          Transfer via UPI / NEFT / IMPS to this account, then submit your UTR / reference and receipt below for verification.
        </p>
      </div>
    </div>
  );
}

function DetailRow({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-2">
      <div className="min-w-0">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wider">{label}</p>
        <p className={`text-sm text-foreground break-all ${mono ? 'font-mono' : 'font-medium'}`}>{value}</p>
      </div>
      <button
        type="button"
        className="text-[10px] text-primary shrink-0 pt-3"
        onClick={() => copyField(label, value)}
      >
        Copy
      </button>
    </div>
  );
}
