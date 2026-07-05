class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.visitorName,
    required this.visitorPhone,
    required this.flatNumber,
    required this.guardName,
    required this.purpose,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String visitorName;
  final String? visitorPhone;
  final String flatNumber;
  final String guardName;
  final String? purpose;
  final String status;
  final DateTime createdAt;

  factory ApprovalRequest.fromRow(Map<String, dynamic> row) => ApprovalRequest(
        id: row['id'] as String,
        visitorName: row['visitor_name'] as String? ?? 'Visitor',
        visitorPhone: row['visitor_phone'] as String?,
        flatNumber: row['flat_number'] as String? ?? '',
        guardName: row['guard_name'] as String? ?? '',
        purpose: row['purpose'] as String?,
        status: row['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
