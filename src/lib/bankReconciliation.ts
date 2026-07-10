import { differenceInCalendarDays, parse, isValid, format } from 'date-fns';
import { normalizePaymentChannel } from '@/lib/financeAuditDetection';
import { ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';

export const BANK_RECON_DATE_TOLERANCE_DAYS = 3;
export const HIGH_CONFIDENCE_THRESHOLD = 0.8;

export type BankStatementCsvRow = {
  line_date: string;
  amount: number;
  description: string;
  reference: string;
  raw_row: Record<string, string>;
};

export type ReconcilablePayment = {
  kind: 'maintenance_payment';
  id: string;
  amount: number;
  date: string;
  payment_method: string;
  transaction_id: string | null;
  flat_number: string;
  label: string;
};

export type ReconcilableLedgerEntry = {
  kind: 'finance_entry';
  id: string;
  amount: number;
  date: string;
  payment_method: string;
  transaction_id: string | null;
  title: string | null;
  destination: string;
  label: string;
};

export type ReconcilableTarget = ReconcilablePayment | ReconcilableLedgerEntry;

export type StatementLineForMatch = {
  id: string;
  line_date: string;
  amount: number;
  description: string | null;
  reference: string | null;
};

export type SuggestedMatch = {
  statement_line_id: string;
  match_type: 'maintenance_payment' | 'finance_entry';
  maintenance_payment_id?: string;
  finance_entry_id?: string;
  match_confidence: number;
  target: ReconcilableTarget;
  reasons: string[];
};

const DATE_ALIASES = ['date', 'transaction date', 'txn date', 'value date', 'posting date', 'tran date'];
const AMOUNT_ALIASES = ['amount', 'transaction amount', 'txn amount'];
const DEBIT_ALIASES = ['debit', 'withdrawal', 'dr', 'debit amount'];
const CREDIT_ALIASES = ['credit', 'deposit', 'cr', 'credit amount'];
const DESC_ALIASES = ['description', 'narration', 'particulars', 'remarks', 'details'];
const REF_ALIASES = ['reference', 'ref', 'utr', 'upi ref', 'cheque no', 'transaction id', 'txn id', 'ref no'];

function normalizeHeader(h: string): string {
  return h.trim().toLowerCase().replace(/[_-]+/g, ' ').replace(/\s+/g, ' ');
}

function findColumnIndex(headers: string[], aliases: string[]): number {
  const normalized = headers.map(normalizeHeader);
  for (const alias of aliases) {
    const idx = normalized.findIndex((h) => h === alias || h.includes(alias));
    if (idx >= 0) return idx;
  }
  return -1;
}

function parseAmount(raw: string): number | null {
  const cleaned = raw.replace(/[₹,\s]/g, '').replace(/\((.*)\)/, '-$1');
  if (!cleaned) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

function parseCsvLine(line: string): string[] {
  const cells: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === ',' && !inQuotes) {
      cells.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  cells.push(current.trim());
  return cells;
}

function parseFlexibleDate(raw: string): string | null {
  const s = raw.trim();
  if (!s) return null;
  const formats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'dd-MM-yyyy', 'dd-MMM-yyyy', 'MMM dd, yyyy', 'dd/MM/yy'];
  for (const f of formats) {
    const d = parse(s, f, new Date());
    if (isValid(d)) return format(d, 'yyyy-MM-dd');
  }
  const iso = new Date(s);
  if (isValid(iso)) return format(iso, 'yyyy-MM-dd');
  return null;
}

/** Parse bank CSV with flexible column headers. */
export function parseBankStatementCsv(text: string): BankStatementCsvRow[] {
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  if (lines.length < 2) return [];

  const headers = parseCsvLine(lines[0]);
  const dateIdx = findColumnIndex(headers, DATE_ALIASES);
  const amountIdx = findColumnIndex(headers, AMOUNT_ALIASES);
  const debitIdx = findColumnIndex(headers, DEBIT_ALIASES);
  const creditIdx = findColumnIndex(headers, CREDIT_ALIASES);
  const descIdx = findColumnIndex(headers, DESC_ALIASES);
  const refIdx = findColumnIndex(headers, REF_ALIASES);

  if (dateIdx < 0) {
    throw new Error('CSV must include a date column (date, value date, transaction date, etc.)');
  }
  if (amountIdx < 0 && (debitIdx < 0 || creditIdx < 0)) {
    throw new Error('CSV must include amount or debit/credit columns');
  }

  const rows: BankStatementCsvRow[] = [];
  for (let i = 1; i < lines.length; i++) {
    const cells = parseCsvLine(lines[i]);
    if (cells.every((c) => !c)) continue;

    const lineDate = parseFlexibleDate(cells[dateIdx] ?? '');
    if (!lineDate) continue;

    let amount: number | null = null;
    if (amountIdx >= 0) {
      amount = parseAmount(cells[amountIdx] ?? '');
    } else {
      const debit = parseAmount(cells[debitIdx] ?? '') ?? 0;
      const credit = parseAmount(cells[creditIdx] ?? '') ?? 0;
      if (debit === 0 && credit === 0) continue;
      amount = credit - debit;
    }
    if (amount === null || amount === 0) continue;

    const raw_row: Record<string, string> = {};
    headers.forEach((h, idx) => {
      raw_row[h] = cells[idx] ?? '';
    });

    rows.push({
      line_date: lineDate,
      amount,
      description: descIdx >= 0 ? (cells[descIdx] ?? '') : '',
      reference: refIdx >= 0 ? (cells[refIdx] ?? '') : '',
      raw_row,
    });
  }
  return rows;
}

export function bankReconCsvTemplate(): string {
  return 'date,amount,description,reference\n2026-04-01,5000.00,UPI/FLAT A-101 maint,UTR123456789\n2026-04-02,-12000.00,NEFT Vendor ABC,NEFT987654321\n';
}

function normalizeRef(s: string | null | undefined): string {
  return (s ?? '').replace(/\s/g, '').toLowerCase();
}

function refsOverlap(a: string | null | undefined, b: string | null | undefined): boolean {
  const na = normalizeRef(a);
  const nb = normalizeRef(b);
  if (!na || !nb) return false;
  if (na === nb) return true;
  if (na.length >= 6 && nb.includes(na)) return true;
  if (nb.length >= 6 && na.includes(nb)) return true;
  return false;
}

function flatInText(flatNumber: string, text: string): boolean {
  if (!flatNumber || !text) return false;
  const norm = text.replace(/\s/g, '').toLowerCase();
  const flat = flatNumber.replace(/\s/g, '').toLowerCase();
  return norm.includes(flat);
}

function vendorInText(vendor: string | null, text: string): boolean {
  if (!vendor || !text) return false;
  const v = vendor.trim().toLowerCase();
  if (v.length < 3) return false;
  return text.toLowerCase().includes(v);
}

function signedAmountsMatch(statementAmount: number, targetAmount: number): boolean {
  return Math.abs(Math.abs(statementAmount) - Math.abs(targetAmount)) < 0.01;
}

function daysApart(a: string, b: string): number {
  const da = parse(a.slice(0, 10), 'yyyy-MM-dd', new Date());
  const db = parse(b.slice(0, 10), 'yyyy-MM-dd', new Date());
  if (!isValid(da) || !isValid(db)) return 999;
  return Math.abs(differenceInCalendarDays(da, db));
}

export function computeMatchConfidence(
  line: StatementLineForMatch,
  target: ReconcilableTarget,
  dateToleranceDays = BANK_RECON_DATE_TOLERANCE_DAYS,
): { confidence: number; reasons: string[] } {
  const reasons: string[] = [];
  if (!signedAmountsMatch(line.amount, target.amount)) {
    return { confidence: 0, reasons: ['Amount mismatch'] };
  }
  reasons.push('Exact amount');

  let confidence = 0.5;

  const dayDiff = daysApart(line.line_date, target.date);
  if (dayDiff <= dateToleranceDays) {
    confidence += dayDiff === 0 ? 0.25 : 0.15;
    reasons.push(dayDiff === 0 ? 'Same date' : `Date within ±${dateToleranceDays} days`);
  }

  const narration = `${line.description ?? ''} ${line.reference ?? ''}`;
  if (refsOverlap(line.reference, target.transaction_id)) {
    confidence += 0.25;
    reasons.push('Reference / UTR match');
  }

  if (target.kind === 'maintenance_payment') {
    if (flatInText(target.flat_number, narration)) {
      confidence += 0.1;
      reasons.push('Flat number in narration');
    }
  } else if (target.kind === 'finance_entry') {
    if (target.title && narration.toLowerCase().includes(target.title.toLowerCase().slice(0, 8))) {
      confidence += 0.08;
      reasons.push('Title in narration');
    }
  }

  return { confidence: Math.min(1, confidence), reasons };
}

export function buildReconcilableTargets(
  payments: {
    id: string;
    flat_number: string;
    amount: number;
    payment_method: string;
    payment_status: string;
    due_date: string | null;
    payment_date: string | null;
    created_at: string;
    transaction_id?: string | null;
    charge_title?: string;
  }[],
  ledgerEntries: {
    id: string;
    total_amount: number;
    payment_method: string;
    payment_status: string;
    transaction_date?: string | null;
    entry_month?: string | null;
    created_at: string;
    transaction_id?: string | null;
    title?: string | null;
    destination: string;
  }[],
  alreadyMatchedPaymentIds: Set<string>,
  alreadyMatchedEntryIds: Set<string>,
): ReconcilableTarget[] {
  const targets: ReconcilableTarget[] = [];

  for (const p of payments) {
    if (p.payment_status !== 'verified') continue;
    if (normalizePaymentChannel(p.payment_method) !== 'bank') continue;
    if (alreadyMatchedPaymentIds.has(p.id)) continue;
    targets.push({
      kind: 'maintenance_payment',
      id: p.id,
      amount: Number(p.amount),
      date: paymentBillingDate(p) || p.created_at.slice(0, 10),
      payment_method: p.payment_method,
      transaction_id: p.transaction_id ?? null,
      flat_number: p.flat_number,
      label: `Flat ${p.flat_number} — ${p.charge_title ?? 'Maintenance'} — ₹${Number(p.amount).toLocaleString('en-IN')}`,
    });
  }

  for (const e of ledgerEntries) {
    if (e.payment_status !== 'verified') continue;
    if (normalizePaymentChannel(e.payment_method) !== 'bank') continue;
    if (alreadyMatchedEntryIds.has(e.id)) continue;
    const isExpense = e.destination === 'separate_entry';
    targets.push({
      kind: 'finance_entry',
      id: e.id,
      amount: isExpense ? -Math.abs(Number(e.total_amount)) : Number(e.total_amount),
      date: ledgerTransactionDate(e),
      payment_method: e.payment_method,
      transaction_id: e.transaction_id ?? null,
      title: e.title ?? null,
      destination: e.destination,
      label: `${isExpense ? 'Expense' : 'Receipt'} — ${e.title ?? 'Ledger'} — ₹${Number(e.total_amount).toLocaleString('en-IN')}`,
    });
  }

  return targets;
}

export function targetKey(target: ReconcilableTarget): string {
  return `${target.kind}:${target.id}`;
}

export function suggestionFromTarget(
  line: StatementLineForMatch,
  target: ReconcilableTarget,
  dateToleranceDays = BANK_RECON_DATE_TOLERANCE_DAYS,
): SuggestedMatch {
  const { confidence, reasons } = computeMatchConfidence(line, target, dateToleranceDays);
  return {
    statement_line_id: line.id,
    match_type: target.kind === 'maintenance_payment' ? 'maintenance_payment' : 'finance_entry',
    maintenance_payment_id: target.kind === 'maintenance_payment' ? target.id : undefined,
    finance_entry_id: target.kind === 'finance_entry' ? target.id : undefined,
    match_confidence: confidence,
    target,
    reasons,
  };
}

/** Candidates for manual linking, sorted by confidence (includes amount mismatches at 0). */
export function rankCandidatesForLine(
  line: StatementLineForMatch,
  targets: ReconcilableTarget[],
  usedTargetKeys: Set<string> = new Set(),
  limit = 10,
  dateToleranceDays = BANK_RECON_DATE_TOLERANCE_DAYS,
): SuggestedMatch[] {
  const ranked = targets
    .filter((t) => !usedTargetKeys.has(targetKey(t)))
    .map((t) => suggestionFromTarget(line, t, dateToleranceDays))
    .filter((s) => s.match_confidence > 0)
    .sort((a, b) => b.match_confidence - a.match_confidence);
  return ranked.slice(0, limit);
}

export function filterTargetsToPeriod(
  targets: ReconcilableTarget[],
  periodFrom: string,
  periodTo: string,
  toleranceDays = BANK_RECON_DATE_TOLERANCE_DAYS,
): ReconcilableTarget[] {
  const from = parse(periodFrom.slice(0, 10), 'yyyy-MM-dd', new Date());
  const to = parse(periodTo.slice(0, 10), 'yyyy-MM-dd', new Date());
  if (!isValid(from) || !isValid(to)) return targets;
  const minMs = from.getTime() - toleranceDays * 86400000;
  const maxMs = to.getTime() + toleranceDays * 86400000;
  return targets.filter((t) => {
    const d = parse(t.date.slice(0, 10), 'yyyy-MM-dd', new Date());
    if (!isValid(d)) return true;
    const ms = d.getTime();
    return ms >= minMs && ms <= maxMs;
  });
}

export function suggestMatches(
  lines: StatementLineForMatch[],
  targets: ReconcilableTarget[],
  dateToleranceDays = BANK_RECON_DATE_TOLERANCE_DAYS,
): SuggestedMatch[] {
  const suggestions: SuggestedMatch[] = [];
  const usedTargetIds = new Set<string>();

  for (const line of lines) {
    let best: SuggestedMatch | null = null;

    for (const target of targets) {
      if (usedTargetIds.has(targetKey(target))) continue;
      const { confidence, reasons } = computeMatchConfidence(line, target, dateToleranceDays);
      if (confidence <= 0) continue;
      if (!best || confidence > best.match_confidence) {
        best = {
          statement_line_id: line.id,
          match_type: target.kind === 'maintenance_payment' ? 'maintenance_payment' : 'finance_entry',
          maintenance_payment_id: target.kind === 'maintenance_payment' ? target.id : undefined,
          finance_entry_id: target.kind === 'finance_entry' ? target.id : undefined,
          match_confidence: confidence,
          target,
          reasons,
        };
      }
    }

    if (best) {
      suggestions.push(best);
      usedTargetIds.add(targetKey(best.target));
    }
  }

  return suggestions.sort((a, b) => b.match_confidence - a.match_confidence);
}

export type ReconciliationSummary = {
  statementCredits: number;
  statementDebits: number;
  matchedCredits: number;
  matchedDebits: number;
  unmatchedCredits: number;
  unmatchedDebits: number;
  lineCount: number;
  matchedCount: number;
  suggestedCount: number;
  exceptionCount: number;
};

export function computeReconciliationSummary(
  lines: { id: string; amount: number }[],
  matchesByLineId: Map<string, { status: string }>,
): ReconciliationSummary {
  let statementCredits = 0;
  let statementDebits = 0;
  let matchedCredits = 0;
  let matchedDebits = 0;
  let matchedCount = 0;
  let suggestedCount = 0;

  for (const line of lines) {
    const amt = Number(line.amount);
    if (amt > 0) statementCredits += amt;
    else statementDebits += Math.abs(amt);

    const match = matchesByLineId.get(line.id);
    if (!match) continue;
    if (match.status === 'confirmed' || match.status === 'manual') {
      matchedCount++;
      if (amt > 0) matchedCredits += amt;
      else matchedDebits += Math.abs(amt);
    } else if (match.status === 'suggested') {
      suggestedCount++;
    }
  }

  const exceptionCount = lines.length - matchedCount;
  return {
    statementCredits,
    statementDebits,
    matchedCredits,
    matchedDebits,
    unmatchedCredits: statementCredits - matchedCredits,
    unmatchedDebits: statementDebits - matchedDebits,
    lineCount: lines.length,
    matchedCount,
    suggestedCount,
    exceptionCount,
  };
}
