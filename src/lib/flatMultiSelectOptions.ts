import type { FlatMultiSelectOption } from '@/components/FlatMultiSelect';

export type FlatRowForOptions = { id: string; flat_number: string; owner_name?: string | null };

/** Numeric flat order (101, 102, … 605) — not lexicographic string order. */
export function compareFlatNumbers(a: string, b: string): number {
  return a.localeCompare(b, undefined, { numeric: true });
}

export function sortFlatsByNumber<T extends { flat_number: string }>(flats: T[]): T[] {
  return [...flats].sort((a, b) => compareFlatNumbers(a.flat_number, b.flat_number));
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
