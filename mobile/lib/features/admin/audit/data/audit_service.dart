import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/supabase/db.dart';
import '../logic/finance_audit_detection.dart';
import '../logic/integrity_audit_engine.dart';

/// Security audit log row (`audit_logs`).
class AuditLog {
  const AuditLog({
    required this.id,
    required this.createdAt,
    required this.eventType,
    required this.userType,
    this.userId,
    this.userName,
    this.ipAddress,
    this.userAgent,
    required this.deviceInfo,
    required this.details,
    required this.severity,
  });

  final String id;
  final String createdAt;
  final String eventType;
  final String userType;
  final String? userId;
  final String? userName;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> details;
  final String severity;

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: (j['id'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        eventType: (j['event_type'] ?? '').toString(),
        userType: (j['user_type'] ?? '').toString(),
        userId: j['user_id']?.toString(),
        userName: j['user_name']?.toString(),
        ipAddress: j['ip_address']?.toString(),
        userAgent: j['user_agent']?.toString(),
        deviceInfo: _map(j['device_info']),
        details: _map(j['details']),
        severity: (j['severity'] ?? 'info').toString(),
      );
}

class ChargeOption {
  const ChargeOption(this.id, this.title);
  final String id;
  final String title;
}

/// Result of a remediation call (web `{ ok, error }`).
class FixResult {
  const FixResult.ok()
      : ok = true,
        error = null;
  const FixResult.fail(this.error) : ok = false;
  final bool ok;
  final String? error;
}

/// Readable error text (Supabase `error.message` like the web toast).
String auditErrText(Object e) =>
    e is PostgrestException ? e.message : e.toString();

String _errText(Object e) => auditErrText(e);

const _paymentCols =
    'id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status, transaction_id, notes, finance_entry_id';

/// Queries and fixes used by the Audit module — identical to the web components.
class AuditService {
  const AuditService();

  Future<List<AuditLog>> fetchLogs(String societyId,
      {String filter = 'all'}) async {
    if (!dbReady) return const [];
    var q = db.from('audit_logs').select('*').eq('society_id', societyId);
    if (filter != 'all') q = q.eq('event_type', filter);
    final data = await q.order('created_at', ascending: false).limit(200);
    return rowsOf(data).map(AuditLog.fromJson).toList();
  }

  /// FinanceAuditAlarms: charges (ordered by title) + verified/pending payments.
  Future<({List<ChargeOption> charges, List<AuditPaymentRow> payments})>
      fetchAlarmData(String societyId) async {
    if (!dbReady)
      return (
        charges: const <ChargeOption>[],
        payments: const <AuditPaymentRow>[]
      );
    final charges = rowsOf(await db
            .from('maintenance_charges')
            .select('id, title')
            .eq('society_id', societyId)
            .order('title'))
        .map((c) => ChargeOption(
            (c['id'] ?? '').toString(), (c['title'] ?? '').toString()))
        .toList();
    if (charges.isEmpty)
      return (charges: charges, payments: const <AuditPaymentRow>[]);
    final payments = rowsOf(await db
            .from('maintenance_payments')
            .select(_paymentCols)
            .inFilter('charge_id', charges.map((c) => c.id).toList())
            .inFilter('payment_status', ['verified', 'pending']))
        .map(AuditPaymentRow.fromJson)
        .toList();
    return (charges: charges, payments: payments);
  }

  /// FinanceLedgerOvercountPanel inputs (verified payments + all ledger rows, no transaction_date — like web).
  Future<({List<AuditPaymentRow> payments, List<AuditLedgerRow> ledger})>
      fetchOvercountData(String societyId) async {
    if (!dbReady)
      return (
        payments: const <AuditPaymentRow>[],
        ledger: const <AuditLedgerRow>[]
      );
    final chargeIds = rowsOf(await db
            .from('maintenance_charges')
            .select('id')
            .eq('society_id', societyId))
        .map((c) => (c['id'] ?? '').toString())
        .toList();
    final payments = chargeIds.isEmpty
        ? <AuditPaymentRow>[]
        : rowsOf(await db
                .from('maintenance_payments')
                .select(
                    'id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id')
                .inFilter('charge_id', chargeIds)
                .eq('payment_status', 'verified'))
            .map(AuditPaymentRow.fromJson)
            .toList();
    final ledger = rowsOf(await db
            .from('finance_entries')
            .select(
                'id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title')
            .eq('society_id', societyId))
        .map(AuditLedgerRow.fromJson)
        .toList();
    return (payments: payments, ledger: ledger);
  }

  Future<List<AuditChargeRow>> _charges(String societyId) async =>
      rowsOf(await db
              .from('maintenance_charges')
              .select('id, title, amount, frequency')
              .eq('society_id', societyId))
          .map(AuditChargeRow.fromJson)
          .toList();

  /// FinanceIntegrityAudit `runAudit` loads.
  Future<IntegrityAuditInput> fetchIntegrityInput(String societyId) async {
    final charges = await _charges(societyId);
    final chargeIds = charges.map((c) => c.id).toList();
    final payments = chargeIds.isEmpty
        ? <AuditPaymentRow>[]
        : rowsOf(await db
                .from('maintenance_payments')
                .select(
                    'id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id, transaction_id')
                .inFilter('charge_id', chargeIds))
            .map(AuditPaymentRow.fromJson)
            .toList();
    final ledger = rowsOf(await db
            .from('finance_entries')
            .select(
                'id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title, charge_id, aggregate_flat_count')
            .eq('society_id', societyId))
        .map(AuditLedgerRow.fromJson)
        .toList();
    final flats = rowsOf(await db
            .from('flats')
            .select('id, flat_number, is_occupied')
            .eq('society_id', societyId))
        .map(AuditFlatRow.fromJson)
        .toList();
    return IntegrityAuditInput(
        charges: charges, payments: payments, ledger: ledger, flats: flats);
  }

  /// ManualAuditTracer `trace` loads.
  Future<
      ({
        List<AuditChargeRow> charges,
        List<AuditPaymentRow> payments,
        List<AuditLedgerRow> ledger
      })> fetchTraceInput(String societyId) async {
    final charges = await _charges(societyId);
    final chargeIds = charges.map((c) => c.id).toList();
    final payments = chargeIds.isEmpty
        ? <AuditPaymentRow>[]
        : rowsOf(await db
                .from('maintenance_payments')
                .select(
                    'id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id')
                .inFilter('charge_id', chargeIds))
            .map(AuditPaymentRow.fromJson)
            .toList();
    final ledger = rowsOf(await db
            .from('finance_entries')
            .select(
                'id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title, aggregate_flat_count')
            .eq('society_id', societyId))
        .map(AuditLedgerRow.fromJson)
        .toList();
    return (charges: charges, payments: payments, ledger: ledger);
  }

  /* ─── Remediation (financeAuditRemediation.ts) ─── */

  Future<FixResult> updatePayment(String id,
      {required double amount,
      required String method,
      required String status,
      String? notes}) async {
    try {
      await db.from('maintenance_payments').update({
        'amount': amount,
        'payment_method': method,
        'payment_status': status,
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      }).eq('id', id);
      return const FixResult.ok();
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
  }

  Future<void> _deleteLedgerRow(String entryId) async {
    await db
        .from('finance_entry_allocations')
        .delete()
        .eq('finance_entry_id', entryId);
    await db
        .from('finance_entry_counterparties')
        .delete()
        .eq('finance_entry_id', entryId);
    await db.from('finance_entries').delete().eq('id', entryId);
  }

  /// Deletes the payment; removes its ledger entry (+ allocations / counterparties) when no payment remains linked.
  Future<FixResult> deleteMaintenancePayment(
      String paymentId, String? financeEntryId) async {
    try {
      await db.from('maintenance_payments').delete().eq('id', paymentId);
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
    if (financeEntryId != null && financeEntryId.isNotEmpty) {
      try {
        final remaining = rowsOf(await db
            .from('maintenance_payments')
            .select('id')
            .eq('finance_entry_id', financeEntryId));
        if (remaining.isEmpty) await _deleteLedgerRow(financeEntryId);
      } catch (_) {
        // Like the web, cleanup failures do not fail the delete. (A failed lookup skips cleanup for safety.)
      }
    }
    return const FixResult.ok();
  }

  Future<FixResult> deleteOrphanLedgerEntry(String entryId,
      {bool hi = false}) async {
    try {
      final linked = rowsOf(await db
          .from('maintenance_payments')
          .select('id')
          .eq('finance_entry_id', entryId));
      if (linked.isNotEmpty) {
        return FixResult.fail(hi
            ? 'इस लेजर प्रविष्टि से अभी भी भुगतान जुड़े हैं। पहले भुगतान हटाएँ या फिर से जोड़ें।'
            : 'This ledger entry still has linked payments. Remove or relink payments first.');
      }
      await db
          .from('finance_entry_allocations')
          .delete()
          .eq('finance_entry_id', entryId);
      await db
          .from('finance_entry_counterparties')
          .delete()
          .eq('finance_entry_id', entryId);
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
    try {
      await db.from('finance_entries').delete().eq('id', entryId);
      return const FixResult.ok();
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
  }

  Future<FixResult> alignPaymentDueToMonth(
      String paymentId, String yyyyMm) async {
    try {
      await db
          .from('maintenance_payments')
          .update({'due_date': '$yyyyMm-01'}).eq('id', paymentId);
      return const FixResult.ok();
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
  }

  Future<FixResult> alignLedgerEntryMonth(String entryId, String yyyyMm) async {
    try {
      await db
          .from('finance_entries')
          .update({'entry_month': yyyyMm}).eq('id', entryId);
      return const FixResult.ok();
    } catch (e) {
      return FixResult.fail(_errText(e));
    }
  }

  /// `queryReceiptHeadConflicts` — used by Finance before recording a receipt.
  Future<List<AuditPaymentRow>> queryReceiptHeadConflicts({
    required String chargeId,
    String? paymentMethod,
    required List<({String flatNumber, String dueDate})> targets,
    List<String> monthlyMaintenanceChargeIds = const [],
  }) async {
    final flatNumbers = targets.map((t) => t.flatNumber).toSet().toList();
    if (flatNumbers.isEmpty || chargeId.isEmpty) return const [];
    final isMonthly = monthlyMaintenanceChargeIds.contains(chargeId);
    final chargeIds =
        isMonthly ? monthlyMaintenanceChargeIds.toSet().toList() : [chargeId];
    try {
      final rows = rowsOf(await db
              .from('maintenance_payments')
              .select(_paymentCols)
              .inFilter('charge_id', chargeIds)
              .inFilter('flat_number', flatNumbers)
              .inFilter('payment_status', ['verified', 'pending']))
          .map(AuditPaymentRow.fromJson)
          .toList();
      if (isMonthly)
        return findMonthlyMaintenanceMonthConflicts(rows, chargeIds, targets);
      return findReceiptHeadConflicts(rows, [
        for (final t in targets)
          ReceiptHeadRecordingTarget(
              flatNumber: t.flatNumber,
              dueDate: t.dueDate,
              chargeId: chargeId,
              paymentMethod: paymentMethod),
      ]);
    } catch (_) {
      return const [];
    }
  }
}
