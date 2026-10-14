// Finance → Transactions (web `receipts` sub-tab) filtering, totals and head-wise summaries —
// the memo chain of FinanceManager.tsx kept pure for testing.

import 'cash_bank_channel.dart';
import 'finance_charge_helpers.dart';
import 'finance_dates.dart';
import 'finance_derived.dart';
import 'finance_expense_head.dart';
import 'finance_ledger_display.dart';
import 'finance_models.dart';
import 'flat_sort.dart';
import 'transaction_statement_rows.dart';

/// Filter state of the Transactions tab.
class TransactionsQuery {
  const TransactionsQuery({
    this.filterStatus = 'all',
    this.paymentTypeFilter = 'all',
    this.paymentMonthFilter = 'all',
    this.receiptModeFilter = 'all',
    this.search = '',
    this.includeVacantFlats = false,
  });

  /// `all` | `pending` | `verified` | `rejected` | `unpaid`
  final String filterStatus;
  final String paymentTypeFilter;
  final String paymentMonthFilter;

  /// `all` | `society_pool` | `flats_only` | `flats_plus_outsider` | `outsider_only`
  final String receiptModeFilter;
  final String search;
  final bool includeVacantFlats;
}

/// A row shown in the head-wise drill-down sheet (web `ReportDetailRow`).
class FinReportRow {
  const FinReportRow({
    required this.id,
    required this.label,
    this.sublabel,
    this.amount,
    this.date,
    this.dateIso,
    this.status,
    this.extra,
    this.payment,
    this.entry,
  });

  final String id;
  final String label;
  final String? sublabel;
  final double? amount;
  final String? date;
  final String? dateIso;
  final String? status;
  final String? extra;
  final FinancePayment? payment;
  final FinanceLedgerRow? entry;

  bool get drillable => payment != null || entry != null;
}

/// Payment-type filter values available for the loaded data (labels are localised by the UI).
List<String> paymentTypeOptionValues(FinanceDerived d) {
  final keys = <String>{};
  for (final p in d.data.payments) {
    final ch = d.chargeById[p.chargeId ?? ''];
    if (ch != null && isMonthlyMaintenanceCharge(ch)) {
      keys.add('monthly_maintenance');
    } else if (ch != null && ch.frequency.isNotEmpty) {
      keys.add(ch.frequency.toLowerCase());
    } else {
      keys.add('other');
    }
  }
  final ledger = d.data.ledgerEntries;
  return [
    'all',
    'all_payments',
    'all_receipts',
    if (ledger.any(isLedgerInSocietyPool)) 'society_pool_pending',
    if (keys.contains('monthly_maintenance')) 'monthly_maintenance',
    if (keys.contains('monthly')) 'monthly',
    if (keys.contains('quarterly')) 'quarterly',
    if (keys.contains('yearly')) 'yearly',
    if (keys.contains('one-time')) 'one-time',
    if (keys.contains('other')) 'other',
    if (ledger.any((e) => e.destination == 'corpus')) 'corpus',
    if (ledger.any((e) => e.recordMode != 'flats_only')) 'outsider_mixed',
  ];
}

/// Month filter options (`all` first, then newest month first) with `MM/yyyy` labels.
List<({String value, String label})> monthOptionsForReceipts(FinanceDerived d) {
  final uniq = <String, String>{};
  for (final p in d.data.payments) {
    final value = paymentMonthValue(p.dueDate);
    if (value.isEmpty) continue;
    uniq.putIfAbsent(value, () => paymentMonthLabel(p));
  }
  for (final e in d.societyLedgerEntries) {
    final value = ledgerMonthValue(e);
    uniq.putIfAbsent(value,
        () => parseYmd('$value-15') == null ? value : isoMonthToDisplay(value));
  }
  final entries = uniq.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return [
    (value: 'all', label: 'All months'),
    for (final e in entries) (value: e.key, label: e.value),
  ];
}

class TransactionsView {
  TransactionsView._({
    required this.scopedReceiptPayments,
    required this.filteredPayments,
    required this.scopedLedgerOnly,
    required this.unpaidRows,
    required this.summaryCount,
    required this.summarySum,
    required this.summaryFlatCount,
    required this.receiptHeadSummary,
    required this.paymentHeadSummary,
    required this.lineItems,
    required this.derived,
  });

  final List<FinancePayment> scopedReceiptPayments;
  final List<FinancePayment> filteredPayments;
  final List<FinanceLedgerRow> scopedLedgerOnly;
  final List<UnpaidFlatGridRow> unpaidRows;
  final int summaryCount;
  final double summarySum;
  final int summaryFlatCount;
  final List<TransactionHeadSummaryRow> receiptHeadSummary;
  final List<TransactionHeadSummaryRow> paymentHeadSummary;
  final List<ReceiptLineItem> lineItems;
  final FinanceDerived derived;

  ChannelTotals get receiptChannelTotals =>
      sumChannelRows(receiptHeadSummary.map((r) => r.byChannel));
  ChannelTotals get paymentChannelTotals =>
      sumChannelRows(paymentHeadSummary.map((r) => r.byChannel));

  /// Entries for the head-wise receipt drill-down (sorted by flat, then date).
  List<FinReportRow> receiptHeadEntryRows(String head) {
    final items = <({String t, String flat, FinReportRow row})>[];
    for (final p in filteredPayments) {
      final ch = derived.chargeById[p.chargeId ?? ''];
      final h =
          ch != null ? derived.majorHeadForCharge(ch) : kUncategorizedHead;
      if (h != head) continue;
      final method = p.paymentMethod.toUpperCase();
      items.add((
        t: p.createdAt,
        flat: p.flatNumber,
        row: FinReportRow(
          id: 'mp-${p.id}',
          label: 'Flat ${p.flatNumber}',
          sublabel:
              '${(ch?.title ?? '').isEmpty ? 'Unknown charge' : ch!.title} · ${(p.residentName ?? '').isEmpty ? '—' : p.residentName}',
          amount: p.amount,
          date: fmtDateLocal(p.createdAt),
          dateIso: p.createdAt,
          status: p.paymentStatus,
          extra: method.isEmpty ? null : method,
          payment: p,
        ),
      ));
    }
    for (final e in scopedLedgerOnly) {
      if (derived.isSocietyPaymentLedgerEntry(e)) continue;
      if (derived.ledgerReceiptHead(e) != head) continue;
      final method = e.paymentMethod.toUpperCase();
      items.add((
        t: e.createdAt,
        flat: primaryFlatFromAllocations(e.allocations),
        row: FinReportRow(
          id: 'ledger-${e.id}',
          label: (e.title ?? '').isEmpty ? 'Finance entry' : e.title!,
          sublabel:
              '${formatLedgerFieldLabel(e.recordMode)} · ${formatLedgerFieldLabel(e.destination)}',
          amount: e.totalAmount,
          date: fmtDateLocal(e.createdAt),
          dateIso: e.createdAt,
          status: e.paymentStatus,
          extra: method.isEmpty ? null : method,
          entry: e,
        ),
      ));
    }
    items.sort((a, b) => compareByFlatThenDate(a.flat, b.flat, a.t, b.t));
    return [for (final i in items) i.row];
  }

  /// Entries for the head-wise society-payment drill-down (newest first).
  List<FinReportRow> paymentHeadEntryRows(String head) {
    final items = <({String t, FinReportRow row})>[];
    for (final e in scopedLedgerOnly) {
      if (!derived.isSocietyPaymentLedgerEntry(e)) continue;
      final h = financeExpenseHeadFromLedgerEntry(
          e.title,
          e.expenseId != null
              ? derived.data.expenseCategoryById[e.expenseId]
              : null);
      if (h != head) continue;
      final method = e.paymentMethod.toUpperCase();
      items.add((
        t: e.createdAt,
        row: FinReportRow(
          id: 'ledger-${e.id}',
          label: (e.title ?? '').isEmpty ? 'Society payment' : e.title!,
          sublabel:
              '${formatLedgerFieldLabel(e.recordMode)} · ${formatLedgerFieldLabel(e.destination)}',
          amount: e.totalAmount,
          date: fmtDateLocal(e.createdAt),
          dateIso: e.createdAt,
          status: e.paymentStatus,
          extra: method.isEmpty ? null : method,
          entry: e,
        ),
      ));
    }
    items.sort((a, b) => b.t.compareTo(a.t));
    return [for (final i in items) i.row];
  }

  static TransactionsView compute(FinanceDerived d, TransactionsQuery q) {
    final data = d.data;
    final typeF = q.paymentTypeFilter;
    final monthF = q.paymentMonthFilter;
    final modeF = q.receiptModeFilter;
    final status = q.filterStatus;
    final search = q.search.trim().toLowerCase();

    final flatOwnerByNumber = <String, String>{};
    for (final f in data.flats) {
      flatOwnerByNumber.putIfAbsent(f.flatNumber, () => f.ownerName ?? '');
    }

    final scopedPayments = data.payments.where((p) {
      if (typeF == 'corpus' ||
          typeF == 'outsider_mixed' ||
          typeF == 'all_payments' ||
          typeF == 'society_pool_pending') {
        return false;
      }
      final fe = (p.financeEntryId != null && p.financeEntryId!.isNotEmpty)
          ? d.financeEntryById[p.financeEntryId]
          : null;
      if (fe != null && isGroupExpenseLedgerEntry(fe)) return false;
      if (modeF != 'all') {
        final mode = fe?.recordMode ?? 'flats_only';
        if (mode != modeF) return false;
      }
      final ch = d.chargeById[p.chargeId ?? ''];
      if (typeF == 'monthly_maintenance') {
        if (ch == null || !isMonthlyMaintenanceCharge(ch)) return false;
      } else if (typeF == 'other') {
        if (ch != null) return false;
      } else if (typeF != 'all' && typeF != 'all_receipts') {
        if (ch == null || ch.frequency.toLowerCase() != typeF) return false;
      }
      if (monthF != 'all' && paymentMonthValue(p.dueDate) != monthF) {
        return false;
      }
      if (search.isNotEmpty) {
        final haystack = [
          p.flatNumber,
          p.residentName ?? '',
          p.transactionId ?? '',
          p.notes ?? '',
          p.paymentMethod,
          (ch?.title ?? '').toLowerCase(),
          (flatOwnerByNumber[p.flatNumber] ?? '').toLowerCase(),
        ].join(' ').toLowerCase();
        if (!haystack.contains(search)) return false;
      }
      return true;
    }).toList();

    final filteredPayments = scopedPayments.where((p) {
      if (status == 'all') return true;
      if (status == 'unpaid') return false;
      return p.paymentStatus == status;
    }).toList();

    const receiptTypeFilters = {
      'all_receipts',
      'society_pool_pending',
      'monthly_maintenance',
      'corpus',
      'outsider_mixed',
      'other',
      'monthly',
      'quarterly',
      'yearly',
      'one-time',
    };

    final scopedLedgerOnly = d.societyLedgerEntries.where((e) {
      final societyPayment = d.isSocietyPaymentLedgerEntry(e);
      if (typeF == 'all_payments' && !societyPayment) return false;
      if (receiptTypeFilters.contains(typeF) && societyPayment) return false;
      if (typeF == 'society_pool_pending' && !isLedgerInSocietyPool(e)) {
        return false;
      }
      if (d.financeEntryIdsWithPayments.contains(e.id)) return false;
      if (modeF != 'all' && e.recordMode != modeF) return false;
      if (monthF != 'all' && ledgerMonthValue(e) != monthF) return false;
      if (status != 'all' && status != 'unpaid' && e.paymentStatus != status) {
        return false;
      }

      if (typeF == 'all' ||
          typeF == 'all_payments' ||
          typeF == 'all_receipts' ||
          typeF == 'society_pool_pending') {
        // include
      } else if (typeF == 'monthly_maintenance') {
        // Web returns early here, so the search box does not narrow these ledger rows.
        if (e.destination == 'corpus') return false;
        final ch = e.chargeId != null ? d.chargeById[e.chargeId] : null;
        if (ch != null && isMonthlyMaintenanceCharge(ch)) return true;
        if (e.destination == 'current_month_maintenance' &&
            (e.recordMode == 'outsider_only' ||
                e.recordMode == 'flats_plus_outsider')) {
          return true;
        }
        return false;
      } else if (typeF == 'corpus') {
        if (e.destination != 'corpus') return false;
      } else if (typeF == 'outsider_mixed') {
        if (e.recordMode == 'flats_only') return false;
      } else {
        final ch = e.chargeId != null ? d.chargeById[e.chargeId] : null;
        if (ch == null || ch.frequency.toLowerCase() != typeF) return false;
      }

      if (search.isEmpty) return true;
      final cp = e.counterparty;
      final parts = [
        e.title,
        e.notes,
        e.transactionId,
        cp?.name,
        cp?.relationToSociety
      ].where((v) => v != null && v.isNotEmpty).join(' ').toLowerCase();
      return parts.contains(search);
    }).toList();

    // Unpaid grid (FLATS UNPAID status filter).
    var unpaidRows = <UnpaidFlatGridRow>[];
    if (status == 'unpaid') {
      final ctx = chargeForUnpaidFilters(data.charges, typeF, monthF);
      final paidSet = {
        for (final p in scopedPayments)
          if (p.paymentStatus == 'verified' && p.flatNumber.isNotEmpty)
            p.flatNumber,
      };
      final pendingByFlat = <String, String>{};
      for (final p in scopedPayments) {
        if (p.paymentStatus != 'pending' && p.paymentStatus != 'rejected') {
          continue;
        }
        if (p.flatNumber.isEmpty) continue;
        pendingByFlat[p.flatNumber] = p.paymentStatus;
      }
      unpaidRows = d
          .uniqueTargetFlats(includeVacant: q.includeVacantFlats)
          .where((f) => !paidSet.contains(f.flatNumber))
          .map((f) => UnpaidFlatGridRow(
                flatNumber: f.flatNumber,
                primaryName: residentLabelForFlatRow(
                        f.id, f.ownerName, data.primaryByFlatId) ??
                    '',
                isOccupied: f.isOccupied,
                pendingPayment: pendingByFlat[f.flatNumber],
                dueAmount: ctx?.amount,
                chargeTitle: ctx?.title,
              ))
          .where((row) =>
              search.isEmpty ||
              '${row.flatNumber} ${row.primaryName}'
                  .toLowerCase()
                  .contains(search))
          .toList()
        ..sort((a, b) => compareFlatNumbers(a.flatNumber, b.flatNumber));
    }

    int count;
    double sum;
    int flatCount;
    if (status == 'unpaid') {
      count = unpaidRows.length;
      sum = 0;
      flatCount = unpaidRows.length;
    } else {
      final flatSet = <String>{};
      sum = 0;
      for (final p in filteredPayments) {
        sum += p.amount;
        if (p.flatNumber.isNotEmpty) flatSet.add(p.flatNumber);
      }
      for (final e in scopedLedgerOnly) {
        sum += e.totalAmount;
        for (final a in e.allocations) {
          flatSet.add(a.flatNumber);
        }
      }
      count = filteredPayments.length + scopedLedgerOnly.length;
      flatCount = flatSet.length;
    }

    var receiptHeads = <TransactionHeadSummaryRow>[];
    var paymentHeads = <TransactionHeadSummaryRow>[];
    var lineItems = <ReceiptLineItem>[];
    if (status != 'unpaid') {
      final rMap = <String, TransactionHeadSummaryRow>{};
      for (final p in filteredPayments) {
        final ch = d.chargeById[p.chargeId ?? ''];
        addTransactionHeadRow(
            rMap,
            ch != null ? d.majorHeadForCharge(ch) : kUncategorizedHead,
            p.amount,
            p.paymentMethod);
      }
      for (final e in scopedLedgerOnly) {
        if (d.isSocietyPaymentLedgerEntry(e)) continue;
        addTransactionHeadRow(
            rMap, d.ledgerReceiptHead(e), e.totalAmount, e.paymentMethod);
      }
      receiptHeads = transactionHeadSummaryRows(rMap);

      final pMap = <String, TransactionHeadSummaryRow>{};
      for (final e in scopedLedgerOnly) {
        if (!d.isSocietyPaymentLedgerEntry(e)) continue;
        final head = financeExpenseHeadFromLedgerEntry(e.title,
            e.expenseId != null ? data.expenseCategoryById[e.expenseId] : null);
        addTransactionHeadRow(pMap, head, e.totalAmount, e.paymentMethod);
      }
      paymentHeads = transactionHeadSummaryRows(pMap);

      lineItems = [
        for (final p in filteredPayments) ReceiptLineItem.payment(p),
        for (final e in scopedLedgerOnly) ReceiptLineItem.ledger(e),
      ];
      lineItems.sort((a, b) {
        final flatA = a.payment != null
            ? a.payment!.flatNumber
            : primaryFlatFromAllocations(a.entry!.allocations);
        final flatB = b.payment != null
            ? b.payment!.flatNumber
            : primaryFlatFromAllocations(b.entry!.allocations);
        return compareByFlatThenDate(flatA, flatB, a.createdAt, b.createdAt);
      });
    }

    return TransactionsView._(
      scopedReceiptPayments: scopedPayments,
      filteredPayments: filteredPayments,
      scopedLedgerOnly: scopedLedgerOnly,
      unpaidRows: unpaidRows,
      summaryCount: count,
      summarySum: sum,
      summaryFlatCount: flatCount,
      receiptHeadSummary: receiptHeads,
      paymentHeadSummary: paymentHeads,
      lineItems: lineItems,
      derived: d,
    );
  }
}
