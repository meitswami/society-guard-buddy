/**
 * Maps 3-digit flat numbers like 101–199 → 1st Floor, … 601–699 → 6th Floor
 * (first digit = floor index). Returns null if the pattern does not apply.
 */
export function floorLabelFromFlatNumber(flatNumber: string): string | null {
  const raw = flatNumber.trim();
  if (!raw) return null;
  const digits = raw.replace(/\D/g, '');
  if (!/^[1-6]\d{2}$/.test(digits)) return null;
  const n = parseInt(digits[0]!, 10);
  const labels: Record<number, string> = {
    1: '1st Floor',
    2: '2nd Floor',
    3: '3rd Floor',
    4: '4th Floor',
    5: '5th Floor',
    6: '6th Floor',
  };
  return labels[n] ?? null;
}
