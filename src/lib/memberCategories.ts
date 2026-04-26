/**
 * Household relations that may use resident app login (phone + shared flat password).
 * Staff/service roles are excluded.
 *
 * Note: Tenants may login, but cannot be "primary" member (owner/household primary).
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
  'tenant',
]);

export function normalizeMemberRelation(relation: string | null | undefined): string {
  return (relation ?? '').trim().toLowerCase();
}

/** True if this relation may have a resident_users login. */
export function allowsResidentLogin(relation: string | null | undefined): boolean {
  return HOUSEHOLD_LOGIN_RELATIONS.has(normalizeMemberRelation(relation));
}

/** True if this relation may be the flat's primary member (owner household). */
export function allowsPrimaryMember(relation: string | null | undefined): boolean {
  const r = normalizeMemberRelation(relation);
  return r !== 'tenant' && allowsResidentLogin(r);
}

/** Inverse: other(s), staff (cook, maid, …), or any custom serviceman label. */
export function isRestrictedMemberCategory(relation: string | null | undefined): boolean {
  return !allowsResidentLogin(relation);
}

export const STAFF_VEHICLE_TYPES = ['car', 'cycle', 'bike', 'activa', 'auto', 'other'] as const;
