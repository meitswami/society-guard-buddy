/** Family / household relations shown in resident + admin member forms. */
export const HOUSEHOLD_RELATION_TYPES = [
  'Owner',
  'Spouse',
  'Son',
  'Daughter',
  'Father',
  'Mother',
  'Brother',
  'Sister',
  'Tenant',
  'Others',
] as const;

/**
 * Flat-registered staff / mid-servants / domestic help.
 * Photos collected in the member portal auto-fill elections & committee when linked.
 */
export const HOUSEHOLD_SERVICE_TYPES = [
  'Cook',
  'Maid',
  'Washerman',
  'Newspaper',
  'Driver',
  'Guard',
  'Cleaner',
  'Sweeper',
  'Housekeeper',
  'Mid-servant',
  'Others',
] as const;

export type HouseholdServiceType = (typeof HOUSEHOLD_SERVICE_TYPES)[number];

export const HOUSEHOLD_SERVICE_TYPE_LC = HOUSEHOLD_SERVICE_TYPES.map((s) => s.toLowerCase());

export function isKnownHouseholdServiceType(relation: string | null | undefined): boolean {
  const r = (relation || '').trim().toLowerCase();
  return HOUSEHOLD_SERVICE_TYPE_LC.includes(r);
}
