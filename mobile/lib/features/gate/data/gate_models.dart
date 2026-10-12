import '../../../core/format/formatters.dart';

String? _nonEmpty(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

List<String> _stringList(Object? v) {
  if (v is List) return v.whereType<Object>().map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  return const [];
}

/// One `visitors` row — web `Visitor` (`src/types/index.ts`, mapped in `useStore.loadVisitors`).
class GateVisitor {
  const GateVisitor({
    required this.id,
    this.societyId,
    required this.name,
    required this.phone,
    this.documentType = 'aadhaar',
    this.documentNumber = '',
    this.documentPhoto,
    this.visitorPhotos = const [],
    required this.flatNumber,
    required this.purpose,
    required this.entryTime,
    this.exitTime,
    this.guardId = '',
    this.guardName = '',
    this.category = 'visitor',
    this.company,
    this.vehicleNumber,
    this.vehiclePhoto,
    this.vehicleEntryTime,
    this.vehicleExitTime,
    this.isBlacklisted = false,
  });

  final String id;
  final String? societyId;
  final String name;
  final String phone;

  /// `aadhaar` | `driving_license` | `passport` | `other`
  final String documentType;
  final String documentNumber;
  final String? documentPhoto;

  /// Data URLs (web `PhotoCapture`) or http(s) URLs.
  final List<String> visitorPhotos;
  final String flatNumber;
  final String purpose;

  /// ISO timestamp exactly as stored (`entry_time`).
  final String entryTime;
  final String? exitTime;
  final String guardId;
  final String guardName;

  /// `visitor` | `delivery` | `service`
  final String category;
  final String? company;
  final String? vehicleNumber;
  final String? vehiclePhoto;
  final String? vehicleEntryTime;
  final String? vehicleExitTime;
  final bool isBlacklisted;

  bool get isInside => exitTime == null || exitTime!.isEmpty;
  bool get hasVehicle => vehicleNumber != null && vehicleNumber!.isNotEmpty;

  /// Entry time in device local time (null when the stored value is not a date).
  DateTime? get entryAt => DateTime.tryParse(entryTime)?.toLocal();
  DateTime? get exitAt => exitTime == null ? null : DateTime.tryParse(exitTime!)?.toLocal();

  /// Local calendar day of the entry as `yyyy-MM-dd` (empty when unknown).
  String get entryDay {
    final d = entryAt;
    return d == null ? '' : Fmt.isoDate(d);
  }

  factory GateVisitor.fromRow(Map<String, dynamic> v) => GateVisitor(
        id: asString(v['id']),
        societyId: _nonEmpty(v['society_id']),
        name: asString(v['name']),
        phone: asString(v['phone']),
        documentType: _nonEmpty(v['document_type']) ?? 'other',
        documentNumber: asString(v['document_number']),
        documentPhoto: _nonEmpty(v['document_photo']),
        visitorPhotos: _stringList(v['visitor_photos']),
        flatNumber: asString(v['flat_number']),
        purpose: asString(v['purpose']),
        entryTime: asString(v['entry_time']),
        exitTime: _nonEmpty(v['exit_time']),
        guardId: asString(v['guard_id']),
        guardName: asString(v['guard_name']),
        category: _nonEmpty(v['category']) ?? 'visitor',
        company: _nonEmpty(v['company']),
        vehicleNumber: _nonEmpty(v['vehicle_number']),
        vehiclePhoto: _nonEmpty(v['vehicle_photo']),
        vehicleEntryTime: _nonEmpty(v['vehicle_entry_time']),
        vehicleExitTime: _nonEmpty(v['vehicle_exit_time']),
        isBlacklisted: v['is_blacklisted'] == true,
      );

  /// Insert payload — identical to web `useStore.addVisitor`.
  Map<String, dynamic> toInsertRow(String societyId) => {
        'society_id': societyId,
        'name': name,
        'phone': phone,
        'document_type': documentType,
        'document_number': documentNumber.isEmpty ? null : documentNumber,
        'document_photo': (documentPhoto == null || documentPhoto!.isEmpty) ? null : documentPhoto,
        'visitor_photos': visitorPhotos,
        'flat_number': flatNumber,
        'purpose': purpose,
        'entry_time': entryTime,
        'guard_id': guardId,
        'guard_name': guardName,
        'category': category,
        'company': (company == null || company!.isEmpty) ? null : company,
        'vehicle_number': (vehicleNumber == null || vehicleNumber!.isEmpty) ? null : vehicleNumber,
        'vehicle_entry_time': (vehicleEntryTime == null || vehicleEntryTime!.isEmpty) ? null : vehicleEntryTime,
      };

  GateVisitor copyWith({
    String? name,
    String? phone,
    String? documentType,
    String? documentNumber,
    List<String>? visitorPhotos,
    String? flatNumber,
    String? purpose,
    String? exitTime,
    String? vehicleExitTime,
    bool clearVehicleExit = false,
  }) =>
      GateVisitor(
        id: id,
        societyId: societyId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        documentType: documentType ?? this.documentType,
        documentNumber: documentNumber ?? this.documentNumber,
        documentPhoto: documentPhoto,
        visitorPhotos: visitorPhotos ?? this.visitorPhotos,
        flatNumber: flatNumber ?? this.flatNumber,
        purpose: purpose ?? this.purpose,
        entryTime: entryTime,
        exitTime: exitTime ?? this.exitTime,
        guardId: guardId,
        guardName: guardName,
        category: category,
        company: company,
        vehicleNumber: vehicleNumber,
        vehiclePhoto: vehiclePhoto,
        vehicleEntryTime: vehicleEntryTime,
        vehicleExitTime: clearVehicleExit ? null : (vehicleExitTime ?? this.vehicleExitTime),
        isBlacklisted: isBlacklisted,
      );
}

/// One `flats` row — web `Flat`.
class GateFlat {
  const GateFlat({
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

  factory GateFlat.fromRow(Map<String, dynamic> f) => GateFlat(
        id: asString(f['id']),
        flatNumber: asString(f['flat_number']),
        floor: _nonEmpty(f['floor']),
        wing: _nonEmpty(f['wing']),
        flatType: _nonEmpty(f['flat_type']) ?? 'residential',
        ownerName: _nonEmpty(f['owner_name']),
        ownerPhone: _nonEmpty(f['owner_phone']),
        intercom: _nonEmpty(f['intercom']),
        isOccupied: f['is_occupied'] is bool ? f['is_occupied'] as bool : true,
        ownerLivesHere: f['owner_lives_here'] is bool ? f['owner_lives_here'] as bool : true,
        tenantHouseholdType: _nonEmpty(f['tenant_household_type']),
      );
}

/// One `members` row — the fields the gate screens use (web `Member`).
class GateMember {
  const GateMember({
    required this.id,
    required this.flatId,
    required this.name,
    this.phone,
    this.relation = 'owner',
    this.photo,
    this.isPrimary = false,
    this.householdGroup,
  });

  final String id;
  final String flatId;
  final String name;
  final String? phone;

  /// Web maps a missing relation to `owner`.
  final String relation;
  final String? photo;
  final bool isPrimary;
  final String? householdGroup;

  factory GateMember.fromRow(Map<String, dynamic> m) => GateMember(
        id: asString(m['id']),
        flatId: asString(m['flat_id']),
        name: asString(m['name']),
        phone: _nonEmpty(m['phone']),
        relation: _nonEmpty(m['relation']) ?? 'owner',
        photo: _nonEmpty(m['photo']),
        isPrimary: m['is_primary'] == true,
        householdGroup: _nonEmpty(m['household_group']),
      );
}

/// One `resident_vehicles` row — web `ResidentVehicle`.
class GateResidentVehicle {
  const GateResidentVehicle({
    required this.id,
    this.societyId,
    required this.flatNumber,
    required this.residentName,
    required this.vehicleNumber,
    this.vehicleType = 'car',
    this.vehiclePhoto,
    this.flatId,
    this.memberId,
    this.vehicleColor,
    this.vehicleDisplayName,
  });

  final String id;
  final String? societyId;
  final String flatNumber;
  final String residentName;
  final String vehicleNumber;

  /// `car` | `bike` | `delivery` | `cycle` | `activa` | `auto` | `other`
  final String vehicleType;
  final String? vehiclePhoto;
  final String? flatId;
  final String? memberId;
  final String? vehicleColor;
  final String? vehicleDisplayName;

  factory GateResidentVehicle.fromRow(Map<String, dynamic> v) => GateResidentVehicle(
        id: asString(v['id']),
        societyId: _nonEmpty(v['society_id']),
        flatNumber: asString(v['flat_number']),
        residentName: asString(v['resident_name']),
        vehicleNumber: asString(v['vehicle_number']),
        vehicleType: _nonEmpty(v['vehicle_type']) ?? 'car',
        vehiclePhoto: _nonEmpty(v['vehicle_photo']),
        flatId: _nonEmpty(v['flat_id']),
        memberId: _nonEmpty(v['member_id']),
        vehicleColor: _nonEmpty(v['vehicle_color']),
        vehicleDisplayName: _nonEmpty(v['vehicle_display_name']),
      );
}
