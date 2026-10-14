/// Society directory rows (web `Flat`, `Member`, `ResidentVehicle`, `Visitor` store types).
library;

String? _s(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// `flats` row — mapped like web `useStore.loadFlats`.
class PeopleFlat {
  const PeopleFlat({
    required this.id,
    required this.flatNumber,
    this.floor,
    this.wing,
    this.flatType = 'residential',
    this.ownerName,
    this.ownerPhone,
    this.intercom,
    this.isOccupied = true,
    this.ownerLivesHere = true,
    this.tenantHouseholdType,
    this.societyId,
  });

  final String id;
  final String flatNumber;
  final String? floor;
  final String? wing;
  final String flatType;
  final String? ownerName;
  final String? ownerPhone;
  final String? intercom;
  final bool isOccupied;
  final bool ownerLivesHere;
  final String? tenantHouseholdType;
  final String? societyId;

  factory PeopleFlat.fromJson(Map<String, dynamic> f) => PeopleFlat(
        id: '${f['id']}',
        flatNumber: '${f['flat_number'] ?? ''}',
        floor: _s(f['floor']),
        wing: _s(f['wing']),
        flatType: _s(f['flat_type']) ?? 'residential',
        ownerName: _s(f['owner_name']),
        ownerPhone: _s(f['owner_phone']),
        intercom: _s(f['intercom']),
        isOccupied: f['is_occupied'] as bool? ?? true,
        ownerLivesHere: f['owner_lives_here'] as bool? ?? true,
        tenantHouseholdType: _s(f['tenant_household_type']),
        societyId: _s(f['society_id']),
      );
}

/// `members` row — mapped like web `useStore.loadMembers`.
class PeopleMember {
  const PeopleMember({
    required this.id,
    required this.flatId,
    required this.name,
    this.phone,
    this.whatsappPhone,
    this.email,
    this.notifyWhatsapp = true,
    this.notifyEmail = true,
    this.relation = 'owner',
    this.age,
    this.gender,
    this.photo,
    this.isPrimary = false,
    this.idPhotoFront,
    this.idPhotoBack,
    this.policeVerification,
    this.spouseName,
    this.dateJoining,
    this.dateLeave,
    this.householdGroup,
    this.createdAt,
  });

  final String id;
  final String flatId;
  final String name;
  final String? phone;
  final String? whatsappPhone;
  final String? email;
  final bool notifyWhatsapp;
  final bool notifyEmail;
  final String relation;
  final int? age;
  final String? gender;
  final String? photo;
  final bool isPrimary;
  final String? idPhotoFront;
  final String? idPhotoBack;
  final String? policeVerification;
  final String? spouseName;
  final String? dateJoining;
  final String? dateLeave;
  final String? householdGroup;
  final String? createdAt;

  factory PeopleMember.fromJson(Map<String, dynamic> m) {
    final age = m['age'];
    final ageInt = age is num ? age.toInt() : int.tryParse('${age ?? ''}');
    return PeopleMember(
      id: '${m['id']}',
      flatId: '${m['flat_id']}',
      name: '${m['name'] ?? ''}',
      phone: _s(m['phone']),
      whatsappPhone: _s(m['whatsapp_phone']),
      email: _s(m['email']),
      notifyWhatsapp: m['notify_whatsapp'] != false,
      notifyEmail: m['notify_email'] != false,
      relation: _s(m['relation']) ?? 'owner',
      age: (ageInt == null || ageInt == 0) ? null : ageInt,
      gender: _s(m['gender']),
      photo: _s(m['photo']),
      isPrimary: m['is_primary'] == true,
      idPhotoFront: _s(m['id_photo_front']),
      idPhotoBack: _s(m['id_photo_back']),
      policeVerification: _s(m['police_verification']),
      spouseName: _s(m['spouse_name']),
      dateJoining: _s(m['date_joining']),
      dateLeave: _s(m['date_leave']),
      householdGroup: _s(m['household_group']),
      createdAt: _s(m['created_at']),
    );
  }

  /// Web `memberGroup`: explicit `household_group` owner/tenant, else derived from relation.
  String get group {
    final g = (householdGroup ?? '').trim().toLowerCase();
    if (g == 'owner' || g == 'tenant') return g;
    return relation.trim().toLowerCase() == 'tenant' ? 'tenant' : 'owner';
  }
}

/// `resident_vehicles` row.
class PeopleVehicle {
  const PeopleVehicle({
    required this.id,
    required this.flatNumber,
    required this.residentName,
    required this.vehicleNumber,
    required this.vehicleType,
    this.flatId,
    this.memberId,
    this.vehicleColor,
    this.vehicleDisplayName,
    this.vehiclePhoto,
    this.societyId,
  });

  final String id;
  final String flatNumber;
  final String residentName;
  final String vehicleNumber;
  final String vehicleType;
  final String? flatId;
  final String? memberId;
  final String? vehicleColor;
  final String? vehicleDisplayName;
  final String? vehiclePhoto;
  final String? societyId;

  factory PeopleVehicle.fromJson(Map<String, dynamic> v) => PeopleVehicle(
        id: '${v['id']}',
        flatNumber: '${v['flat_number'] ?? ''}',
        residentName: '${v['resident_name'] ?? ''}',
        vehicleNumber: '${v['vehicle_number'] ?? ''}',
        vehicleType: '${v['vehicle_type'] ?? ''}',
        flatId: _s(v['flat_id']),
        memberId: _s(v['member_id']),
        vehicleColor: _s(v['vehicle_color']),
        vehicleDisplayName: _s(v['vehicle_display_name']),
        vehiclePhoto: _s(v['vehicle_photo']),
        societyId: _s(v['society_id']),
      );
}

/// `visitors` row (fields the directory needs).
class DirectoryVisitor {
  const DirectoryVisitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.entryTime,
    this.visitorPhotos = const [],
    this.category = '',
    this.documentType = '',
    this.documentNumber = '',
    this.purpose = '',
    this.vehicleNumber,
  });

  final String id;
  final String name;
  final String phone;
  final String flatNumber;
  final String entryTime;
  final List<String> visitorPhotos;
  final String category;
  final String documentType;
  final String documentNumber;
  final String purpose;
  final String? vehicleNumber;

  factory DirectoryVisitor.fromJson(Map<String, dynamic> v) {
    final photos = v['visitor_photos'];
    return DirectoryVisitor(
      id: '${v['id']}',
      name: '${v['name'] ?? ''}',
      phone: '${v['phone'] ?? ''}',
      flatNumber: '${v['flat_number'] ?? ''}',
      entryTime: '${v['entry_time'] ?? ''}',
      visitorPhotos: photos is List
          ? photos
              .whereType<String>()
              .where((p) => p.trim().isNotEmpty)
              .toList()
          : const [],
      category: '${v['category'] ?? ''}',
      documentType: '${v['document_type'] ?? ''}',
      documentNumber: '${v['document_number'] ?? ''}',
      purpose: '${v['purpose'] ?? ''}',
      vehicleNumber: _s(v['vehicle_number']),
    );
  }
}

/// One entry of the visitor directory (grouped by phone).
class VisitorDirectoryEntry {
  VisitorDirectoryEntry(
      {required this.latest,
      required this.totalVisits,
      required this.firstVisit});

  DirectoryVisitor latest;
  int totalVisits;
  String firstVisit;
}
