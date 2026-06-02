export type FlatMemberRow = {
  id?: string;
  flat_id: string | null;
  name?: string | null;
  age?: number | null;
  relation?: string | null;
};

export type FlatHeadcount = {
  flat_number: string;
  adults: number;
  kids: number;
  units: number;
};

const CHILD_RELATION_HINTS = ['son', 'daughter', 'child', 'kid', 'minor', 'grandson', 'granddaughter'];

function isChildMember(m: FlatMemberRow): boolean {
  const age = m.age;
  if (age != null && !Number.isNaN(age) && age > 0) return age < 18;
  const rel = String(m.relation ?? '')
    .trim()
    .toLowerCase();
  if (!rel) return false;
  return CHILD_RELATION_HINTS.some((hint) => rel === hint || rel.includes(hint));
}

/** Per-flat adults, kids, and weighted units for event/function cost sharing. */
export function headcountForFlat(
  flatNumber: string,
  flatId: string | null,
  members: FlatMemberRow[],
  adultWeight: number,
  childWeight: number,
): FlatHeadcount {
  const flatMembers = members.filter((m) => {
    if (flatId && m.flat_id === flatId) return true;
    return false;
  });

  if (flatMembers.length === 0) {
    return { flat_number: flatNumber, adults: 1, kids: 0, units: adultWeight };
  }

  let adults = 0;
  let kids = 0;
  for (const m of flatMembers) {
    if (isChildMember(m)) kids += 1;
    else adults += 1;
  }
  if (adults === 0 && kids === 0) adults = 1;

  const units = adults * adultWeight + kids * childWeight;
  return { flat_number: flatNumber, adults, kids, units };
}

export function computeHeadcountAmounts(
  total: number,
  rows: FlatHeadcount[],
): { flat_number: string; amount: number; adults: number; kids: number }[] {
  const unitSum = rows.reduce((s, r) => s + r.units, 0);
  if (unitSum <= 0) return [];

  let allocated = 0;
  const out: { flat_number: string; amount: number; adults: number; kids: number }[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const isLast = i === rows.length - 1;
    const amount = isLast
      ? Number((total - allocated).toFixed(2))
      : Number(((total * row.units) / unitSum).toFixed(2));
    allocated += amount;
    out.push({ flat_number: row.flat_number, amount, adults: row.adults, kids: row.kids });
  }
  return out;
}
