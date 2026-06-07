/** Normalise expense-head names for fuzzy matching (Water Softner / Softener / Installation). */
export function normalizeHeadToken(s: string): string {
  return (s || '')
    .toLowerCase()
    .replace(/softener/g, 'softner')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function headNamesMatch(a: string, b: string): boolean {
  const na = normalizeHeadToken(a);
  const nb = normalizeHeadToken(b);
  if (!na || !nb) return false;
  if (na === nb) return true;
  if (na.includes(nb) || nb.includes(na)) return true;
  const wa = na.split(/\s+/).filter((w) => w.length > 2);
  const wb = nb.split(/\s+/).filter((w) => w.length > 2);
  return wa.some((w) => wb.includes(w));
}

export function expenseMatchesHead(
  headName: string,
  expense: { title?: string | null; vendor_or_service?: string | null; group_name?: string | null },
): boolean {
  const blob = [expense.title, expense.vendor_or_service, expense.group_name].filter(Boolean).join(' ');
  return headNamesMatch(headName, blob);
}

export function isHeadContributionLedgerTitle(title?: string | null): boolean {
  return /^head contribution\s*[—–-]/i.test((title ?? '').trim());
}

export function isHeadAdjustmentLedgerTitle(title?: string | null): boolean {
  return /^head adjustment\s*[—–-]/i.test((title ?? '').trim());
}

export const HEAD_ADJUSTMENT_SOURCE_LABELS: Record<
  'member_advance' | 'maintenance_pool' | 'corpus',
  string
> = {
  member_advance: 'Member advance / top-up',
  maintenance_pool: 'Society maintenance collections',
  corpus: 'Corpus fund',
};
