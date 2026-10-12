// Finance → Record receipt: validation + allocation math of web `FinanceManager.recordPayment`
// (kept pure so the per-flat / outsider split rules are unit tested).

import 'finance_charge_helpers.dart';
import 'finance_dates.dart';
import 'finance_models.dart';
import 'flat_sort.dart';

const String kModeSocietyPool = 'society_pool';
const String kModeFlatsOnly = 'flats_only';
const String kModeFlatsPlusOutsider = 'flats_plus_outsider';
const String kModeOutsiderOnly = 'outsider_only';

const String kDestCurrentMonth = 'current_month_maintenance';
const String kDestCorpus = 'corpus';
const String kDestSeparate = 'separate_entry';

const String kAllocSamePerFlat = 'same_per_flat';
const String kAllocSplitTotal = 'split_total_equally';

/// JS `Number(str)`: blank → 0, invalid → NaN.
double jsNumber(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? double.nan;
}

/// Snapshot of the Record receipt form (web `payForm`).
class RecordReceiptInput {
  const RecordReceiptInput({
    this.recordMode = kModeFlatsOnly,
    this.destination = kDestCurrentMonth,
    this.allocationStyle = kAllocSamePerFlat,
    this.allocationIncludeVacant = false,
    this.outsiderName = '',
    this.outsiderRelation = '',
    this.outsiderAmount = '',
    this.entryTitle = '',
    this.chargeId = '',
    this.selectedFlats = const [],
    this.amount = '',
    this.paymentMethod = 'cash',
    this.transactionId = '',
    this.notes = '',
    required this.dueDate,
  });

  final String recordMode;
  final String destination;
  final String allocationStyle;
  final bool allocationIncludeVacant;
  final String outsiderName;
  final String outsiderRelation;
  final String outsiderAmount;
  final String entryTitle;
  final String chargeId;
  final List<String> selectedFlats;
  final String amount;
  final String paymentMethod;
  final String transactionId;
  final String notes;
  final String dueDate;
}

enum RecordReceiptIssue {
  /// Society pool without a positive total.
  poolAmountMissing,
  noFlatsSelected,

  /// Web returns without a message (flats only, missing charge or amount).
  silentAbort,
  outsiderNameMissing,
  outsiderAmountMissing,
  outsiderChargeMissing,
  chargeAndAmountMissing,
  outsiderNameAndAmountMissing,

  /// Receipt type names another month than the billing date.
  chargeMonthMismatch,

  /// Billing date not in the entry month (invalid date).
  entryMonthMismatch,
}

/// Sync checks done before the duplicate-receipt query and the receipt upload.
RecordReceiptIssue? validateRecordReceipt(RecordReceiptInput f, List<FinanceCharge> charges) {
  final mode = f.recordMode;
  final n = f.selectedFlats.length;
  if (mode == kModeSocietyPool) {
    final a = jsNumber(f.amount);
    if (f.amount.isEmpty || a.isNaN || a <= 0) return RecordReceiptIssue.poolAmountMissing;
  } else if (n == 0) {
    return RecordReceiptIssue.noFlatsSelected;
  }
  if (mode == kModeFlatsOnly) {
    if (f.amount.isEmpty || f.chargeId.isEmpty) return RecordReceiptIssue.silentAbort;
  }
  if (mode == kModeOutsiderOnly) {
    if (f.outsiderName.trim().isEmpty) return RecordReceiptIssue.outsiderNameMissing;
    if (f.outsiderAmount.isEmpty) return RecordReceiptIssue.outsiderAmountMissing;
    if (f.destination == kDestCurrentMonth && f.chargeId.isEmpty) return RecordReceiptIssue.outsiderChargeMissing;
  }
  if (mode == kModeFlatsPlusOutsider) {
    if (f.chargeId.isEmpty || f.amount.isEmpty) return RecordReceiptIssue.chargeAndAmountMissing;
    if (f.outsiderName.trim().isEmpty || f.outsiderAmount.isEmpty) return RecordReceiptIssue.outsiderNameAndAmountMissing;
  }
  if (needsReceiptHeadConflictCheck(f)) {
    final charge = _chargeById(charges, f.chargeId);
    if (charge != null && !chargeTitleMatchesBillingMonth(charge.title, f.dueDate)) {
      return RecordReceiptIssue.chargeMonthMismatch;
    }
  }
  return null;
}

/// Flats only / flats + outsider with a receipt type and flats → duplicate-month guard applies.
bool needsReceiptHeadConflictCheck(RecordReceiptInput f) =>
    (f.recordMode == kModeFlatsOnly || f.recordMode == kModeFlatsPlusOutsider) &&
    f.chargeId.isNotEmpty &&
    f.selectedFlats.isNotEmpty;

FinanceCharge? _chargeById(List<FinanceCharge> charges, String id) {
  for (final c in charges) {
    if (c.id == id) return c;
  }
  return null;
}

class AllocationInsert {
  const AllocationInsert({required this.flatNumber, required this.flatId, required this.amount});

  final String flatNumber;
  final String? flatId;
  final double amount;

  Map<String, dynamic> toRow(String financeEntryId) => {
        'finance_entry_id': financeEntryId,
        'flat_id': flatId,
        'flat_number': flatNumber,
        'amount': amount,
      };
}

/// Everything `persistFinanceRecord` inserts, plus values used for the notification / toast.
class RecordReceiptPlan {
  const RecordReceiptPlan({
    required this.entry,
    required this.counterparty,
    required this.allocations,
    required this.maintenancePayments,
    required this.totalAmount,
    required this.entryTitle,
    required this.entryMonth,
    required this.recordedCount,
  });

  final Map<String, dynamic> entry;
  final ({String name, String? relation})? counterparty;
  final List<AllocationInsert> allocations;
  final List<Map<String, dynamic>> maintenancePayments;
  final double totalAmount;
  final String entryTitle;
  final String entryMonth;
  final int recordedCount;
}

/// Result: a plan, or the issue (+ offending billing date for [RecordReceiptIssue.entryMonthMismatch]).
class RecordReceiptBuild {
  const RecordReceiptBuild.ok(RecordReceiptPlan this.plan)
      : issue = null,
        badDate = null;
  const RecordReceiptBuild.fail(RecordReceiptIssue this.issue, [this.badDate]) : plan = null;

  final RecordReceiptPlan? plan;
  final RecordReceiptIssue? issue;
  final String? badDate;
}

RecordReceiptBuild buildRecordReceiptPlan({
  required RecordReceiptInput f,
  required String societyId,
  required String adminName,
  required List<SocietyFlatRow> flats,
  required List<FinanceCharge> charges,
  required Map<String, String> primaryByFlatId,
  required String? screenshotUrl,
  DateTime? now,
}) {
  final mode = f.recordMode;
  final n = f.selectedFlats.length;
  final nowDt = (now ?? DateTime.now());
  final nowIso = nowDt.toUtc().toIso8601String();
  final recordingDate = todayRecordingDate(nowDt);
  final primaryBillingDate = f.dueDate;
  final entryMonth = billingMonthFromDate(primaryBillingDate, nowDt);
  if (!isBillingDateInEntryMonth(primaryBillingDate, entryMonth)) {
    return const RecordReceiptBuild.fail(RecordReceiptIssue.entryMonthMismatch);
  }
  final chargeTitle = _chargeById(charges, f.chargeId)?.title ?? '';

  SocietyFlatRow? flatByNumber(String fn) {
    for (final fl in flats) {
      if (fl.flatNumber == fn) return fl;
    }
    return null;
  }

  final poolFlats = [for (final fn in f.selectedFlats) (flatNumber: fn, flatId: flatByNumber(fn)?.id)];

  var allocationStyle = 'none';
  var totalAmount = 0.0;
  final allocations = <AllocationInsert>[];
  final mpRows = <Map<String, dynamic>>[];

  Map<String, dynamic> buildMpRow(String flatNumber, double amount, String? flatId) => {
        'charge_id': f.chargeId,
        'flat_id': flatId,
        'flat_number': flatNumber,
        'resident_name': residentLabelForFlatRow(flatId, flatByNumber(flatNumber)?.ownerName, primaryByFlatId),
        'amount': amount,
        'payment_method': f.paymentMethod,
        'payment_status': (f.paymentMethod == 'cash' || f.paymentMethod == 'upi') ? 'verified' : 'pending',
        'payment_date': nowIso,
        'due_date': f.dueDate,
        'recording_date': recordingDate,
        'transaction_id': f.transactionId.isEmpty ? null : f.transactionId,
        'screenshot_url': screenshotUrl,
        'notes': f.notes.isEmpty ? null : f.notes,
        'submitted_by': 'admin',
        'submitted_by_user_id': null,
        'verified_by': adminName,
        'verified_at': nowIso,
        'reviewed_at': nowIso,
        'rejection_reason': null,
      };

  if (mode == kModeSocietyPool) {
    allocationStyle = 'none';
    totalAmount = jsNumber(f.amount);
  }

  if (mode == kModeFlatsOnly) {
    final perFlat = jsNumber(f.amount);
    allocationStyle = n > 1 ? kAllocSamePerFlat : 'none';
    totalAmount = perFlat * n;
    for (final pf in poolFlats) {
      allocations.add(AllocationInsert(flatNumber: pf.flatNumber, flatId: pf.flatId, amount: perFlat));
      mpRows.add(buildMpRow(pf.flatNumber, perFlat, pf.flatId));
    }
  }

  if (mode == kModeOutsiderOnly) {
    final raw = jsNumber(f.outsiderAmount);
    final samePerFlat = f.allocationStyle == kAllocSamePerFlat;
    allocationStyle = samePerFlat ? kAllocSamePerFlat : kAllocSplitTotal;
    final perFlat = samePerFlat ? raw : raw / n;
    totalAmount = samePerFlat ? raw * n : raw;
    for (final pf in poolFlats) {
      allocations.add(AllocationInsert(flatNumber: pf.flatNumber, flatId: pf.flatId, amount: perFlat));
      if (f.destination == kDestCurrentMonth) mpRows.add(buildMpRow(pf.flatNumber, perFlat, pf.flatId));
    }
  }

  if (mode == kModeFlatsPlusOutsider) {
    final mAmt = jsNumber(f.amount);
    final rawOut = jsNumber(f.outsiderAmount);
    final samePerFlat = f.allocationStyle == kAllocSamePerFlat;
    allocationStyle = samePerFlat ? kAllocSamePerFlat : kAllocSplitTotal;
    final outsiderPerFlat = samePerFlat ? rawOut : rawOut / n;
    final outsiderTotal = samePerFlat ? rawOut * n : rawOut;
    totalAmount = mAmt * n + outsiderTotal;
    for (final pf in poolFlats) {
      allocations.add(AllocationInsert(flatNumber: pf.flatNumber, flatId: pf.flatId, amount: mAmt + outsiderPerFlat));
      final mpAmt = f.destination == kDestCurrentMonth ? mAmt + outsiderPerFlat : mAmt;
      mpRows.add(buildMpRow(pf.flatNumber, mpAmt, pf.flatId));
    }
  }

  final outsider = f.outsiderName.trim();
  final needsCounterparty =
      mode == kModeOutsiderOnly || mode == kModeFlatsPlusOutsider || (mode == kModeSocietyPool && outsider.isNotEmpty);
  final titleOverride = f.entryTitle.trim();
  final String entryTitle;
  if (mode == kModeSocietyPool) {
    entryTitle = titleOverride.isNotEmpty
        ? titleOverride
        : outsider.isNotEmpty
            ? 'Receipt: $outsider'
            : chargeTitle.isNotEmpty
                ? chargeTitle
                : 'Society pool receipt';
  } else if (mode == kModeOutsiderOnly) {
    entryTitle = titleOverride.isNotEmpty ? titleOverride : 'Outsider: $outsider';
  } else if (mode == kModeFlatsPlusOutsider) {
    entryTitle = titleOverride.isNotEmpty ? titleOverride : '$chargeTitle + outsider ($outsider)';
  } else {
    entryTitle = chargeTitle;
  }

  final String? chargeIdForEntry =
      mode == kModeOutsiderOnly && f.destination != kDestCurrentMonth ? null : (f.chargeId.isEmpty ? null : f.chargeId);
  final destForEntry = mode == kModeFlatsOnly
      ? kDestCurrentMonth
      : (mode == kModeSocietyPool && f.destination == kDestSeparate)
          ? kDestCorpus
          : f.destination;
  final aggregateFlatCount = mode == kModeSocietyPool ? 0 : n;

  final billingDates = [
    for (final r in mpRows) ((r['due_date'] as String?) ?? '').isEmpty ? primaryBillingDate : r['due_date'] as String,
  ];
  for (final d in billingDates) {
    if (!isBillingDateInEntryMonth(d, entryMonth)) return RecordReceiptBuild.fail(RecordReceiptIssue.entryMonthMismatch, d);
  }
  final transactionDate =
      billingDates.isEmpty ? primaryBillingDate : billingDates.reduce((a, b) => a.compareTo(b) < 0 ? a : b);

  final entry = <String, dynamic>{
    'society_id': societyId,
    'record_mode': mode,
    'destination': destForEntry,
    'allocation_style': allocationStyle,
    'include_vacant': f.allocationIncludeVacant,
    'entry_month': entryMonth,
    'transaction_date': transactionDate,
    'total_amount': totalAmount,
    'aggregate_flat_count': aggregateFlatCount,
    'charge_id': chargeIdForEntry,
    'title': entryTitle,
    'notes': f.notes.isEmpty ? null : f.notes,
    'screenshot_url': screenshotUrl,
    'transaction_id': f.transactionId.isEmpty ? null : f.transactionId,
    'payment_method': f.paymentMethod,
    'payment_status': 'verified',
    'created_by': adminName,
  };

  final relation = f.outsiderRelation.trim();
  return RecordReceiptBuild.ok(RecordReceiptPlan(
    entry: entry,
    counterparty: needsCounterparty ? (name: outsider, relation: relation.isEmpty ? null : relation) : null,
    allocations: allocations,
    maintenancePayments: mpRows,
    totalAmount: totalAmount,
    entryTitle: entryTitle,
    entryMonth: entryMonth,
    recordedCount: mode == kModeSocietyPool ? 1 : (mpRows.isNotEmpty ? mpRows.length : n),
  ));
}

/// Per-flat amounts for "Distribute equally to all flats" (last flat takes the rounding remainder).
List<double> distributePoolAmounts(double total, int flatCount) {
  if (flatCount <= 0) return const [];
  final perFlat = double.parse((total / flatCount).toStringAsFixed(2));
  final out = <double>[];
  var allocated = 0.0;
  for (var i = 0; i < flatCount; i++) {
    final isLast = i == flatCount - 1;
    final amount = isLast ? double.parse((total - allocated).toStringAsFixed(2)) : perFlat;
    allocated += amount;
    out.add(amount);
  }
  return out;
}
