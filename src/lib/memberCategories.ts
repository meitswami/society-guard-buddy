/**
 * Household relations that may use resident app login (phone + shared flat password) and may be primary.
 * Tenant, other(s), and staff/service roles are excluded.
 */
const HOUSEHOLD_LOGIN_RELATIONS = new Set([
  'owner',
  'spouse',
  'son',
  'daughter',
  'father',
  'mother',
  'family',
  'brother',
  'sister',
]);

export function normalizeMemberRelation(relation: string | null | undefined): string {
  return (relation ?? '').trim().toLowerCase();
}

/** True if this relation may have a resident_users login and can be primary member. */
export function allowsResidentLoginAndPrimary(relation: string | null | undefined): boolean {
  return HOUSEHOLD_LOGIN_RELATIONS.has(normalizeMemberRelation(relation));
}

/** Inverse: tenant, other(s), staff (cook, maid, …), or any custom serviceman label. */
export function isRestrictedMemberCategory(relation: string | null | undefined): boolean {
  return !allowsResidentLoginAndPrimary(relation);
}

export const STAFF_VEHICLE_TYPES = ['car', 'cycle', 'bike', 'activa', 'auto', 'other'] as const;
