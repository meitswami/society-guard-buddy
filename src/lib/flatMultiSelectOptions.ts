import type { FlatMultiSelectOption } from '@/components/FlatMultiSelect';

export type FlatRowForOptions = { id: string; flat_number: string; owner_name?: string | null };

/** Build options with a second-line label: primary member name, else flat owner_name. */
export function flatOptionsWithPrimaryLabel(
  flats: FlatRowForOptions[],
  primaryNameByFlatId: Map<string, string>,
): FlatMultiSelectOption[] {
  return flats.map((f) => {
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
