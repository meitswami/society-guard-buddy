export type SocietyBankAccount = {
  id: string;
  society_id: string;
  bank_name: string;
  account_holder_name: string;
  account_number: string;
  ifsc: string;
  branch_name: string | null;
  branch_address: string | null;
  micr: string | null;
  account_type: string | null;
  currency: string;
  upi_vpa: string | null;
  customer_id: string | null;
  is_primary: boolean;
  is_active: boolean;
  effective_from: string | null;
  effective_to: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type SocietyBankAccountInput = {
  bank_name: string;
  account_holder_name: string;
  account_number: string;
  ifsc: string;
  branch_name?: string | null;
  branch_address?: string | null;
  micr?: string | null;
  account_type?: string | null;
  currency?: string;
  upi_vpa?: string | null;
  customer_id?: string | null;
  is_primary?: boolean;
  is_active?: boolean;
  effective_from?: string | null;
  effective_to?: string | null;
  notes?: string | null;
};

export function maskAccountNumber(accountNumber: string): string {
  const digits = accountNumber.replace(/\s+/g, '');
  if (digits.length <= 4) return digits;
  return `${'•'.repeat(Math.max(0, digits.length - 4))}${digits.slice(-4)}`;
}

export function buildUpiPayUrl(opts: {
  upiVpa: string;
  payeeName: string;
  amount?: number;
  note?: string;
}): string {
  const params = new URLSearchParams();
  params.set('pa', opts.upiVpa.trim());
  params.set('pn', opts.payeeName.trim() || 'Society');
  params.set('cu', 'INR');
  if (opts.amount && opts.amount > 0) params.set('am', String(opts.amount));
  if (opts.note?.trim()) params.set('tn', opts.note.trim());
  return `upi://pay?${params.toString()}`;
}

export function copyableBankDetails(account: Pick<
  SocietyBankAccount,
  'account_holder_name' | 'account_number' | 'ifsc' | 'bank_name' | 'branch_name' | 'upi_vpa'
>): string {
  const lines = [
    `Account name: ${account.account_holder_name}`,
    `Bank: ${account.bank_name}`,
    `Account number: ${account.account_number}`,
    `IFSC: ${account.ifsc}`,
  ];
  if (account.branch_name) lines.push(`Branch: ${account.branch_name}`);
  if (account.upi_vpa) lines.push(`UPI: ${account.upi_vpa}`);
  return lines.join('\n');
}
