/// Household member rules — port of web `src/lib/memberCategories.ts`,
/// `src/lib/householdRoles.ts` and the member logic in `ResidentDashboard.tsx`
/// (`handleAddMember`, `startEditMember`, owner / tenant grouping).
library;

/// Family / household relations shown in resident + admin member forms (web `HOUSEHOLD_RELATION_TYPES`).
const List<String> kHouseholdRelationTypes = [
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

/// Flat-registered staff / domestic help (web `HOUSEHOLD_SERVICE_TYPES`).
const List<String> kHouseholdServiceTypes = [
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

const List<String> _serviceTypesLc = [
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
  'others',
];

/// Web `STAFF_VEHICLE_TYPES`.
const List<String> kStaffVehicleTypes = ['car', 'cycle', 'bike', 'activa', 'auto', 'other'];

/// Police verification states on restricted members.
const List<String> kPoliceVerificationStates = ['pending', 'submitted', 'verified'];

class DocTypeOption {
  const DocTypeOption(this.value, this.label);
  final String value;
  final String label;
}

/// Web `DOC_TYPES.photoId`.
const List<DocTypeOption> kPhotoIdDocTypes = [
  DocTypeOption('aadhaar', 'Aadhaar'),
  DocTypeOption('pan', 'PAN Card'),
  DocTypeOption('passport', 'Passport'),
  DocTypeOption('voter_id', 'Voter ID'),
  DocTypeOption('driving_license', 'Driving License'),
  DocTypeOption('other', 'Other'),
];

/// Web `DOC_TYPES.tenant`.
const List<DocTypeOption> kTenantDocTypes = [
  DocTypeOption('rental_agreement', 'Rental agreement'),
  DocTypeOption('police_verification', 'Police verification'),
  DocTypeOption('other', 'Other'),
];

const Set<String> _householdLoginRelations = {
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

/// Other(s), staff (cook, maid, …) or any custom serviceman label.
bool isRestrictedMemberCategory(String? relation) => !allowsResidentLogin(relation);

/// Web `isKnownHouseholdServiceType`.
bool isKnownHouseholdServiceType(String? relation) => _serviceTypesLc.contains((relation ?? '').trim().toLowerCase());

/// Web `SERVICE_TYPES.map(s => s.toLowerCase()).includes(m.relation?.toLowerCase())`.
bool isServiceRelation(String? relation) => relation != null && _serviceTypesLc.contains(relation.toLowerCase());

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Owner / tenant household group of a member row (web `groupOf` in the Family tab).
String memberHouseholdGroup({String? householdGroup, String? relation}) {
  final g = (householdGroup ?? '').trim().toLowerCase();
  if (g == 'owner' || g == 'tenant') return g;
  return (relation ?? '').trim().toLowerCase() == 'tenant' ? 'tenant' : 'owner';
}

/// `photo_id` / `tenant_doc` / `service_doc` upload on `member_documents`.
class MemberDocDraft {
  const MemberDocDraft({required this.kind, required this.type, this.front = '', this.back = ''});

  static const kindPhotoId = 'photo_id';
  static const kindTenantDoc = 'tenant_doc';
  static const kindServiceDoc = 'service_doc';

  final String kind;
  final String type;
  final String front;
  final String back;

  bool get hasImage => front.isNotEmpty || back.isNotEmpty;

  MemberDocDraft copyWith({String? type, String? front, String? back}) =>
      MemberDocDraft(kind: kind, type: type ?? this.type, front: front ?? this.front, back: back ?? this.back);

  /// Row inserted into `member_documents`.
  Map<String, dynamic> toRow(String memberId) => {
        'member_id': memberId,
        'doc_kind': kind,
        'doc_type': type,
        'front_url': front.isEmpty ? null : front,
        'back_url': back.isEmpty ? null : back,
      };

  /// Web `startEditMember` mapping (`kind || 'photo_id'`, `type || defaultType`).
  factory MemberDocDraft.fromRow(Map<String, dynamic> row, {String defaultType = 'other'}) {
    String s(Object? v) => v == null ? '' : v.toString();
    final kind = s(row['doc_kind']);
    final type = s(row['doc_type']);
    return MemberDocDraft(
      kind: kind.isEmpty ? kindPhotoId : kind,
      type: type.isEmpty ? defaultType : type,
      front: s(row['front_url']),
      back: s(row['back_url']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemberDocDraft && other.kind == kind && other.type == type && other.front == front && other.back == back;

  @override
  int get hashCode => Object.hash(kind, type, front, back);
}

/// Rows to insert after deleting the old `member_documents` (web: docs with a type and an image).
List<Map<String, dynamic>> memberDocumentRows(String memberId, List<MemberDocDraft> docs) => [
      for (final d in docs)
        if (d.type.isNotEmpty && d.hasImage) d.toRow(memberId),
    ];

/// Values of the web Family member form (`memberForm`).
class MemberFormData {
  const MemberFormData({
    this.name = '',
    this.phone = '',
    this.relation = '',
    this.age = '',
    this.gender = '',
    this.isServiceman = false,
    this.serviceType = '',
    this.customServiceType = '',
    this.photo = '',
    this.idPhotoFront = '',
    this.idPhotoBack = '',
    this.policeVerification = '',
    this.spouseName = '',
    this.dateJoining = '',
    this.dateLeave = '',
    this.vehicleCategory = '',
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleColor = '',
  });

  final String name;
  final String phone;

  /// Capitalised family relation (`Owner`, `Tenant`, `Others`, …).
  final String relation;
  final String age;
  final String gender;
  final bool isServiceman;
  final String serviceType;
  final String customServiceType;
  final String photo;
  final String idPhotoFront;
  final String idPhotoBack;
  final String policeVerification;
  final String spouseName;
  final String dateJoining;
  final String dateLeave;
  final String vehicleCategory;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleColor;

  /// Web shows the ID / tenant / staff block for servicemen, `Tenant` and `Others`.
  bool get showsRestrictedSection => isServiceman || relation == 'Tenant' || relation == 'Others';

  bool get isTenantRelation => relation.toLowerCase() == 'tenant';

  MemberFormData copyWith({
    String? name,
    String? phone,
    String? relation,
    String? age,
    String? gender,
    bool? isServiceman,
    String? serviceType,
    String? customServiceType,
    String? photo,
    String? idPhotoFront,
    String? idPhotoBack,
    String? policeVerification,
    String? spouseName,
    String? dateJoining,
    String? dateLeave,
    String? vehicleCategory,
    String? vehicleName,
    String? vehicleNumber,
    String? vehicleColor,
  }) =>
      MemberFormData(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        isServiceman: isServiceman ?? this.isServiceman,
        serviceType: serviceType ?? this.serviceType,
        customServiceType: customServiceType ?? this.customServiceType,
        photo: photo ?? this.photo,
        idPhotoFront: idPhotoFront ?? this.idPhotoFront,
        idPhotoBack: idPhotoBack ?? this.idPhotoBack,
        policeVerification: policeVerification ?? this.policeVerification,
        spouseName: spouseName ?? this.spouseName,
        dateJoining: dateJoining ?? this.dateJoining,
        dateLeave: dateLeave ?? this.dateLeave,
        vehicleCategory: vehicleCategory ?? this.vehicleCategory,
        vehicleName: vehicleName ?? this.vehicleName,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        vehicleColor: vehicleColor ?? this.vehicleColor,
      );
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Web `startEditMember`: seeds the form from a `members` row.
///
/// Two deliberate fixes over the web (which silently rewrote such members to
/// `Spouse` on save): a household relation that is not in the dropdown (e.g. `family`)
/// is kept as an extra option, and a custom staff label (e.g. `plumber`) opens as
/// serviceman → `Others` with that label in the custom field.
MemberFormData memberFormFromRow(Map<String, dynamic> m) {
  String s(Object? v) => v == null ? '' : v.toString();
  final rel = s(m['relation']);
  final relLower = rel.toLowerCase();
  var isService = isServiceRelation(rel);
  var relation = '';
  var serviceType = '';
  var customServiceType = '';
  if (isService) {
    serviceType = kHouseholdServiceTypes.firstWhere((x) => x.toLowerCase() == relLower, orElse: () => 'Others');
    // Web keeps `Spouse` in the hidden family dropdown for servicemen.
    relation = 'Spouse';
  } else {
    final known = kHouseholdRelationTypes.where((r) => r.toLowerCase() == relLower);
    if (known.isNotEmpty) {
      relation = known.first;
    } else if (relLower.isEmpty) {
      relation = '';
    } else if (allowsResidentLogin(relLower) || relLower == 'other') {
      relation = _capitalize(relLower);
    } else {
      isService = true;
      serviceType = 'Others';
      customServiceType = rel.trim();
      relation = 'Spouse';
    }
  }
  final g = s(m['gender']).trim().toLowerCase();
  final gender = (g == 'male' || g == 'female' || g == 'other') ? g : '';
  final age = m['age'];
  return MemberFormData(
    name: s(m['name']),
    phone: s(m['phone']),
    relation: relation,
    age: age == null ? '' : age.toString(),
    gender: gender,
    isServiceman: isService,
    serviceType: serviceType,
    customServiceType: customServiceType,
    photo: s(m['photo']),
    idPhotoFront: s(m['id_photo_front']),
    idPhotoBack: s(m['id_photo_back']),
    policeVerification: s(m['police_verification']),
    spouseName: s(m['spouse_name']),
    dateJoining: s(m['date_joining']),
    dateLeave: s(m['date_leave']),
  );
}

/// Family relations offered in the dropdown (web filters for primary members).
List<String> relationOptionsFor({required bool editingPrimary, String currentRelation = ''}) {
  final base = kHouseholdRelationTypes.where((r) => !editingPrimary || allowsPrimaryMember(r)).toList();
  if (currentRelation.isNotEmpty && !base.contains(currentRelation)) base.add(currentRelation);
  return base;
}

enum MemberSaveError {
  onCommittee,
  nameRequired,
  serviceTypeRequired,
  relationRequired,
  primaryMustStayOwner,
  tenantPhotoIdRequired,
  tenantRentalRequired,
  restrictedPhotoIdRequired,
}

/// Validated `members` payload for web `handleAddMember`.
class MemberSavePlan {
  const MemberSavePlan._({
    this.error,
    this.relNorm = '',
    this.restricted = false,
    this.isTenant = false,
    this.wasPrimary = false,
    this.payload = const {},
  });

  final MemberSaveError? error;
  final String relNorm;
  final bool restricted;
  final bool isTenant;
  final bool wasPrimary;
  final Map<String, dynamic> payload;

  bool get ok => error == null;
}

/// Mirrors the validation + payload building of web `handleAddMember`.
MemberSavePlan planMemberSave({
  required MemberFormData form,
  required List<MemberDocDraft> docs,
  required String flatId,
  Map<String, dynamic>? editing,
  bool editingOnCommittee = false,
  String? myHouseholdGroup,
}) {
  MemberSavePlan fail(MemberSaveError e) => MemberSavePlan._(error: e);
  if (editing != null && editingOnCommittee) return fail(MemberSaveError.onCommittee);
  final name = form.name.trim();
  if (name.isEmpty) return fail(MemberSaveError.nameRequired);
  if (form.isServiceman) {
    if (form.serviceType.isEmpty) return fail(MemberSaveError.serviceTypeRequired);
  } else if (form.relation.isEmpty) {
    return fail(MemberSaveError.relationRequired);
  }
  final relationRaw = form.isServiceman
      ? (form.serviceType == 'Others'
          ? (form.customServiceType.trim().isNotEmpty ? form.customServiceType.trim() : 'others')
          : form.serviceType)
      : (form.relation == 'Others' ? 'others' : form.relation);
  final relNorm = relationRaw.toLowerCase();
  final wasPrimary = editing?['is_primary'] == true;
  if (wasPrimary && (form.isServiceman || !allowsPrimaryMember(relNorm))) {
    return fail(MemberSaveError.primaryMustStayOwner);
  }
  final restricted = isRestrictedMemberCategory(relNorm);
  final isTenant = relNorm == 'tenant';
  final photoIdDocs = docs.where((d) => d.kind == MemberDocDraft.kindPhotoId && d.front.isNotEmpty).toList();
  final tenantDocs = docs.where((d) => d.kind == MemberDocDraft.kindTenantDoc && d.front.isNotEmpty).toList();
  final legacyFront = (editing?['id_photo_front'] ?? '').toString();
  final hasAnyPhotoId =
      photoIdDocs.isNotEmpty || legacyFront.isNotEmpty || form.idPhotoFront.isNotEmpty || form.photo.isNotEmpty;
  if (restricted || isTenant) {
    if (isTenant && !hasAnyPhotoId) return fail(MemberSaveError.tenantPhotoIdRequired);
    if (isTenant && tenantDocs.isEmpty) return fail(MemberSaveError.tenantRentalRequired);
    if (!isTenant && !hasAnyPhotoId) return fail(MemberSaveError.restrictedPhotoIdRequired);
  }

  String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
  final payload = <String, dynamic>{
    'flat_id': flatId,
    'name': name,
    'phone': form.phone.isEmpty ? null : form.phone,
    'relation': relNorm,
    'household_group': relNorm == 'tenant' || (myHouseholdGroup ?? '') == 'tenant' ? 'tenant' : 'owner',
    'age': form.age.trim().isEmpty ? null : int.tryParse(form.age.trim()),
    'gender': form.gender.isEmpty ? null : form.gender,
    'photo': form.photo.isEmpty ? null : form.photo,
    // Never demote primary via this form; new members are never primary here.
    'is_primary': wasPrimary,
  };
  if (restricted || isTenant) {
    final best = photoIdDocs.isEmpty ? null : photoIdDocs.first;
    final front = (best?.front.isNotEmpty ?? false)
        ? best!.front
        : (form.idPhotoFront.isNotEmpty ? form.idPhotoFront : form.photo);
    final back = (best?.back.isNotEmpty ?? false) ? best!.back : form.idPhotoBack;
    payload['id_photo_front'] = front.isEmpty ? null : front;
    payload['id_photo_back'] = back.isEmpty ? null : back;
    payload['police_verification'] = orNull(form.policeVerification);
    payload['spouse_name'] = orNull(form.spouseName);
    payload['date_joining'] = form.dateJoining.isEmpty ? null : form.dateJoining;
    payload['date_leave'] = form.dateLeave.isEmpty ? null : form.dateLeave;
  } else {
    payload['id_photo_front'] = null;
    payload['id_photo_back'] = null;
    payload['police_verification'] = null;
    payload['spouse_name'] = null;
    payload['date_joining'] = null;
    payload['date_leave'] = null;
  }
  return MemberSavePlan._(
    relNorm: relNorm,
    restricted: restricted,
    isTenant: isTenant,
    wasPrimary: wasPrimary,
    payload: payload,
  );
}

/// Which `resident_users` logins to remove before saving (web `handleAddMember`).
List<String> loginPhonesToRemove({required String? previousPhone, required String newPhone, required bool restricted}) {
  final out = <String>[];
  final prev = previousPhone ?? '';
  if (prev.isNotEmpty && (restricted || newPhone.isEmpty || newPhone != prev)) out.add(prev);
  if (restricted && newPhone.isNotEmpty && !out.contains(newPhone)) out.add(newPhone);
  return out;
}

/// `resident_vehicles` row for a restricted member's vehicle (web `syncResidentStaffVehicle`);
/// null when the vehicle fields are empty (existing row is deleted).
Map<String, dynamic>? staffVehicleRow({
  required MemberFormData form,
  required String? societyId,
  required String flatId,
  required String flatNumber,
  required String memberId,
}) {
  final num = form.vehicleNumber.trim();
  final hasVehicle = num.isNotEmpty || form.vehicleName.trim().isNotEmpty;
  if (!hasVehicle) return null;
  return {
    'society_id': societyId,
    'flat_id': flatId,
    'flat_number': flatNumber,
    'resident_name': form.name.trim(),
    'vehicle_number': num.isEmpty ? 'N/A' : num,
    'vehicle_type': form.vehicleCategory.isEmpty ? 'other' : form.vehicleCategory,
    'vehicle_display_name': form.vehicleName.trim().isEmpty ? null : form.vehicleName.trim(),
    'vehicle_color': form.vehicleColor.trim().isEmpty ? null : form.vehicleColor.trim(),
    'member_id': memberId,
  };
}

/// Member line under the name (web: `🧹 cook · 34y · female · 📱98…`).
String memberSubtitle({String? relation, Object? age, String? gender, String? phone}) {
  final rel = relation ?? '';
  final service = isServiceRelation(rel);
  final b = StringBuffer(service ? '🧹 $rel' : rel);
  if (age != null && age.toString().isNotEmpty && age.toString() != '0') b.write(' · ${age}y');
  if ((gender ?? '').isNotEmpty) b.write(' · $gender');
  if ((phone ?? '').isNotEmpty) b.write(' · 📱$phone');
  return b.toString();
}
