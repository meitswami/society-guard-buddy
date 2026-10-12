import '../logic/role_permissions.dart';
import '../logic/society_form.dart';

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s;
}

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

num? _numOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

bool? _boolOrNull(Object? v) => v is bool ? v : null;

List<String> _stringList(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : <String>[];

/// `societies` row (web `Society` interface + the columns the details sheet shows).
class SocietyRow {
  const SocietyRow({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.isActive = true,
    this.logoUrl,
    this.contactPerson,
    this.contactEmail,
    this.contactPhone,
    this.letterheadUrl,
    this.letterheadMode,
    this.letterheadTopMm,
    this.letterheadBottomMm,
    this.photoUrls = const [],
    this.totalFlats,
    this.totalFloors,
    this.blockNames,
    this.terraceAccessible,
    this.hasBasement,
    this.basementUsableForResidents,
    this.flatsPerFloor,
    this.flatSeriesStart,
    this.flatSeriesEnd,
    this.referralCode,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final bool isActive;
  final String? logoUrl;
  final String? contactPerson;
  final String? contactEmail;
  final String? contactPhone;
  final String? letterheadUrl;
  final String? letterheadMode;
  final num? letterheadTopMm;
  final num? letterheadBottomMm;
  final List<String> photoUrls;
  final int? totalFlats;
  final int? totalFloors;
  final List<String>? blockNames;
  final bool? terraceAccessible;
  final bool? hasBasement;
  final bool? basementUsableForResidents;
  final int? flatsPerFloor;
  final String? flatSeriesStart;
  final String? flatSeriesEnd;
  final String? referralCode;
  final String? createdAt;

  factory SocietyRow.fromJson(Map<String, dynamic> j) => SocietyRow(
        id: '${j['id']}',
        name: _str(j['name']) ?? '',
        address: _str(j['address']),
        city: _str(j['city']),
        state: _str(j['state']),
        pincode: _str(j['pincode']),
        isActive: j['is_active'] != false,
        logoUrl: _str(j['logo_url']),
        contactPerson: _str(j['contact_person']),
        contactEmail: _str(j['contact_email']),
        contactPhone: _str(j['contact_phone']),
        letterheadUrl: _str(j['letterhead_url']),
        letterheadMode: _str(j['letterhead_mode']),
        letterheadTopMm: _numOrNull(j['letterhead_top_mm']),
        letterheadBottomMm: _numOrNull(j['letterhead_bottom_mm']),
        photoUrls: _stringList(j['photo_urls']),
        totalFlats: _intOrNull(j['total_flats']),
        totalFloors: _intOrNull(j['total_floors']),
        blockNames:
            j['block_names'] is List ? _stringList(j['block_names']) : null,
        terraceAccessible: _boolOrNull(j['terrace_accessible']),
        hasBasement: _boolOrNull(j['has_basement']),
        basementUsableForResidents:
            _boolOrNull(j['basement_usable_for_residents']),
        flatsPerFloor: _intOrNull(j['flats_per_floor']),
        flatSeriesStart: _str(j['flat_series_start']),
        flatSeriesEnd: _str(j['flat_series_end']),
        referralCode: _str(j['referral_code']),
        createdAt: _str(j['created_at']),
      );

  /// Web `const thumb = s.logo_url || photos[0]`.
  String? get thumbUrl {
    if (logoUrl != null && logoUrl!.isNotEmpty) return logoUrl;
    return photoUrls.isNotEmpty ? photoUrls.first : null;
  }

  String get addressLine =>
      societyAddressLine(address: address, city: city, state: state);

  SocietyFormSource get formSource => SocietyFormSource(
        name: name,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        contactPerson: contactPerson,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        logoUrl: logoUrl,
        letterheadUrl: letterheadUrl,
        letterheadMode: letterheadMode,
        letterheadTopMm: letterheadTopMm,
        letterheadBottomMm: letterheadBottomMm,
        totalFlats: totalFlats,
        totalFloors: totalFloors,
        blockNames: blockNames,
        terraceAccessible: terraceAccessible,
        hasBasement: hasBasement,
        basementUsableForResidents: basementUsableForResidents,
        flatsPerFloor: flatsPerFloor,
        flatSeriesStart: flatSeriesStart,
        flatSeriesEnd: flatSeriesEnd,
        photoUrls: photoUrls,
      );

  /// Local search (name, address, contact, referral code).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      name,
      address,
      city,
      state,
      pincode,
      contactPerson,
      contactPhone,
      contactEmail,
      referralCode
    ].whereType<String>().any((v) => v.toLowerCase().contains(q));
  }
}

/// `society_roles` row.
class SocietyRoleRow {
  const SocietyRoleRow({
    required this.id,
    required this.societyId,
    required this.roleName,
    this.slug,
    this.permissionsRaw,
    this.createdAt,
  });

  final String id;
  final String societyId;
  final String roleName;
  final String? slug;
  final Object? permissionsRaw;
  final String? createdAt;

  /// Effective permissions an admin with this role gets (web `mergeRolePermissions`).
  RolePermissions get permissions => RolePermissions.merge(permissionsRaw);

  factory SocietyRoleRow.fromJson(Map<String, dynamic> j) => SocietyRoleRow(
        id: '${j['id']}',
        societyId: '${j['society_id']}',
        roleName: _str(j['role_name']) ?? '',
        slug: _str(j['slug']),
        permissionsRaw: j['permissions'],
        createdAt: _str(j['created_at']),
      );
}

/// `admins` row (web `Admin` interface).
class AdminRow {
  const AdminRow({
    required this.id,
    required this.name,
    required this.adminId,
    required this.password,
    this.societyId,
    this.roleId,
    this.email,
    this.createdAt,
  });

  final String id;
  final String name;
  final String adminId;
  final String password;
  final String? societyId;
  final String? roleId;
  final String? email;
  final String? createdAt;

  factory AdminRow.fromJson(Map<String, dynamic> j) => AdminRow(
        id: '${j['id']}',
        name: _str(j['name']) ?? '',
        adminId: _str(j['admin_id']) ?? '',
        password: _str(j['password']) ?? '',
        societyId: _str(j['society_id']),
        roleId: _str(j['role_id']),
        email: _str(j['email']),
        createdAt: _str(j['created_at']),
      );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [name, adminId, email]
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }
}

/// `super_admins` row used by the login form.
class SuperAdminRow {
  const SuperAdminRow({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    this.recoveryEmail,
    this.totpEnabled = false,
    this.totpSecret,
  });

  final String id;
  final String name;
  final String username;
  final String password;
  final String? recoveryEmail;
  final bool totpEnabled;
  final String? totpSecret;

  bool get hasTotpSecret => totpSecret != null && totpSecret!.isNotEmpty;

  factory SuperAdminRow.fromJson(Map<String, dynamic> j) => SuperAdminRow(
        id: '${j['id']}',
        name: _str(j['name']) ?? '',
        username: _str(j['username']) ?? '',
        password: _str(j['password']) ?? '',
        recoveryEmail: _str(j['recovery_email']),
        totpEnabled: j['totp_enabled'] == true,
        totpSecret: _str(j['totp_secret']),
      );

  SuperAdminRow copyWith(
          {String? totpSecret, bool? totpEnabled, String? recoveryEmail}) =>
      SuperAdminRow(
        id: id,
        name: name,
        username: username,
        password: password,
        recoveryEmail: recoveryEmail ?? this.recoveryEmail,
        totpEnabled: totpEnabled ?? this.totpEnabled,
        totpSecret: totpSecret ?? this.totpSecret,
      );
}

/// One `support_tickets.media_items` entry (`{url, kind}`).
class TicketMedia {
  const TicketMedia({required this.url, this.kind});

  final String url;
  final String? kind;
}

/// Web `parseMedia(raw)`: array entries that are objects with a `url`.
List<TicketMedia> parseTicketMedia(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final x in raw)
      if (x is Map && x.containsKey('url'))
        TicketMedia(url: '${x['url'] ?? ''}', kind: x['kind']?.toString()),
  ];
}

/// `support_tickets` row.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.message,
    required this.flatNumber,
    required this.submitterName,
    required this.submitterResidentId,
    this.societyId,
    this.societyName,
    this.submitterKind,
    this.media = const [],
    this.audioUrl,
    this.superadminReply,
    this.repliedAt,
    this.repliedBySuperadminId,
    this.createdAt,
  });

  final String id;
  final int ticketNumber;
  final String status;
  final String message;
  final String flatNumber;
  final String submitterName;
  final String submitterResidentId;
  final String? societyId;
  final String? societyName;
  final String? submitterKind;
  final List<TicketMedia> media;
  final String? audioUrl;
  final String? superadminReply;
  final String? repliedAt;
  final String? repliedBySuperadminId;
  final String? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: '${j['id']}',
        ticketNumber: _intOrNull(j['ticket_number']) ?? 0,
        status: _str(j['status']) ?? 'pending',
        message: _str(j['message']) ?? '',
        flatNumber: _str(j['flat_number']) ?? '',
        submitterName: _str(j['submitter_name']) ?? '',
        submitterResidentId: _str(j['submitter_resident_id']) ?? '',
        societyId: _str(j['society_id']),
        societyName: _str(j['society_name']),
        submitterKind: _str(j['submitter_kind']),
        media: parseTicketMedia(j['media_items']),
        audioUrl: _str(j['audio_url']),
        superadminReply: _str(j['superadmin_reply']),
        repliedAt: _str(j['replied_at']),
        repliedBySuperadminId: _str(j['replied_by_superadmin_id']),
        createdAt: _str(j['created_at']),
      );
}

/// Web `STATUS_OPTIONS` of `SuperadminSupportTickets`.
const List<String> kTicketStatuses = ['pending', 'resolved', 'future_update'];

/// `society_orders` joined with its `society_signups` row (web onboarding table row).
class OnboardingRow {
  const OnboardingRow({required this.order, this.signup});

  final Map<String, dynamic> order;
  final Map<String, dynamic>? signup;

  String get orderId => '${order['id']}';
  String get orderStatus => '${order['status'] ?? '—'}';
  String? get signupStatus => signup?['status']?.toString();
  String? get societyName => signup?['society_name']?.toString();
  String? get contactPhone => signup?['contact_phone']?.toString();
  String? get contactPerson => signup?['contact_person']?.toString();
  String? get referralCodeUsed => signup?['referral_code_used']?.toString();
  String get merchantTransactionId =>
      '${order['merchant_transaction_id'] ?? ''}';
  String get provider => '${order['provider'] ?? ''}';
  String get currency => '${order['currency'] ?? 'INR'}';
  String? get createdAt => order['created_at']?.toString();
  num get amountInr {
    final v = order['amount_inr'];
    if (v is num) return v;
    return num.tryParse('${v ?? ''}') ?? 0;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      societyName,
      contactPhone,
      contactPerson,
      merchantTransactionId,
      referralCodeUsed
    ].whereType<String>().any((v) => v.toLowerCase().contains(q));
  }
}

/// Web `loadOnboarding` join: orders (newest first) with their signups by `signup_id`.
List<OnboardingRow> joinOnboarding(
    List<Map<String, dynamic>> orders, List<Map<String, dynamic>> signups) {
  final byId = {for (final s in signups) '${s['id']}': s};
  return [
    for (final o in orders)
      OnboardingRow(order: o, signup: byId['${o['signup_id']}'])
  ];
}

/// Distinct non-empty signup ids (web `[...new Set(orders.map((o) => o.signup_id).filter(Boolean))]`).
List<String> distinctSignupIds(List<Map<String, dynamic>> orders) {
  final seen = <String>{};
  final out = <String>[];
  for (final o in orders) {
    final id = o['signup_id'];
    if (id == null || '$id'.isEmpty) continue;
    if (seen.add('$id')) out.add('$id');
  }
  return out;
}

/// Server-side biometric credential (`biometric_credentials`) shown in Settings.
class BiometricDevice {
  const BiometricDevice(
      {required this.id,
      required this.credentialId,
      required this.createdAt,
      this.thisDevice = false});

  final String id;
  final String credentialId;
  final String createdAt;
  final bool thisDevice;

  String get shortId =>
      credentialId.length > 8 ? credentialId.substring(0, 8) : credentialId;
}
