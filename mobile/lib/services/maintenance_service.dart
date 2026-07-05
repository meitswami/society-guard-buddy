import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/maintenance_models.dart';

class MaintenanceService {
  Future<List<MaintenanceCharge>> fetchCharges(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('maintenance_charges')
        .select('id, title, amount, due_day, frequency')
        .eq('society_id', societyId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => MaintenanceCharge.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<MaintenancePayment>> fetchPaymentsForFlat(String flatId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('maintenance_payments')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((r) => MaintenancePayment.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> submitPayment({
    required String chargeId,
    required String flatId,
    required String flatNumber,
    required String residentName,
    required String residentId,
    required double amount,
    required String paymentMethod,
    required String paidOnDate,
    required String dueDate,
    String? transactionId,
    String? notes,
  }) async {
    if (!Env.isConfigured) return;

    final paidAtIso = DateTime.parse('${paidOnDate}T12:00:00').toIso8601String();

    await SupabaseBootstrap.client.from('maintenance_payments').insert({
      'charge_id': chargeId,
      'flat_id': flatId,
      'flat_number': flatNumber,
      'resident_name': residentName,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_status': 'pending',
      'payment_date': paidAtIso,
      'due_date': dueDate,
      'transaction_id': transactionId?.trim().isEmpty == true ? null : transactionId?.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'submitted_by': 'resident',
      'submitted_by_user_id': residentId,
    });
  }
}
