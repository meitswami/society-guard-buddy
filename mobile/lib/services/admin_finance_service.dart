import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class AdminMaintenancePayment {
  const AdminMaintenancePayment({
    required this.id,
    required this.flatNumber,
    required this.residentName,
    required this.amount,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    this.chargeTitle,
    this.notes,
    this.transactionId,
  });

  final String id;
  final String flatNumber;
  final String? residentName;
  final double amount;
  final String paymentStatus;
  final String paymentMethod;
  final String createdAt;
  final String? chargeTitle;
  final String? notes;
  final String? transactionId;

  factory AdminMaintenancePayment.fromRow(
    Map<String, dynamic> row, {
    String? chargeTitle,
  }) =>
      AdminMaintenancePayment(
        id: row['id'] as String,
        flatNumber: row['flat_number'] as String,
        residentName: row['resident_name'] as String?,
        amount: (row['amount'] as num).toDouble(),
        paymentStatus: row['payment_status'] as String? ?? 'pending',
        paymentMethod: row['payment_method'] as String? ?? '',
        createdAt: row['created_at'] as String? ?? '',
        chargeTitle: chargeTitle,
        notes: row['notes'] as String?,
        transactionId: row['transaction_id'] as String?,
      );
}

class AdminFinanceService {
  Future<List<AdminMaintenancePayment>> fetchPayments(String societyId) async {
    if (!Env.isConfigured) return const [];

    final flats = await SupabaseBootstrap.client
        .from('flats')
        .select('id')
        .eq('society_id', societyId);
    final flatIds = (flats as List).map((f) => f['id'] as String).toList();
    if (flatIds.isEmpty) return const [];

    final rows = await SupabaseBootstrap.client
        .from('maintenance_payments')
        .select('*')
        .inFilter('flat_id', flatIds)
        .order('created_at', ascending: false)
        .limit(100);

    final chargeIds = (rows as List)
        .map((r) => r['charge_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final chargeTitles = <String, String>{};
    if (chargeIds.isNotEmpty) {
      final charges = await SupabaseBootstrap.client
          .from('maintenance_charges')
          .select('id, title')
          .inFilter('id', chargeIds);
      for (final c in charges as List) {
        chargeTitles[c['id'] as String] = c['title'] as String;
      }
    }

    return (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final chargeId = map['charge_id'] as String?;
      return AdminMaintenancePayment.fromRow(
        map,
        chargeTitle: chargeId != null ? chargeTitles[chargeId] : null,
      );
    }).toList();
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String adminName,
    required String societyId,
    required String flatNumber,
    required double amount,
    String? chargeTitle,
  }) async {
    if (!Env.isConfigured) return;

    final reviewedAt = DateTime.now().toIso8601String();
    await SupabaseBootstrap.client.from('maintenance_payments').update({
      'payment_status': 'verified',
      'verified_by': adminName,
      'verified_at': reviewedAt,
      'reviewed_at': reviewedAt,
      'rejection_reason': null,
    }).eq('id', paymentId);

    final title = 'Payment approved: ${chargeTitle ?? 'Maintenance'}';
    final message =
        'Your payment of ₹${amount.toStringAsFixed(0)} has been approved by $adminName.';
    await SupabaseBootstrap.client.from('notifications').insert({
      'society_id': societyId,
      'title': title,
      'message': message,
      'type': 'maintenance_payment_decision',
      'target_type': 'flat',
      'target_id': flatNumber,
      'created_by': adminName,
    });
  }

  Future<void> rejectPayment({
    required String paymentId,
    required String adminName,
    required String societyId,
    required String flatNumber,
    required String reason,
    String? chargeTitle,
  }) async {
    if (!Env.isConfigured) return;
    if (reason.trim().isEmpty) throw StateError('Rejection reason is required');

    final reviewedAt = DateTime.now().toIso8601String();
    await SupabaseBootstrap.client.from('maintenance_payments').update({
      'payment_status': 'rejected',
      'verified_by': adminName,
      'verified_at': reviewedAt,
      'reviewed_at': reviewedAt,
      'rejection_reason': reason.trim(),
    }).eq('id', paymentId);

    final title = 'Payment rejected: ${chargeTitle ?? 'Maintenance'}';
    final message = 'Your payment entry was rejected by $adminName. Reason: ${reason.trim()}';
    await SupabaseBootstrap.client.from('notifications').insert({
      'society_id': societyId,
      'title': title,
      'message': message,
      'type': 'maintenance_payment_decision',
      'target_type': 'flat',
      'target_id': flatNumber,
      'created_by': adminName,
    });
  }
}
