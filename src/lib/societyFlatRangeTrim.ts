import type { SupabaseClient } from '@supabase/supabase-js';

/** Society row fields used to derive expected numeric flat numbers (101–105, 201–205, …). */
export type SocietyFlatRangeInput = {
  total_floors: number | null;
  flat_series_start: string | null;
  flat_series_end: string | null;
  block_names: string[] | null;
};

export type BuiltFlatRange = {
  valid: Set<string>;
  floorBase: number;
  floors: number;
  uStart: number;
  nUnits: number;
  maxTrimUnit: number;
};

/**
 * Builds the set of valid flat numbers (e.g. 101–105 on tier 1, 201–205 on tier 2, …).
 * Assumes each residential tier advances by +100 (common in Indian numbering).
 */
export function buildValidFlatNumberSet(input: {
  total_floors: number;
  flat_series_start: string;
  flat_series_end: string;
}): BuiltFlatRange | null {
  const start = parseInt(String(input.flat_series_start).trim(), 10);
  const end = parseInt(String(input.flat_series_end).trim(), 10);
  const floors = input.total_floors;
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start || !floors || floors < 1) {
    return null;
  }

  const floorBase = Math.floor(start / 100);
  const endFloorBase = Math.floor(end / 100);
  if (endFloorBase !== floorBase) {
    return null;
  }

  const uStart = start - floorBase * 100;
  const nUnits = end - start + 1;
  if (nUnits < 1) return null;

  const valid = new Set<string>();
  for (let i = 0; i < floors; i++) {
    const prefix = floorBase + i;
    for (let j = 0; j < nUnits; j++) {
      valid.add(String(prefix * 100 + uStart + j));
    }
  }

  const maxTrimUnit = uStart + nUnits + 3;
  return { valid, floorBase, floors, uStart, nUnits, maxTrimUnit };
}

function wingAllowedForTrim(wing: string | null | undefined, block_names: string[] | null): boolean {
  if (!block_names?.length) return true;
  const set = new Set(block_names.map((b) => b.trim().toLowerCase()).filter(Boolean));
  const w = (wing ?? '').trim().toLowerCase();
  if (w && set.has(w)) return true;
  if (!w && set.size === 1) return true;
  return false;
}

function isResidentialFlatType(flat_type: string | null | undefined): boolean {
  return (flat_type ?? 'residential') === 'residential';
}

/**
 * True if this flat row should be removed: on a configured tier, unit looks like a mistaken
 * extra in the same band (e.g. 106 when range is 101–105), but not odd numbers like shop 150.
 */
export function flatRowShouldTrim(
  flat: { flat_number: string; wing: string | null; flat_type: string | null },
  range: BuiltFlatRange,
  block_names: string[] | null,
): boolean {
  if (!isResidentialFlatType(flat.flat_type)) return false;
  if (!wingAllowedForTrim(flat.wing, block_names)) return false;

  const raw = flat.flat_number.trim();
  if (!/^\d+$/.test(raw)) return false;

  const n = parseInt(raw, 10);
  if (!Number.isFinite(n)) return false;

  if (range.valid.has(String(n))) return false;

  const floorPrefix = Math.floor(n / 100);
  if (floorPrefix < range.floorBase || floorPrefix > range.floorBase + range.floors - 1) {
    return false;
  }

  const unit = n - floorPrefix * 100;
  if (unit < range.uStart || unit > range.maxTrimUnit) return false;

  return true;
}

export function canTrimFlatsFromSocietyRow(row: SocietyFlatRangeInput): BuiltFlatRange | null {
  if (row.total_floors == null || row.total_floors < 1) return null;
  if (!row.flat_series_start?.trim() || !row.flat_series_end?.trim()) return null;
  return buildValidFlatNumberSet({
    total_floors: row.total_floors,
    flat_series_start: row.flat_series_start,
    flat_series_end: row.flat_series_end,
  });
}

/**
 * Deletes residential flats for the society that fall outside the configured numeric range
 * (same tier pattern as 101–105 / 201–205). Keeps non-numeric flat numbers, other wings when
 * ambiguous, non-residential types, and numbers outside the “nearby unit” band (e.g. 150).
 * Members on removed flats are removed via ON DELETE CASCADE.
 */
export async function trimSocietyFlatsToConfiguredRange(
  supabase: SupabaseClient,
  societyId: string,
  row: SocietyFlatRangeInput,
): Promise<number> {
  const range = canTrimFlatsFromSocietyRow(row);
  if (!range) return 0;

  const { data: flats, error } = await supabase
    .from('flats')
    .select('id, flat_number, wing, flat_type')
    .eq('society_id', societyId);

  if (error || !flats?.length) return 0;

  const ids: string[] = [];
  for (const f of flats) {
    if (flatRowShouldTrim(f, range, row.block_names)) ids.push(f.id);
  }
  if (!ids.length) return 0;

  const chunk = 200;
  for (let i = 0; i < ids.length; i += chunk) {
    const part = ids.slice(i, i + chunk);
    const { error: delErr } = await supabase.from('flats').delete().in('id', part);
    if (delErr) {
      console.error('trimSocietyFlatsToConfiguredRange delete', delErr);
      return 0;
    }
  }

  return ids.length;
}
