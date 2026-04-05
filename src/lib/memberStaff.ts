import type { Member, Visitor } from '@/types';

/** Lowercase service types when a resident picks a fixed role (not "Others", which overlaps with family). */
const KNOWN_SERVICE_TYPE_LC = ['cook', 'maid', 'washerman', 'newspaper', 'driver'] as const;

/** Family / household relations (resident + admin member forms). Staff should not use these. */
const FAMILY_RELATION_LC = new Set([
  'owner',
  'spouse',
  'son',
  'daughter',
  'father',
  'mother',
  'brother',
  'sister',
  'tenant',
  'family',
  'other',
  'others', // family "Others" and undifferentiated; staff should use a custom type label instead
]);

/**
 * Members shown on Guard Quick Entry: servicemen registered on a flat (by resident or admin).
 * Primary owners are excluded. Matches known service types or a custom service label (e.g. plumber).
 */
export function isQuickEntryStaffMember(m: Member): boolean {
  if (m.isPrimary) return false;
  const r = (m.relation || '').toLowerCase();
  if (!r) return false;
  if (KNOWN_SERVICE_TYPE_LC.includes(r as (typeof KNOWN_SERVICE_TYPE_LC)[number])) return true;
  return !FAMILY_RELATION_LC.has(r);
}

/** Stable synthetic phone when staff has no mobile (visitors.phone is NOT NULL in DB). */
export function staffMemberSyntheticPhone(memberId: string): string {
  const compact = memberId.replace(/-/g, '');
  return `staff-${compact.slice(0, 16)}`;
}

export function quickEntryPhoneForMember(m: Member): string {
  const digits = (m.phone || '').replace(/\D/g, '');
  if (digits.length >= 10) return digits.slice(-10);
  return staffMemberSyntheticPhone(m.id);
}

export function memberToQuickVisitorTemplate(m: Member, flatNumber: string): Visitor {
  const phone = quickEntryPhoneForMember(m);
  const rel = (m.relation || 'staff').replace(/\b\w/g, c => c.toUpperCase());
  return {
    id: `member-${m.id}`,
    name: m.name,
    phone,
    documentType: 'other',
    documentNumber: '',
    visitorPhotos: m.photo ? [m.photo] : [],
    flatNumber,
    purpose: `${rel} · Registered staff`,
    entryTime: '',
    guardId: '',
    guardName: '',
    category: 'service',
  };
}
