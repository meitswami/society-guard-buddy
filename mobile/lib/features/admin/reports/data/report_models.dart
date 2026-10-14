import '../logic/js_compat.dart';

/// Visitor log row as used by Reports / Logs (web `Visitor` from `useStore`).
class ReportVisitor {
  const ReportVisitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.purpose,
    required this.entryTime,
    this.exitTime,
    required this.guardId,
    required this.guardName,
    required this.category,
    this.company,
    this.vehicleNumber,
    this.vehicleEntryTime,
    this.vehicleExitTime,
    this.documentType = 'other',
    this.documentNumber = '',
    this.isBlacklisted = false,
  });

  final String id;
  final String name;
  final String phone;
  final String flatNumber;
  final String purpose;
  final String entryTime;
  final String? exitTime;
  final String guardId;
  final String guardName;
  final String category;
  final String? company;
  final String? vehicleNumber;
  final String? vehicleEntryTime;
  final String? vehicleExitTime;
  final String documentType;
  final String documentNumber;
  final bool isBlacklisted;

  /// Columns the report / log screens need (photos are not loaded).
  static const String selectColumns =
      'id, society_id, name, phone, document_type, document_number, flat_number, purpose, entry_time, exit_time, '
      'guard_id, guard_name, category, company, vehicle_number, vehicle_entry_time, vehicle_exit_time, is_blacklisted';

  factory ReportVisitor.fromJson(Map<String, dynamic> v) {
    String? opt(Object? x) {
      final s = x?.toString();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ReportVisitor(
      id: (v['id'] ?? '').toString(),
      name: (v['name'] ?? '').toString(),
      phone: (v['phone'] ?? '').toString(),
      flatNumber: (v['flat_number'] ?? '').toString(),
      purpose: (v['purpose'] ?? '').toString(),
      entryTime: (v['entry_time'] ?? '').toString(),
      exitTime: opt(v['exit_time']),
      guardId: (v['guard_id'] ?? '').toString(),
      guardName: (v['guard_name'] ?? '').toString(),
      category: (v['category'] ?? 'visitor').toString(),
      company: opt(v['company']),
      vehicleNumber: opt(v['vehicle_number']),
      vehicleEntryTime: opt(v['vehicle_entry_time']),
      vehicleExitTime: opt(v['vehicle_exit_time']),
      documentType: (v['document_type'] ?? 'other').toString(),
      documentNumber: (v['document_number'] ?? '').toString(),
      isBlacklisted: v['is_blacklisted'] == true,
    );
  }

  bool get isInside => exitTime == null || exitTime!.isEmpty;

  bool get hasVehicle => vehicleNumber != null && vehicleNumber!.isNotEmpty;

  ReportVisitor markedExit(String nowIso) => ReportVisitor(
        id: id,
        name: name,
        phone: phone,
        flatNumber: flatNumber,
        purpose: purpose,
        entryTime: entryTime,
        exitTime: nowIso,
        guardId: guardId,
        guardName: guardName,
        category: category,
        company: company,
        vehicleNumber: vehicleNumber,
        vehicleEntryTime: vehicleEntryTime,
        vehicleExitTime: hasVehicle ? nowIso : vehicleExitTime,
        documentType: documentType,
        documentNumber: documentNumber,
        isBlacklisted: isBlacklisted,
      );
}

/// `guard_shifts` row (web `ShiftRow` / `ReportShiftRow`).
class ReportShiftRow {
  const ReportShiftRow({
    required this.id,
    required this.guardId,
    required this.guardName,
    required this.loginTime,
    this.logoutTime,
  });

  final String id;
  final String guardId;
  final String guardName;
  final String loginTime;
  final String? logoutTime;

  factory ReportShiftRow.fromJson(Map<String, dynamic> j) => ReportShiftRow(
        id: (j['id'] ?? '').toString(),
        guardId: (j['guard_id'] ?? '').toString(),
        guardName: (j['guard_name'] ?? '').toString(),
        loginTime: (j['login_time'] ?? '').toString(),
        logoutTime:
            (j['logout_time'] == null || j['logout_time'].toString().isEmpty)
                ? null
                : j['logout_time'].toString(),
      );
}

/// `flats` row used by the finance reports.
class ReportFlat {
  const ReportFlat(
      {required this.id,
      required this.flatNumber,
      this.ownerName,
      this.isOccupied});

  final String id;
  final String flatNumber;
  final String? ownerName;
  final bool? isOccupied;

  factory ReportFlat.fromJson(Map<String, dynamic> j) => ReportFlat(
        id: (j['id'] ?? '').toString(),
        flatNumber: (j['flat_number'] ?? '').toString(),
        ownerName: j['owner_name']?.toString(),
        isOccupied: j['is_occupied'] is bool ? j['is_occupied'] as bool : null,
      );
}

/// `maintenance_charges` row (subset).
class ReportCharge {
  const ReportCharge(
      {required this.id,
      required this.title,
      this.amount = 0,
      this.expenseGroupId});

  final String id;
  final String title;
  final double amount;
  final String? expenseGroupId;

  factory ReportCharge.fromJson(Map<String, dynamic> j) => ReportCharge(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        amount: jsAmount(j['amount']),
        expenseGroupId: j['expense_group_id']?.toString(),
      );
}
