/** Society payment heads (Finance → Record payment). One group per head is recommended. */
export const SOCIETY_PAYMENT_EXPENSE_HEADS = [
  'Electricity',
  'Water',
  'Lift / AMC',
  'Security',
  'Housekeeping',
  'Repairs & maintenance',
  'Garden / landscaping',
  'Insurance',
  'Salaries / wages',
  'Legal / professional',
  'Stationery / office',
  'Miscellaneous',
] as const;

const GENERIC_EVENT_GROUP =
  /^(other\s+)?events?\s*(and|&|\/)\s*functions?|events?\s*&\s*functions?|event\s*\/\s*function|general\s+events?$/i;

function joinNoteLines(parts: (string | null | undefined)[]): string | null {
  const lines = parts.map((p) => p?.trim()).filter(Boolean) as string[];
  return lines.length ? lines.join('\n') : null;
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

export { joinNoteLines };
