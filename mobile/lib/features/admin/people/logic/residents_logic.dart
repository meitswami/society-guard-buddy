import '../../../../utils/member_categories.dart';
import '../../../../utils/society_flat_layout.dart' show jsParseInt;
import '../data/people_models.dart';

/// Pure rules of web `src/components/AdminResidentManager.tsx` (search, member form
/// validation, primary-member decision, payloads, login sync planning).

String _joinTruthy(Iterable<String?> parts) =>
    parts.where((p) => p != null && p.isNotEmpty).cast<String>().join(' ');

/// Residents list search — web `filteredFlats` (flat no., owner name/phone, member name/phone/WA/email/relation).
List<PeopleFlat> filterAdminFlats({
  required List<PeopleFlat> flats,
  required Map<String, List<PeopleMember>> membersByFlat,
  required String query,
}) {
  if (query.trim().isEmpty) return flats;
  final q = query.toLowerCase();
  return flats.where((f) {
    final flatMembers = membersByFlat[f.id] ?? const [];
    final memberHay = flatMembers
        .map((m) => _joinTruthy(
            [m.name, m.phone, m.whatsappPhone, m.email, m.relation]))
        .join(' ')
        .toLowerCase();
    return f.flatNumber.toLowerCase().contains(q) ||
        (f.ownerName != null && f.ownerName!.toLowerCase().contains(q)) ||
        (f.ownerPhone != null && f.ownerPhone!.contains(q)) ||
        memberHay.contains(q);
  }).toList();
}

/// Web `matchingMembersForFlat` (name, phone, relation).
List<PeopleMember> adminNameHits(List<PeopleMember> flatMembers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return flatMembers
      .where((m) =>
          _joinTruthy([m.name, m.phone, m.relation]).toLowerCase().contains(q))
      .toList();
}

/// Validation failures of the member form (web toasts).
enum MemberFormIssue {
  nameRequired('Name is required', 'नाम आवश्यक है'),
  relationRequired(
      'Please select a relation or role', 'कृपया संबंध या भूमिका चुनें'),
  tenantPhotoId('Tenant: at least 1 Photo ID is required',
      'किरायेदार: कम से कम 1 फ़ोटो आईडी आवश्यक है'),
  tenantAgreement('Tenant: rental agreement document is required',
      'किरायेदार: किराया अनुबंध दस्तावेज़ आवश्यक है'),
  restrictedPhotoId(
    'Photo ID is required for restricted categories (tenant/other/service)',
    'प्रतिबंधित श्रेणियों (किरायेदार/अन्य/सेवा) के लिए फ़ोटो आईडी आवश्यक है',
  );

  const MemberFormIssue(this.en, this.hi);

  final String en;
  final String hi;
}

/// True when the form must collect ID documents (tenant, other or staff).
bool memberNeedsDocs(String relation) =>
    isRestrictedMemberCategory(relation) || isTenantRelation(relation);

MemberFormIssue? validateMemberForm({
  required MemberFormState form,
  required List<MemberDocDraft> docs,
  PeopleMember? editing,
}) {
  if (form.name.isEmpty) return MemberFormIssue.nameRequired;
  if (form.relation.isEmpty) return MemberFormIssue.relationRequired;

  final isTenant = isTenantRelation(form.relation);
  if (!memberNeedsDocs(form.relation)) return null;

  final photoIdDocs =
      docs.where((d) => d.kind == MemberDocKind.photoId && d.front.isNotEmpty);
  final tenantDocs = docs
      .where((d) => d.kind == MemberDocKind.tenantDoc && d.front.isNotEmpty);
  final hasLegacyFront = (editing?.idPhotoFront ?? '').isNotEmpty;
  final hasAnyPhotoId =
      photoIdDocs.isNotEmpty || form.idPhotoFront.isNotEmpty || hasLegacyFront;
  if (isTenant && !hasAnyPhotoId) return MemberFormIssue.tenantPhotoId;
  if (isTenant && tenantDocs.isEmpty) return MemberFormIssue.tenantAgreement;
  if (!isTenant && !hasAnyPhotoId) return MemberFormIssue.restrictedPhotoId;
  return null;
}

/// Web `showPrimaryCheckbox`.
bool showPrimaryCheckbox(
        {required String relation,
        required bool primaryExists,
        required int flatMemberCount}) =>
    allowsPrimaryMember(relation) && !primaryExists && flatMemberCount > 0;

/// Web primary decision inside `saveMember`.
bool decideIsPrimary({
  required String relation,
  required bool isEditing,
  required bool previousWasPrimary,
  required int flatMemberCount,
  required bool primaryExists,
  required bool formIsPrimary,
}) {
  if (!allowsPrimaryMember(relation)) return false;
  if (previousWasPrimary) return true;
  if (!isEditing && flatMemberCount == 0) return true;
  if (formIsPrimary &&
      showPrimaryCheckbox(
          relation: relation,
          primaryExists: primaryExists,
          flatMemberCount: flatMemberCount)) {
    return true;
  }
  return false;
}

/// `household_group` stored for a relation.
String householdGroupForRelation(String relation) =>
    relation.trim().toLowerCase() == 'tenant' ? 'tenant' : 'owner';

String? _orNull(String v) => v.isEmpty ? null : v;

/// `members` insert/update payload (web `payload`).
Map<String, dynamic> buildMemberPayload({
  required String flatId,
  required MemberFormState form,
  required List<MemberDocDraft> docs,
  required bool isPrimary,
}) {
  final payload = <String, dynamic>{
    'flat_id': flatId,
    'name': form.name,
    'phone': _orNull(form.phone),
    'whatsapp_phone': _orNull(form.whatsappPhone),
    'email': _orNull(form.email.trim()),
    'notify_whatsapp': form.notifyWhatsapp,
    'notify_email': form.notifyEmail,
    'relation': form.relation,
    'household_group': householdGroupForRelation(form.relation),
    'age': form.age.isEmpty ? null : jsParseInt(form.age),
    'gender': _orNull(form.gender),
    'is_primary': isPrimary,
    'photo': _orNull(form.photo),
  };
  if (memberNeedsDocs(form.relation)) {
    MemberDocDraft? best;
    for (final d in docs) {
      if (d.kind == MemberDocKind.photoId && d.front.isNotEmpty) {
        best = d;
        break;
      }
    }
    payload['id_photo_front'] =
        _orNull(best?.front ?? '') ?? _orNull(form.idPhotoFront);
    payload['id_photo_back'] =
        _orNull(best?.back ?? '') ?? _orNull(form.idPhotoBack);
    payload['police_verification'] = _orNull(form.policeVerification.trim());
    payload['spouse_name'] = _orNull(form.spouseName.trim());
    payload['date_joining'] = _orNull(form.dateJoining);
    payload['date_leave'] = _orNull(form.dateLeave);
  } else {
    payload['id_photo_front'] = null;
    payload['id_photo_back'] = null;
    payload['police_verification'] = null;
    payload['spouse_name'] = null;
    payload['date_joining'] = null;
    payload['date_leave'] = null;
  }
  return payload;
}

/// `member_documents` rows to insert (documents with a type and at least one image).
List<Map<String, dynamic>> memberDocumentRows(
        String memberId, List<MemberDocDraft> docs) =>
    [
      for (final d in docs)
        if (d.type.isNotEmpty && (d.front.isNotEmpty || d.back.isNotEmpty))
          {
            'member_id': memberId,
            'doc_kind': d.kind.db,
            'doc_type': d.type,
            'front_url': _orNull(d.front),
            'back_url': _orNull(d.back),
          },
    ];

/// Staff vehicle row of the member form, or null when no vehicle was entered
/// (web `syncStaffVehicleRow`).
Map<String, dynamic>? staffVehicleRow({
  required String societyId,
  required String memberId,
  required String flatId,
  required String flatNumber,
  required String residentName,
  required MemberFormState form,
}) {
  final num = form.vehicleNumber.trim();
  final hasVehicle = num.isNotEmpty || form.vehicleName.trim().isNotEmpty;
  if (!hasVehicle) return null;
  return {
    'society_id': societyId,
    'flat_id': flatId,
    'flat_number': flatNumber,
    'resident_name': residentName,
    'vehicle_number': num.isEmpty ? 'N/A' : num,
    'vehicle_type':
        form.vehicleCategory.isEmpty ? 'other' : form.vehicleCategory,
    'vehicle_display_name': _orNull(form.vehicleName.trim()),
    'vehicle_color': _orNull(form.vehicleColor.trim()),
    'member_id': memberId,
  };
}

/// Web `syncResidentUsersForFlat` planning: logins to create for household members with a
/// phone that have no account yet. All logins of a flat share one password (existing or new).
List<Map<String, dynamic>> planNewResidentLogins({
  required List<Map<String, dynamic>> latestMembers,
  required List<Map<String, dynamic>> existingUsers,
  required String flatId,
  required String flatNumber,
  required String Function() newPassword,
}) {
  final withPhone = latestMembers.where((m) {
    final phone = (m['phone'] ?? '').toString();
    return phone.isNotEmpty && allowsResidentLogin(m['relation']?.toString());
  }).toList();
  if (withPhone.isEmpty) return const [];
  final existingPhones = existingUsers.map((u) => '${u['phone']}').toSet();
  final password = existingUsers.isNotEmpty
      ? '${existingUsers.first['password']}'
      : newPassword();
  return [
    for (final m in withPhone)
      if (!existingPhones.contains('${m['phone']}'))
        {
          'name': m['name'],
          'phone': m['phone'],
          'flat_id': flatId,
          'flat_number': flatNumber,
          'password': password,
          'must_change_password': m['is_primary'] == true,
        },
  ];
}

/// Web `mapGenderForAdminForm`.
String mapGenderForAdminForm(String? g) {
  final x = (g ?? '').trim().toLowerCase();
  if (x == 'male') return 'Male';
  if (x == 'female') return 'Female';
  if (x == 'other') return 'Other';
  if (g == 'Male' || g == 'Female' || g == 'Other') return g!;
  return '';
}

/// Member form pre-filled from an existing row (web `editMember`).
MemberFormState memberFormFrom(PeopleMember m) => MemberFormState(
      name: m.name,
      phone: m.phone ?? '',
      whatsappPhone: m.whatsappPhone ?? '',
      email: m.email ?? '',
      notifyWhatsapp: m.notifyWhatsapp,
      notifyEmail: m.notifyEmail,
      relation: m.relation,
      age: m.age != null ? '${m.age}' : '',
      gender: mapGenderForAdminForm(m.gender),
      isPrimary: m.isPrimary,
      photo: m.photo ?? '',
      idPhotoFront: m.idPhotoFront ?? '',
      idPhotoBack: m.idPhotoBack ?? '',
      policeVerification: m.policeVerification ?? '',
      spouseName: m.spouseName ?? '',
      dateJoining: m.dateJoining ?? '',
      dateLeave: m.dateLeave ?? '',
    );

/// Document type options (web `docTypes`).
class DocTypeOption {
  const DocTypeOption(this.value, this.en, this.hi);

  final String value;
  final String en;
  final String hi;
}

const kPhotoIdDocTypes = [
  DocTypeOption('aadhaar', 'Aadhaar', 'आधार'),
  DocTypeOption('pan', 'PAN Card', 'पैन कार्ड'),
  DocTypeOption('passport', 'Passport', 'पासपोर्ट'),
  DocTypeOption('voter_id', 'Voter ID', 'मतदाता पहचान पत्र'),
  DocTypeOption('driving_license', 'Driving License', 'ड्राइविंग लाइसेंस'),
  DocTypeOption('other', 'Other', 'अन्य'),
];

const kTenantDocTypes = [
  DocTypeOption('rental_agreement', 'Rental agreement', 'किराया अनुबंध'),
  DocTypeOption('police_verification', 'Police verification', 'पुलिस सत्यापन'),
  DocTypeOption('other', 'Other', 'अन्य'),
];

const kServiceDocTypes = [
  DocTypeOption('id_proof', 'ID proof', 'पहचान प्रमाण'),
  DocTypeOption('police_verification', 'Police verification', 'पुलिस सत्यापन'),
  DocTypeOption('other', 'Other', 'अन्य'),
];

List<DocTypeOption> docTypesFor(MemberDocKind kind) => switch (kind) {
      MemberDocKind.photoId => kPhotoIdDocTypes,
      MemberDocKind.tenantDoc => kTenantDocTypes,
      MemberDocKind.serviceDoc => kServiceDocTypes,
    };

/// Default document type when "Add ID" / "Add doc" is tapped.
String defaultDocType(MemberDocKind kind) => switch (kind) {
      MemberDocKind.photoId => 'aadhaar',
      MemberDocKind.tenantDoc => 'rental_agreement',
      MemberDocKind.serviceDoc => 'id_proof',
    };

/// CSS `capitalize`: first letter of every word upper-cased.
String capitalizeWords(String s) => s.replaceAllMapped(
    RegExp(r'(^|[\s\-_/(])(\p{L})', unicode: true),
    (m) => '${m[1]}${m[2]!.toUpperCase()}');

/// Member subtitle line of the residents list (web `relation · 34y · Male · 📱… · WA … · email`).
String memberDetailLine(PeopleMember m, {bool includeLoginPhone = true}) {
  final b = StringBuffer(capitalizeWords(m.relation));
  if (m.age != null) b.write(' · ${m.age}y');
  if (m.gender != null) b.write(' · ${capitalizeWords(m.gender!)}');
  if (includeLoginPhone && m.phone != null) b.write(' · 📱${m.phone}');
  if (m.whatsappPhone != null) b.write(' · WA ${m.whatsappPhone}');
  if (m.email != null) b.write(' · ${m.email}');
  return b.toString();
}
