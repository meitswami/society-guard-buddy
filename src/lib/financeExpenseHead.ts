/** Chart-of-accounts major heads for Finance → Record payment. */
export const SOCIETY_PAYMENT_MAJOR_HEADS = [
  'SALARY & WAGES',
  'OPERATION & MAINTENANCE',
  'FIXED ASSETS',
  'LEGAL & PROFESSIONAL FEES',
  'SOCIETY CORPUS FUND',
  'CORPUS FUND (LEGAL)',
  'FIXED DEPOSIT',
  'BANK',
  'CASH',
  'MISCELLANEOUS',
] as const;

export type SocietyPaymentMajorHead = (typeof SOCIETY_PAYMENT_MAJOR_HEADS)[number];

/** @deprecated Use SOCIETY_PAYMENT_MAJOR_HEADS + sub-head group names instead. */
export const SOCIETY_PAYMENT_EXPENSE_HEADS = SOCIETY_PAYMENT_MAJOR_HEADS;

const GENERIC_EVENT_GROUP =
  /^(other\s+)?events?\s*(and|&|\/)\s*functions?|events?\s*&\s*functions?|event\s*\/\s*function|general\s+events?$/i;

function joinNoteLines(parts: (string | null | undefined)[]): string | null {
  const lines = parts.map((p) => p?.trim()).filter(Boolean) as string[];
  return lines.length ? lines.join('\n') : null;
}

/** Guess major head from an existing sub-head / group name (legacy rows). */
export function inferMajorHeadFromGroupName(name: string): SocietyPaymentMajorHead {
  const n = (name || '').trim().toLowerCase();
  if (!n) return 'MISCELLANEOUS';
  if (/corpus.*legal|legal.*corpus/.test(n)) return 'CORPUS FUND (LEGAL)';
  if (/corpus|society fund/.test(n)) return 'SOCIETY CORPUS FUND';
  if (/fixed deposit|\bfd\b/.test(n)) return 'FIXED DEPOSIT';
  if (/^bank\b|bank account/.test(n)) return 'BANK';
  if (/^cash\b|petty cash/.test(n)) return 'CASH';
  if (/legal|professional|audit|advocate|lawyer/.test(n)) return 'LEGAL & PROFESSIONAL FEES';
  if (/fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset/.test(n)) return 'FIXED ASSETS';
  if (/salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor/.test(n)) {
    return 'SALARY & WAGES';
  }
  if (/electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility/.test(n)) {
    return 'OPERATION & MAINTENANCE';
  }
  return 'MISCELLANEOUS';
}

export function resolveGroupMajorHead(group: { name: string; major_head?: string | null }): SocietyPaymentMajorHead {
  const stored = group.major_head?.trim();
  if (stored && (SOCIETY_PAYMENT_MAJOR_HEADS as readonly string[]).includes(stored)) {
    return stored as SocietyPaymentMajorHead;
  }
  return inferMajorHeadFromGroupName(group.name);
}

export function groupMatchesPaymentHeadSearch(
  group: { name: string; description?: string | null; major_head?: string | null },
  query: string,
): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  const major = resolveGroupMajorHead(group);
  return (
    group.name.toLowerCase().includes(q) ||
    major.toLowerCase().includes(q) ||
    (group.description ?? '').toLowerCase().includes(q)
  );
}

export function paymentGroupsByMajorHead<T extends { name: string; major_head?: string | null }>(
  groups: T[],
): Map<SocietyPaymentMajorHead, T[]> {
  const map = new Map<SocietyPaymentMajorHead, T[]>();
  for (const head of SOCIETY_PAYMENT_MAJOR_HEADS) map.set(head, []);
  for (const g of groups) {
    const major = resolveGroupMajorHead(g);
    map.get(major)!.push(g);
  }
  for (const head of SOCIETY_PAYMENT_MAJOR_HEADS) {
    map.get(head)!.sort((a, b) => a.name.localeCompare(b.name));
  }
  return map;
}

/** Ledger title + extra note lines for group-linked expenses. */
export function buildGroupExpenseLedgerTitle(opts: {
  expenseCategory: 'food' | 'payment';
  groupName: string;
  expenseTitle: string;
  eventTitle?: string | null;
}): { ledgerTitle: string; detailNote: string | null } {
  const group = opts.groupName.trim();
  const line = opts.expenseTitle.trim();

  if (opts.expenseCategory === 'food') {
    const eventLabel = opts.eventTitle?.trim();
    const ledgerTitle = eventLabel
      ? `Event food — ${eventLabel}`
      : group
        ? `Event food — ${group}`
        : 'Event food';
    const detailNote =
      line && line !== eventLabel && line !== group ? `Item: ${line}` : line ? `Item: ${line}` : null;
    return { ledgerTitle, detailNote };
  }

  const head = group || line || 'Society payment';
  const detailNote =
    line && line.toLowerCase() !== head.toLowerCase() ? `Detail: ${line}` : null;
  return { ledgerTitle: head, detailNote };
}

/**
 * Head for period report / totals — not the raw ledger title.
 * Legacy rows used `[Group] line`; generic event groups map to the line item head.
 */
export function financeExpenseHeadFromLedgerTitle(rawTitle: string): string {
  const t = (rawTitle || '').trim() || 'Society expense';

  if (/^event food\s*[—–-]/i.test(t)) return t;

  const bracket = /^\[([^\]]+)\]\s*(.*)$/.exec(t);
  if (bracket) {
    const group = bracket[1].trim();
    const rest = bracket[2].trim();
    if (GENERIC_EVENT_GROUP.test(group)) return rest || group;
    if (rest) return group;
    return group;
  }

  return t;
}

export function financeExpenseHeadFromLedgerEntry(
  rawTitle: string,
  expenseCategory?: string | null,
): string {
  if (expenseCategory === 'food') {
    const parsed = financeExpenseHeadFromLedgerTitle(rawTitle);
    if (/^event food\s*[—–-]/i.test(parsed)) return parsed;
    const stripped = parsed.replace(/^\[[^\]]+\]\s*/, '').trim();
    return stripped ? `Event food — ${stripped}` : 'Event food';
  }
  return financeExpenseHeadFromLedgerTitle(rawTitle);
}

/** Event / catering bills — reconciled in Events & food, not Finance → Transactions. */
export function isEventFoodExpenseCategory(category?: string | null): boolean {
  return category === 'food';
}

export function isEventFoodLedgerTitle(title?: string | null): boolean {
  return /^event food\s*[—–-]/i.test((title ?? '').trim());
}

export function isEventFoodLedgerEntry(
  entry: { expense_id?: string | null; title?: string | null },
  expenseCategoryById: Map<string, string>,
): boolean {
  if (entry.expense_id) {
    return isEventFoodExpenseCategory(expenseCategoryById.get(entry.expense_id));
  }
  return isEventFoodLedgerTitle(entry.title);
}

export { joinNoteLines };
