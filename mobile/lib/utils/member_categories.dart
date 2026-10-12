/// Member relation rules — port of web `src/lib/memberCategories.ts`,
/// `src/lib/householdRoles.ts` and `src/lib/memberStaff.ts`.
///
/// Household relations may use the resident app login (phone + shared flat password).
/// Staff/service roles are excluded. Tenants may log in but cannot be the primary member.
library;

const _householdLoginRelations = {
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
};

String normalizeMemberRelation(String? relation) => (relation ?? '').trim().toLowerCase();

/// True if this relation may have a `resident_users` login.
bool allowsResidentLogin(String? relation) => _householdLoginRelations.contains(normalizeMemberRelation(relation));

/// True if this relation may be the flat's primary member (owner household).
bool allowsPrimaryMember(String? relation) {
  final r = normalizeMemberRelation(relation);
  return r != 'tenant' && allowsResidentLogin(r);
}

/// Inverse: other(s), staff (cook, maid, …), or any custom serviceman label.
bool isRestrictedMemberCategory(String? relation) => !allowsResidentLogin(relation);

/// True for the `tenant` relation.
bool isTenantRelation(String? relation) => normalizeMemberRelation(relation) == 'tenant';

/// Web `STAFF_VEHICLE_TYPES`.
const kStaffVehicleTypes = ['car', 'cycle', 'bike', 'activa', 'auto', 'other'];

/// Web `HOUSEHOLD_RELATION_TYPES` (resident + admin member forms).
const kHouseholdRelationTypes = [
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
];

/// Web `HOUSEHOLD_SERVICE_TYPES` — flat-registered staff / mid-servants / domestic help.
const kHouseholdServiceTypes = [
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
];

final List<String> kHouseholdServiceTypesLc = kHouseholdServiceTypes.map((s) => s.toLowerCase()).toList();

/// Web `isKnownHouseholdServiceType`.
bool isKnownHouseholdServiceType(String? relation) =>
    kHouseholdServiceTypesLc.contains((relation ?? '').trim().toLowerCase());

/// Relation options of the admin member form (`<optgroup label="Household">`).
const kAdminHouseholdRelations = ['owner', 'spouse', 'son', 'daughter', 'father', 'mother', 'family', 'tenant', 'other'];

/// Relation options of the admin member form (`<optgroup label="Staff / service (Quick Entry)">`).
const kAdminStaffRelations = [
  'cook',
  'maid',
  'washerman',
  'newspaper',
  'driver',
  'guard',
  'cleaner',
  'sweeper',
  'housekeeper',
  'mid-servant',
];

/// Lowercase service types when a resident picks a fixed role (not "Others", which overlaps with family).
final List<String> _knownServiceTypeLc = kHouseholdServiceTypesLc.where((s) => s != 'others').toList();

/// Family / household relations. Staff should not use these.
const _familyRelationLc = {
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
  'others',
};

/// Web `isQuickEntryStaffMember`: servicemen registered on a flat (by resident or admin).
/// Primary owners are excluded. Matches known service types or a custom service label (e.g. plumber).
bool isQuickEntryStaffMember({required String? relation, required bool isPrimary}) {
  if (isPrimary) return false;
  final r = (relation ?? '').toLowerCase();
  if (r.isEmpty) return false;
  if (_knownServiceTypeLc.contains(r)) return true;
  return !_familyRelationLc.contains(r);
}

/// Stable synthetic phone when staff has no mobile (`visitors.phone` is NOT NULL in DB).
String staffMemberSyntheticPhone(String memberId) {
  final compact = memberId.replaceAll('-', '');
  return 'staff-${compact.length > 16 ? compact.substring(0, 16) : compact}';
}

/// Web `quickEntryPhoneForMember`.
String quickEntryPhoneForMember({required String memberId, required String? phone}) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 10) return digits.substring(digits.length - 10);
  return staffMemberSyntheticPhone(memberId);
}
