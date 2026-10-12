// Derived lookups FinanceManager memoises on every load (charge maps, major heads, unpaid flats …).

import 'finance_charge_helpers.dart';
import 'finance_expense_head.dart';
import 'finance_ledger_display.dart';
import 'finance_models.dart';
import 'finance_period_report.dart';
import 'flat_sort.dart';

/// Row of the unpaid-flats grid (web `UnpaidFlatGridRow`).
class UnpaidFlatGridRow {
  const UnpaidFlatGridRow({
    required this.flatNumber,
    required this.primaryName,
    required this.isOccupied,
    required this.pendingPayment,
    required this.dueAmount,
    required this.chargeTitle,
  });

  final String flatNumber;
  final String primaryName;
  final bool? isOccupied;

  /// `pending` | `rejected` | null
  final String? pendingPayment;
  final double? dueAmount;
  final String? chargeTitle;
}

class FinanceDerived {
  FinanceDerived(this.data)
      : chargeById = {for (final c in data.charges) if (c.id.isNotEmpty) c.id: c},
        paymentGroupById = {for (final g in data.paymentExpenseGroups) g.id: g},
        financeEntryById = {for (final e in data.ledgerEntries) e.id: e},
        financeEntryIdsWithPayments = {
          for (final p in data.payments)
            if (p.financeEntryId != null && p.financeEntryId!.isNotEmpty) p.financeEntryId!,
        },
        societyLedgerEntries = filterSocietyLedgerEntries(data.ledgerEntries, data.expenseCategoryById),
        monthlyMaintenanceChargeIds = {
          for (final c in data.charges)
            if (isMonthlyMaintenanceCharge(c)) c.id,
        },
        chargeIdsWithDependents = {
          for (final p in data.payments)
            if (p.chargeId != null && p.chargeId!.isNotEmpty) p.chargeId!,
          for (final e in data.ledgerEntries)
            if (e.chargeId != null && e.chargeId!.isNotEmpty) e.chargeId!,
        },
        groupIdsInUse = {
          for (final c in data.charges)
            if (c.expenseGroupId != null && c.expenseGroupId!.isNotEmpty) c.expenseGroupId!,
        };

  final FinanceCoreData data;
  final Map<String, FinanceCharge> chargeById;
  final Map<String, PaymentExpenseGroup> paymentGroupById;
  final Map<String, FinanceLedgerRow> financeEntryById;
  final Set<String> financeEntryIdsWithPayments;

  /// Finance module ledger — excludes event food (reconciled under Events & food).
  final List<FinanceLedgerRow> societyLedgerEntries;
  final Set<String> monthlyMaintenanceChargeIds;
  final Set<String> chargeIdsWithDependents;
  final Set<String> groupIdsInUse;

  Map<String, String> get chargeTitleById => {for (final e in chargeById.entries) e.key: e.value.title};

  /// Major head for a receipt type (linked sub-head, else inferred from the title).
  String majorHeadForCharge(FinanceCharge c) {
    final g = (c.expenseGroupId != null && c.expenseGroupId!.isNotEmpty) ? paymentGroupById[c.expenseGroupId] : null;
    if (g != null) return resolveGroupMajorHeadOf(g);
    return inferMajorHeadFromGroupName(c.title);
  }

  /// Charges bucketed by major head (+ `Uncategorized`), in charge order.
  Map<String, List<FinanceCharge>> get chargesByMajorHead {
    final map = <String, List<FinanceCharge>>{for (final h in kSocietyPaymentMajorHeads) h: [], kUncategorizedHead: []};
    for (final c in data.charges) {
      (map[majorHeadForCharge(c)] ?? map[kUncategorizedHead]!).add(c);
    }
    return map;
  }

  List<PaymentExpenseGroup> subHeadsForMajor(String major) {
    if (major.isEmpty) return const [];
    return data.paymentExpenseGroups.where((g) => resolveGroupMajorHeadOf(g) == major).toList();
  }

  Map<String, List<PaymentExpenseGroup>> get paymentGroupsByMajorHeadMap {
    final grouped = paymentGroupsByMajorHead(data.paymentExpenseGroups);
    return {for (final h in kSocietyPaymentMajorHeads) h: grouped[h] ?? [], kUncategorizedHead: []};
  }

  bool isSocietyPaymentLedgerEntry(FinanceLedgerRow e) {
    final id = e.expenseId;
    if (id == null || id.isEmpty) return false;
    return data.expenseCategoryById[id] != 'food';
  }

  /// Receipt-side head for a ledger-only row.
  String ledgerReceiptHead(FinanceLedgerRow e) {
    final ch = e.chargeId != null ? chargeById[e.chargeId] : null;
    if (ch != null) return majorHeadForCharge(ch);
    if (e.destination == 'corpus') return 'SOCIETY CORPUS FUND';
    if (e.destination == 'current_month_maintenance') return 'OPERATION & MAINTENANCE';
    final t = (e.title ?? '').trim();
    if (t.isNotEmpty) return inferMajorHeadFromGroupName(t);
    return kUncategorizedHead;
  }

  /// Kind label key: `pool` | `ledgerOnly` | `food` | `societyPayment`.
  String ledgerEntryKind(FinanceLedgerRow e) {
    final id = e.expenseId;
    if (id == null || id.isEmpty) return isLedgerInSocietyPool(e) ? 'pool' : 'ledgerOnly';
    if (data.expenseCategoryById[id] == 'food') return 'food';
    return 'societyPayment';
  }

  /// Flats in scope for reminders / unpaid (occupied only unless vacant included), one row per flat number.
  List<SocietyFlatRow> uniqueTargetFlats({required bool includeVacant}) {
    final target = includeVacant ? data.flats : data.flats.where((f) => f.occupied).toList();
    final seen = <String>{};
    final rows = <SocietyFlatRow>[];
    for (final f in target) {
      final key = f.flatNumber;
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      rows.add(f);
    }
    return rows;
  }

  int targetFlatCount({required bool includeVacant}) =>
      includeVacant ? data.flats.length : data.flats.where((f) => f.occupied).length;

  /// Flats with no verified payment at all (Reminders panel).
  List<SocietyFlatRow> unpaidFlats({required bool includeVacant}) {
    final paid = {
      for (final p in data.payments)
        if (p.paymentStatus == 'verified') p.flatNumber,
    };
    return uniqueTargetFlats(includeVacant: includeVacant).where((f) => !paid.contains(f.flatNumber)).toList();
  }

  /// Current month's monthly maintenance charge (title + amount) used by the reminders grid.
  ({String title, double amount})? get currentMaintenanceCharge {
    final monthly = data.charges.where(isMonthlyMaintenanceCharge).toList();
    if (monthly.isEmpty) return null;
    final current = monthly.firstWhere((c) => isCurrentMonthChargeTitle(c.title), orElse: () => monthly.first);
    return (title: current.title, amount: current.amount);
  }

  List<UnpaidFlatGridRow> unpaidReminderRows({required bool includeVacant}) {
    final current = currentMaintenanceCharge;
    final rows = unpaidFlats(includeVacant: includeVacant).map((f) {
      String? pending;
      for (final p in data.payments) {
        if (p.flatNumber == f.flatNumber && (p.paymentStatus == 'pending' || p.paymentStatus == 'rejected')) {
          pending = p.paymentStatus;
          break;
        }
      }
      return UnpaidFlatGridRow(
        flatNumber: f.flatNumber,
        primaryName: residentLabelForFlatRow(f.id, f.ownerName, data.primaryByFlatId) ?? '',
        isOccupied: f.isOccupied,
        pendingPayment: pending,
        dueAmount: current?.amount,
        chargeTitle: current?.title,
      );
    }).toList();
    rows.sort((a, b) => compareFlatNumbers(a.flatNumber, b.flatNumber));
    return rows;
  }

  /// Preferred charge for Record receipt auto-select (current month maintenance → any monthly maintenance → first).
  FinanceCharge? get preferredRecordCharge {
    if (data.charges.isEmpty) return null;
    for (final c in data.charges) {
      if (isMonthlyMaintenanceCharge(c) && isCurrentMonthChargeTitle(c.title)) return c;
    }
    for (final c in data.charges) {
      if (isMonthlyMaintenanceCharge(c)) return c;
    }
    return data.charges.first;
  }
}
