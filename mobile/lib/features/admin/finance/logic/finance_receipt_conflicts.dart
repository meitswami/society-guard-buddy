// Receipt double-entry guards — port of the receipt-head helpers in
// `src/lib/financeAuditDetection.ts` (+ `financeReceiptConflicts.test.ts`).

import 'finance_dates.dart';
import 'finance_models.dart';

/// Same flat + charge + calendar month (verified or pending). Channel must not allow a second receipt.
String paymentDuplicateGroupKey(FinancePayment p) {
  final dateStr = paymentBillingDate(p.dueDate);
  String month = 'unknown';
  if (dateStr.isNotEmpty) {
    final d = parseYmd(dateStr) ?? parseIsoLoose(dateStr);
    month = d == null ? 'unknown' : ymOf(d);
  }
  return '${p.flatNumber}||${p.chargeId ?? ''}||$month';
}

/// Same flat + billing month for any monthly-maintenance charge.
String monthlyMaintenanceMonthKey(String flatNumber, String dueDateYmd) {
  final m = dueDateYmd.length > 7 ? dueDateYmd.substring(0, 7) : dueDateYmd;
  return '$flatNumber||$m';
}

class ReceiptHeadRecordingTarget {
  const ReceiptHeadRecordingTarget(
      {required this.flatNumber,
      required this.dueDate,
      required this.chargeId,
      this.paymentMethod});

  final String flatNumber;
  final String dueDate;
  final String chargeId;
  final String? paymentMethod;
}

/// Key used to block a new payment when the receipt head is already recorded (channel ignored).
String receiptHeadKeyFromRecording(
    String flatNumber, String chargeId, String dueDate,
    [String? paymentMethod]) {
  final month = dueDate.length > 7 ? dueDate.substring(0, 7) : dueDate;
  return '$flatNumber||$chargeId||$month';
}

bool _isActiveStatus(String s) => s == 'verified' || s == 'pending';

/// Verified/pending payments that already occupy the same receipt head slot.
List<FinancePayment> findReceiptHeadConflicts(
  List<FinancePayment> existingPayments,
  List<ReceiptHeadRecordingTarget> targets,
) {
  final targetKeys = {
    for (final t in targets)
      receiptHeadKeyFromRecording(
          t.flatNumber, t.chargeId, t.dueDate, t.paymentMethod),
  };
  final seen = <String>{};
  final conflicts = <FinancePayment>[];
  for (final p in existingPayments) {
    if (!_isActiveStatus(p.paymentStatus)) continue;
    final key = paymentDuplicateGroupKey(p);
    if (!targetKeys.contains(key) || seen.contains(p.id)) continue;
    seen.add(p.id);
    conflicts.add(p);
  }
  return conflicts;
}

/// Block a second monthly-maintenance receipt for the same flat + billing month
/// across all monthly maintenance charge types (cash/UPI/title variants).
List<FinancePayment> findMonthlyMaintenanceMonthConflicts(
  List<FinancePayment> existingPayments,
  Iterable<String> monthlyChargeIds,
  List<({String flatNumber, String dueDate})> targets,
) {
  final monthlyIds = monthlyChargeIds.toSet();
  if (monthlyIds.isEmpty || targets.isEmpty) return const [];
  final targetKeys = {
    for (final t in targets) monthlyMaintenanceMonthKey(t.flatNumber, t.dueDate)
  };
  final seen = <String>{};
  final conflicts = <FinancePayment>[];
  for (final p in existingPayments) {
    if (!_isActiveStatus(p.paymentStatus)) continue;
    if (!monthlyIds.contains(p.chargeId)) continue;
    final dateStr = paymentBillingDate(p.dueDate);
    if (dateStr.isEmpty) continue;
    final key = monthlyMaintenanceMonthKey(p.flatNumber, dateStr);
    if (!targetKeys.contains(key) || seen.contains(p.id)) continue;
    seen.add(p.id);
    conflicts.add(p);
  }
  return conflicts;
}
