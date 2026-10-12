/// Row models for the resident area (same tables / columns as `ResidentDashboard.tsx`).
library;

String _s(Object? v) => v == null ? '' : v.toString();
String? _ns(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int? _ni(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// `approval_requests` row (guard asks the flat to approve a visitor).
class ApprovalRequestRow {
  const ApprovalRequestRow({
    required this.id,
    required this.visitorName,
    required this.flatNumber,
    required this.guardName,
    required this.status,
    required this.createdAt,
    this.visitorPhone,
    this.purpose,
    this.visitorPhoto,
  });

  final String id;
  final String visitorName;
  final String? visitorPhone;
  final String flatNumber;
  final String guardName;
  final String? purpose;
  final String? visitorPhoto;
  final String status;
  final String createdAt;

  bool get isPending => status == 'pending';

  factory ApprovalRequestRow.fromJson(Map<String, dynamic> r) => ApprovalRequestRow(
        id: _s(r['id']),
        visitorName: _s(r['visitor_name']),
        visitorPhone: _ns(r['visitor_phone']),
        flatNumber: _s(r['flat_number']),
        guardName: _s(r['guard_name']),
        purpose: _ns(r['purpose']),
        visitorPhoto: _ns(r['visitor_photo']),
        status: _s(r['status']).isEmpty ? 'pending' : _s(r['status']),
        createdAt: _s(r['created_at']),
      );
}

/// `visitor_passes` row (OTP pre-approval created by the resident).
class VisitorPassRow {
  const VisitorPassRow({
    required this.id,
    required this.otpCode,
    required this.flatNumber,
    required this.validDate,
    required this.status,
    required this.createdByName,
    required this.createdAt,
    this.guestName,
    this.guestPhone,
    this.timeSlotStart,
    this.timeSlotEnd,
    this.usedAt,
  });

  final String id;
  final String otpCode;
  final String flatNumber;
  final String? guestName;
  final String? guestPhone;
  final String validDate;
  final String? timeSlotStart;
  final String? timeSlotEnd;
  final String status;
  final String createdByName;
  final String createdAt;
  final String? usedAt;

  bool get isActive => status == 'active';

  factory VisitorPassRow.fromJson(Map<String, dynamic> r) => VisitorPassRow(
        id: _s(r['id']),
        otpCode: _s(r['otp_code']),
        flatNumber: _s(r['flat_number']),
        guestName: _ns(r['guest_name']),
        guestPhone: _ns(r['guest_phone']),
        validDate: _s(r['valid_date']),
        timeSlotStart: _ns(r['time_slot_start']),
        timeSlotEnd: _ns(r['time_slot_end']),
        status: _s(r['status']).isEmpty ? 'active' : _s(r['status']),
        createdByName: _s(r['created_by_name']),
        createdAt: _s(r['created_at']),
        usedAt: _ns(r['used_at']),
      );
}

/// `members` row (family, tenants, staff of the flat). [raw] keeps every column for the edit form.
class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.flatId,
    required this.name,
    required this.raw,
    this.phone,
    this.relation,
    this.age,
    this.gender,
    this.photo,
    this.isPrimary = false,
    this.householdGroup,
  });

  final String id;
  final String flatId;
  final String name;
  final String? phone;
  final String? relation;
  final int? age;
  final String? gender;
  final String? photo;
  final bool isPrimary;
  final String? householdGroup;
  final Map<String, dynamic> raw;

  factory HouseholdMember.fromJson(Map<String, dynamic> r) => HouseholdMember(
        id: _s(r['id']),
        flatId: _s(r['flat_id']),
        name: _s(r['name']),
        phone: _ns(r['phone']),
        relation: _ns(r['relation']),
        age: _ni(r['age']),
        gender: _ns(r['gender']),
        photo: _ns(r['photo']),
        isPrimary: r['is_primary'] == true,
        householdGroup: _ns(r['household_group']),
        raw: Map<String, dynamic>.from(r),
      );
}

/// `resident_users` row of the flat (shared-password logins).
class FlatmateLogin {
  const FlatmateLogin({required this.id, required this.name, required this.phone, this.mustChangePassword = false});

  final String id;
  final String name;
  final String phone;
  final bool mustChangePassword;

  factory FlatmateLogin.fromJson(Map<String, dynamic> r) => FlatmateLogin(
        id: _s(r['id']),
        name: _s(r['name']),
        phone: _s(r['phone']),
        mustChangePassword: r['must_change_password'] == true,
      );
}

/// `resident_vehicles` row.
class ResidentVehicleRow {
  const ResidentVehicleRow({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.residentName,
    required this.flatNumber,
    this.flatId,
    this.memberId,
    this.displayName,
    this.color,
  });

  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String residentName;
  final String flatNumber;
  final String? flatId;
  final String? memberId;
  final String? displayName;
  final String? color;

  factory ResidentVehicleRow.fromJson(Map<String, dynamic> r) => ResidentVehicleRow(
        id: _s(r['id']),
        vehicleNumber: _s(r['vehicle_number']),
        vehicleType: _s(r['vehicle_type']),
        residentName: _s(r['resident_name']),
        flatNumber: _s(r['flat_number']),
        flatId: _ns(r['flat_id']),
        memberId: _ns(r['member_id']),
        displayName: _ns(r['vehicle_display_name']),
        color: _ns(r['vehicle_color']),
      );
}

/// `maintenance_charges` row (society charge heads residents pay against).
class MaintenanceChargeRow {
  const MaintenanceChargeRow({
    required this.id,
    required this.title,
    required this.amount,
    this.dueDay = 1,
    this.frequency = 'monthly',
    this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String title;
  final double amount;
  final int dueDay;
  final String frequency;
  final String? createdAt;
  final bool isActive;

  factory MaintenanceChargeRow.fromJson(Map<String, dynamic> r) => MaintenanceChargeRow(
        id: _s(r['id']),
        title: _s(r['title']),
        amount: _d(r['amount']),
        dueDay: _ni(r['due_day']) ?? 1,
        frequency: _s(r['frequency']),
        createdAt: _ns(r['created_at']),
        isActive: r['is_active'] != false,
      );
}

/// `maintenance_payments` row submitted by the flat (verified by admin).
class MaintenancePaymentRow {
  const MaintenancePaymentRow({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.dueDate,
    required this.flatNumber,
    required this.createdAt,
    this.chargeId,
    this.paymentDate,
    this.transactionId,
    this.screenshotUrl,
    this.notes,
    this.rejectionReason,
    this.receiptNumber,
    this.residentName,
    this.verifiedBy,
    this.verifiedAt,
  });

  final String id;
  final String? chargeId;
  final double amount;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentDate;
  final String dueDate;
  final String? transactionId;
  final String? screenshotUrl;
  final String? notes;
  final String? rejectionReason;
  final String? receiptNumber;
  final String flatNumber;
  final String? residentName;
  final String? verifiedBy;
  final String? verifiedAt;
  final String createdAt;

  bool get isVerified => paymentStatus == 'verified';

  factory MaintenancePaymentRow.fromJson(Map<String, dynamic> r) => MaintenancePaymentRow(
        id: _s(r['id']),
        chargeId: _ns(r['charge_id']),
        amount: _d(r['amount']),
        paymentMethod: _s(r['payment_method']),
        paymentStatus: _s(r['payment_status']).isEmpty ? 'pending' : _s(r['payment_status']),
        paymentDate: _ns(r['payment_date']),
        dueDate: _s(r['due_date']),
        transactionId: _ns(r['transaction_id']),
        screenshotUrl: _ns(r['screenshot_url']),
        notes: _ns(r['notes']),
        rejectionReason: _ns(r['rejection_reason']),
        receiptNumber: _ns(r['receipt_number']),
        flatNumber: _s(r['flat_number']),
        residentName: _ns(r['resident_name']),
        verifiedBy: _ns(r['verified_by']),
        verifiedAt: _ns(r['verified_at']),
        createdAt: _s(r['created_at']),
      );
}

/// `society_bank_accounts` row (web `SocietyBankAccount`).
class SocietyBankAccountRow {
  const SocietyBankAccountRow({
    required this.id,
    required this.societyId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifsc,
    this.branchName,
    this.upiVpa,
  });

  final String id;
  final String societyId;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifsc;
  final String? branchName;
  final String? upiVpa;

  bool get hasUpi => (upiVpa ?? '').trim().isNotEmpty;

  factory SocietyBankAccountRow.fromJson(Map<String, dynamic> r) => SocietyBankAccountRow(
        id: _s(r['id']),
        societyId: _s(r['society_id']),
        bankName: _s(r['bank_name']),
        accountHolderName: _s(r['account_holder_name']),
        accountNumber: _s(r['account_number']),
        ifsc: _s(r['ifsc']),
        branchName: _ns(r['branch_name']),
        upiVpa: _ns(r['upi_vpa']),
      );
}

/// `society_dashboard_banners` row shown once per app session after login.
class DashboardBanner {
  const DashboardBanner({required this.id, required this.imageUrl, this.title});

  final String id;
  final String imageUrl;
  final String? title;

  factory DashboardBanner.fromJson(Map<String, dynamic> r) =>
      DashboardBanner(id: _s(r['id']), imageUrl: _s(r['image_url']), title: _ns(r['title']));
}
