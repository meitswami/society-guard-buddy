import type { FlatMultiSelectOption } from '@/components/FlatMultiSelect';

export type FlatRowForOptions = { id: string; flat_number: string; owner_name?: string | null };

/** Numeric flat order (101, 102, … 605) — not lexicographic string order. */
export function compareFlatNumbers(a: string, b: string): number {
  return a.localeCompare(b, undefined, { numeric: true });
}

export function sortFlatsByNumber<T extends { flat_number: string }>(flats: T[]): T[] {
  return [...flats].sort((a, b) => compareFlatNumbers(a.flat_number, b.flat_number));
}

/** Lowest flat number on a ledger allocation list (for sort keys). */
export function primaryFlatFromAllocations(
  allocations: { flat_number: string }[] | null | undefined,
): string {
  if (!allocations?.length) return '';
  return sortFlatsByNumber(allocations)[0]!.flat_number;
}

/**
 * Numeric flat order when both rows have a flat; otherwise chronological.
 * Avoids pushing non-flat ledger rows into a separate block at the end.
 */
export function compareByFlatThenDate(
  flatA: string,
  flatB: string,
  dateA: string,
  dateB: string,
): number {
  if (flatA && flatB) {
    const byFlat = compareFlatNumbers(flatA, flatB);
    if (byFlat !== 0) return byFlat;
  }
  const byDate = dateA.localeCompare(dateB);
  if (byDate !== 0) return byDate;
  return compareFlatNumbers(flatA, flatB);
}

/** Build options with a second-line label: primary member name, else flat owner_name. */
export function flatOptionsWithPrimaryLabel(
  flats: FlatRowForOptions[],
  primaryNameByFlatId: Map<string, string>,
): FlatMultiSelectOption[] {
  return sortFlatsByNumber(flats).map((f) => {
    const primary = primaryNameByFlatId.get(f.id)?.trim();
    const owner = f.owner_name?.trim();
    const subtitle = primary || owner || undefined;
    return { id: f.id, flat_number: f.flat_number, subtitle };
  });
}

/** Label stored on payment rows: one value per flat, no shared multi-select field. */
export function residentLabelForFlatRow(
  flatId: string | undefined,
  ownerName: string | null | undefined,
  primaryNameByFlatId: Map<string, string>,
): string | null {
  if (flatId) {
    const p = primaryNameByFlatId.get(flatId)?.trim();
    if (p) return p;
  }
  const o = ownerName?.trim();
  return o || null;
}
