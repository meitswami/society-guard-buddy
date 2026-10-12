/// Admin people-management rows and form state (web `AdminResidentManager.tsx`,
/// `AdminGuardManager.tsx`, `ParkingManager.tsx`).
library;

export '../../../shared/directory/directory_models.dart';

String? _s(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// `resident_users` row (flat login account).
class ResidentLogin {
  const ResidentLogin({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatId,
    required this.flatNumber,
    required this.password,
    this.mustChangePassword = false,
    this.whatsappPhone,
    this.email,
  });

  final String id;
  final String name;
  final String phone;
  final String flatId;
  final String flatNumber;
  final String password;
  final bool mustChangePassword;
  final String? whatsappPhone;
  final String? email;

  factory ResidentLogin.fromJson(Map<String, dynamic> r) => ResidentLogin(
        id: '${r['id']}',
        name: '${r['name'] ?? ''}',
        phone: '${r['phone'] ?? ''}',
        flatId: '${r['flat_id']}',
        flatNumber: '${r['flat_number'] ?? ''}',
        password: '${r['password'] ?? ''}',
        mustChangePassword: r['must_change_password'] == true,
        whatsappPhone: _s(r['whatsapp_phone']),
        email: _s(r['email']),
      );
}

/// `member_documents.doc_kind`.
enum MemberDocKind {
  photoId('photo_id'),
  tenantDoc('tenant_doc'),
  serviceDoc('service_doc');

  const MemberDocKind(this.db);

  final String db;

  static MemberDocKind fromDb(String? v) =>
      MemberDocKind.values.firstWhere((k) => k.db == v, orElse: () => MemberDocKind.photoId);
}

/// One document being edited in the member form (front/back are data URLs).
class MemberDocDraft {
  MemberDocDraft({required this.kind, required this.type, this.front = '', this.back = ''});

  MemberDocKind kind;
  String type;
  String front;
  String back;

  factory MemberDocDraft.fromJson(Map<String, dynamic> d) => MemberDocDraft(
        kind: MemberDocKind.fromDb(_s(d['doc_kind'])),
        type: _s(d['doc_type']) ?? 'other',
        front: _s(d['front_url']) ?? '',
        back: _s(d['back_url']) ?? '',
      );
}

/// Web `MemberFormState`.
class MemberFormState {
  MemberFormState({
    this.name = '',
    this.phone = '',
    this.whatsappPhone = '',
    this.email = '',
    this.notifyWhatsapp = true,
    this.notifyEmail = true,
    this.relation = 'family',
    this.age = '',
    this.gender = '',
    this.isPrimary = false,
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

  String name;
  String phone;
  String whatsappPhone;
  String email;
  bool notifyWhatsapp;
  bool notifyEmail;
  String relation;
  String age;
  String gender;
  bool isPrimary;
  String photo;
  String idPhotoFront;
  String idPhotoBack;
  String policeVerification;
  String spouseName;
  String dateJoining;
  String dateLeave;
  String vehicleCategory;
  String vehicleName;
  String vehicleNumber;
  String vehicleColor;
}

/// `guards` row.
class GuardRow {
  const GuardRow({
    required this.id,
    required this.guardId,
    required this.name,
    required this.password,
    required this.authMode,
    required this.policeVerification,
    this.policeVerificationDate,
    required this.kycAlertDays,
    this.phone,
    this.photoUrl,
  });

  final String id;
  final String guardId;
  final String name;
  final String password;
  final String authMode;
  final String policeVerification;
  final String? policeVerificationDate;
  final int kycAlertDays;
  final String? phone;
  final String? photoUrl;

  factory GuardRow.fromJson(Map<String, dynamic> g) => GuardRow(
        id: '${g['id']}',
        guardId: '${g['guard_id'] ?? ''}',
        name: '${g['name'] ?? ''}',
        password: '${g['password'] ?? ''}',
        authMode: _s(g['auth_mode']) ?? 'password',
        policeVerification: _s(g['police_verification']) ?? 'pending',
        policeVerificationDate: _s(g['police_verification_date']),
        kycAlertDays: g['kyc_alert_days'] is num ? (g['kyc_alert_days'] as num).toInt() : 7,
        phone: _s(g['phone']),
        photoUrl: _s(g['photo_url']),
      );
}

/// `guard_documents` row (Photo ID front/back per document type).
class GuardDoc {
  const GuardDoc({required this.id, required this.guardId, required this.docLabel, this.frontUrl, this.backUrl});

  final String id;
  final String guardId;
  final String docLabel;
  final String? frontUrl;
  final String? backUrl;

  factory GuardDoc.fromJson(Map<String, dynamic> d) => GuardDoc(
        id: '${d['id']}',
        guardId: '${d['guard_id']}',
        docLabel: '${d['doc_label'] ?? ''}',
        frontUrl: _s(d['front_url']),
        backUrl: _s(d['back_url']),
      );
}

/// `guard_attachments` row (multiple images / PDFs per worker).
class GuardAttachment {
  const GuardAttachment({
    required this.id,
    required this.guardId,
    required this.fileUrl,
    this.fileName,
    required this.docLabel,
    required this.sortOrder,
  });

  final String id;
  final String guardId;
  final String fileUrl;
  final String? fileName;
  final String docLabel;
  final int sortOrder;

  factory GuardAttachment.fromJson(Map<String, dynamic> a) => GuardAttachment(
        id: '${a['id']}',
        guardId: '${a['guard_id']}',
        fileUrl: '${a['file_url'] ?? ''}',
        fileName: _s(a['file_name']),
        docLabel: '${a['doc_label'] ?? ''}',
        sortOrder: a['sort_order'] is num ? (a['sort_order'] as num).toInt() : 0,
      );
}

/// `parking_spaces` row.
class ParkingSpace {
  const ParkingSpace({
    required this.id,
    required this.spaceNumber,
    required this.spaceType,
    this.floorLevel,
    required this.isAllocated,
    this.allocatedFlatId,
    this.allocatedFlatNumber,
    this.allocatedVehicleNumber,
    this.notes,
  });

  final String id;
  final String spaceNumber;
  final String spaceType;
  final String? floorLevel;
  final bool isAllocated;
  final String? allocatedFlatId;
  final String? allocatedFlatNumber;
  final String? allocatedVehicleNumber;
  final String? notes;

  factory ParkingSpace.fromJson(Map<String, dynamic> s) => ParkingSpace(
        id: '${s['id']}',
        spaceNumber: '${s['space_number'] ?? ''}',
        spaceType: _s(s['space_type']) ?? 'car',
        floorLevel: _s(s['floor_level']),
        isAllocated: s['is_allocated'] == true,
        allocatedFlatId: _s(s['allocated_flat_id']),
        allocatedFlatNumber: _s(s['allocated_flat_number']),
        allocatedVehicleNumber: _s(s['allocated_vehicle_number']),
        notes: _s(s['notes']),
      );
}
