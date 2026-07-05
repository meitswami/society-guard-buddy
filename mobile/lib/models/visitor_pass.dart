class VisitorPass {
  const VisitorPass({
    required this.id,
    required this.otpCode,
    required this.flatNumber,
    required this.guestName,
    required this.guestPhone,
    required this.validDate,
    required this.timeSlotStart,
    required this.timeSlotEnd,
    required this.status,
    required this.createdByName,
    required this.createdAt,
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
  final DateTime createdAt;

  factory VisitorPass.fromRow(Map<String, dynamic> row) => VisitorPass(
        id: row['id'] as String,
        otpCode: row['otp_code'] as String? ?? '',
        flatNumber: row['flat_number'] as String? ?? '',
        guestName: row['guest_name'] as String?,
        guestPhone: row['guest_phone'] as String?,
        validDate: row['valid_date']?.toString() ?? '',
        timeSlotStart: row['time_slot_start'] as String?,
        timeSlotEnd: row['time_slot_end'] as String?,
        status: row['status'] as String? ?? 'active',
        createdByName: row['created_by_name'] as String? ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
