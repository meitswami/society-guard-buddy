class MaintenanceCharge {
  const MaintenanceCharge({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDay,
    required this.frequency,
  });

  final String id;
  final String title;
  final double amount;
  final int dueDay;
  final String frequency;

  factory MaintenanceCharge.fromRow(Map<String, dynamic> row) =>
      MaintenanceCharge(
        id: row['id'] as String,
        title: row['title'] as String? ?? 'Maintenance',
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        dueDay: row['due_day'] as int? ?? 1,
        frequency: row['frequency'] as String? ?? 'monthly',
      );
}

class MaintenancePayment {
  const MaintenancePayment({
    required this.id,
    required this.amount,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentDate,
    required this.dueDate,
    required this.transactionId,
    this.receiptNumber,
  });

  final String id;
  final double amount;
  final String paymentStatus;
  final String paymentMethod;
  final String? paymentDate;
  final String dueDate;
  final String? transactionId;
  final String? receiptNumber;

  factory MaintenancePayment.fromRow(Map<String, dynamic> row) =>
      MaintenancePayment(
        id: row['id'] as String,
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        paymentStatus: row['payment_status'] as String? ?? 'pending',
        paymentMethod: row['payment_method'] as String? ?? '',
        paymentDate: row['payment_date'] as String?,
        dueDate: row['due_date'] as String? ?? '',
        transactionId: row['transaction_id'] as String?,
        receiptNumber: row['receipt_number'] as String?,
      );
}
