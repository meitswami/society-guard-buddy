import type { SupabaseClient } from '@supabase/supabase-js';
import { floorLabelFromFlatNumber } from '@/lib/flatFloor';
import { canTrimFlatsFromSocietyRow, type SocietyFlatRangeInput } from '@/lib/societyFlatRangeTrim';

export type GenerateFlatsResult = {
  created: number;
  skipped: number;
  error?: string;
};

function wingKey(wing: string | null): string {
  return (wing ?? '').trim().toUpperCase();
}

/**
 * Inserts missing `flats` rows from society layout (same numbering model as trim: 101–105, 201–205, …).
 * For each block/wing in `block_names`, generates the full set; single tower uses `wing` null.
 * Idempotent: skips flat_number+wing pairs that already exist for the society.
 */
export async function upsertSocietyFlatsFromLayout(
  supabase: SupabaseClient,
  societyId: string,
  row: SocietyFlatRangeInput,
): Promise<GenerateFlatsResult> {
  if (!societyId) return { created: 0, skipped: 0, error: 'Missing society id' };

  const range = canTrimFlatsFromSocietyRow(row);
  if (!range) {
    return {
      created: 0,
      skipped: 0,
      error: 'Invalid flat layout (need total floors ≥ 1 and a valid flat series on one hundred-band, e.g. 101–111).',
    };
  }

  const wings =
    row.block_names?.length ?
      row.block_names.map((w) => w.trim().toUpperCase()).filter(Boolean)
    : [null as string | null];

  const sortedNumbers = [...range.valid].sort((a, b) => parseInt(a, 10) - parseInt(b, 10));

  const { data: existing, error: exErr } = await supabase
    .from('flats')
    .select('flat_number, wing')
    .eq('society_id', societyId);

  if (exErr) {
    console.error('upsertSocietyFlatsFromLayout existing', exErr);
    return { created: 0, skipped: 0, error: exErr.message };
  }

  // Guard against accidental double-generation when switching between single-tower
  // mode (no wing) and multi-wing mode (A/B/...) without cleaning old rows first.
  const hasExistingWinged = (existing ?? []).some((r) => wingKey(r.wing).length > 0);
  const hasExistingUnwinged = (existing ?? []).some((r) => wingKey(r.wing).length === 0);
  const wantsWinged = wings.some((w) => wingKey(w).length > 0);
  const wantsUnwinged = wings.some((w) => wingKey(w).length === 0);
  if ((hasExistingWinged && wantsUnwinged) || (hasExistingUnwinged && wantsWinged)) {
    return {
      created: 0,
      skipped: 0,
      error:
        'Flat generation halted to avoid duplicates: existing flats use a different wing mode (single tower vs A/B wings). Clean old rows for this society first, then save again.',
    };
  }

  const taken = new Set<string>();
  for (const r of existing ?? []) {
    taken.add(`${String(r.flat_number).trim()}|${wingKey(r.wing)}`);
  }

  const rows: {
    society_id: string;
    flat_number: string;
    wing: string | null;
    floor: string | null;
    flat_type: string;
    is_occupied: boolean;
  }[] = [];

  let skipped = 0;
  for (const wing of wings) {
    const wStored = wingKey(wing || null) || null;
    for (const num of sortedNumbers) {
      const key = `${num}|${wStored ?? ''}`;
      if (taken.has(key)) {
        skipped++;
        continue;
      }
      taken.add(key);
      const floor = floorLabelFromFlatNumber(num);
      rows.push({
        society_id: societyId,
        flat_number: num,
        wing: wStored,
        floor,
        flat_type: 'residential',
        is_occupied: false,
      });
    }
  }

  if (!rows.length) {
    return { created: 0, skipped };
  }

  const chunk = 250;
  let created = 0;
  for (let i = 0; i < rows.length; i += chunk) {
    const part = rows.slice(i, i + chunk);
    const { error } = await supabase.from('flats').insert(part);
    if (error) {
      console.error('upsertSocietyFlatsFromLayout insert', error);
      return { created, skipped, error: error.message };
    }
    created += part.length;
  }

  return { created, skipped };
}
