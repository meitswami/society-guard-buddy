/** Equal per-flat amounts that always sum exactly to `total` (remainder on last row). */
export function computeEqualSplitAmounts(
  total: number,
  flatNumbers: string[],
): { flat_number: string; amount: number }[] {
  if (flatNumbers.length === 0) return [];
  const share = Number((total / flatNumbers.length).toFixed(2));
  let allocated = 0;
  return flatNumbers.map((flat_number, i) => {
    const isLast = i === flatNumbers.length - 1;
    const amount = isLast ? Number((total - allocated).toFixed(2)) : share;
    allocated += amount;
    return { flat_number, amount };
  });
}

/** Nudge the last split so row amounts sum to `total` (handles rounding drift). */
export function adjustSplitRemainder(total: number, amounts: number[]): number[] {
  if (amounts.length === 0) return [];
  const sum = Number(amounts.reduce((a, b) => a + b, 0).toFixed(2));
  const diff = Number((total - sum).toFixed(2));
  if (Math.abs(diff) < 0.005) return amounts;
  const out = [...amounts];
  out[out.length - 1] = Number((out[out.length - 1] + diff).toFixed(2));
  return out;
}
