/// Pure finance period-report maths — Dart port of `src/lib/financePeriodReport.ts`.
///
/// Single source of truth for Reports → Financial (head-wise receipts / expenses),
/// the Cash Flow Statement opening / closing balances and Finance → Totals.
/// No Flutter / Supabase imports: safe to use from any module and from tests.
///
/// ```dart
/// final report = computeFinancePeriodReport(
///   periodFrom: '2026-04-01',
///   periodTo: '2026-04-30',
///   payments: rows.map(FinancePeriodPayment.fromJson).toList(),
///   ledgerEntries: filterSocietyLedgerEntries(ledger, expenseCategoryById),
///   expenseCategoryById: expenseCategoryById,
///   openingBalanceAnchors: anchors,
/// );
/// ```
library;

import 'finance_dates.dart';
import 'finance_heads.dart';
import 'js_compat.dart';
import 'payment_channel.dart';

export 'payment_channel.dart'
    show ChannelTotals, PaymentChannel, normalizePaymentChannel;

// ─── Input rows ──────────────────────────────────────────────────────────────

/// Verified maintenance payment row (`maintenance_payments`) — same fields the
/// web Reports → Financial period report uses.
class FinancePeriodPayment {
  const FinancePeriodPayment({
    this.id,
    this.paymentStatus,
    this.amount = 0,
    this.paymentMethod,
    this.dueDate,
    this.financeEntryId,
    this.flatNumber,
    this.createdAt,
    this.notes,
    this.transactionId,
    this.residentName,
    this.chargeId,
    this.paymentDate,
    this.verifiedAt,
  });

  final String? id;
  final String? paymentStatus;
  final double amount;
  final String? paymentMethod;
  final String? dueDate;
  final String? financeEntryId;
  final String? flatNumber;
  final String? createdAt;
  final String? notes;
  final String? transactionId;
  final String? residentName;
  final String? chargeId;
  final String? paymentDate;
  final String? verifiedAt;

  /// From a raw `maintenance_payments` row (`select('*')`).
  factory FinancePeriodPayment.fromJson(Map<String, dynamic> j) =>
      FinancePeriodPayment(
        id: j['id']?.toString(),
        paymentStatus: j['payment_status']?.toString(),
        amount: jsAmount(j['amount']),
        paymentMethod: j['payment_method']?.toString(),
        dueDate: j['due_date']?.toString(),
        financeEntryId: j['finance_entry_id']?.toString(),
        flatNumber: j['flat_number']?.toString(),
        createdAt: j['created_at']?.toString(),
        notes: j['notes']?.toString(),
        transactionId: j['transaction_id']?.toString(),
        residentName: j['resident_name']?.toString(),
        chargeId: j['charge_id']?.toString(),
        paymentDate: j['payment_date']?.toString(),
        verifiedAt: j['verified_at']?.toString(),
      );

  bool get isVerified => paymentStatus == 'verified';

  /// `paymentBillingDate(p)` — due date, first 10 chars.
  String get billingDate => paymentBillingDate(dueDate);
}

/// One `finance_entry_allocations` row.
class FinanceEntryAllocation {
  const FinanceEntryAllocation(
      {required this.flatNumber, this.amount = 0, this.flatId});

  final String flatNumber;
  final double amount;
  final String? flatId;

  factory FinanceEntryAllocation.fromJson(Map<String, dynamic> j) =>
      FinanceEntryAllocation(
        flatNumber: (j['flat_number'] ?? '').toString(),
        amount: jsAmount(j['amount']),
        flatId: j['flat_id']?.toString(),
      );
}

/// Society finance ledger row (`finance_entries`). Event food rows are excluded
/// upstream with [filterSocietyLedgerEntries].
class FinancePeriodLedgerEntry {
  const FinancePeriodLedgerEntry({
    required this.id,
    this.recordMode,
    required this.destination,
    this.totalAmount = 0,
    this.paymentMethod,
    this.paymentStatus,
    this.title,
    this.notes,
    this.transactionId,
    this.transactionDate,
    this.entryMonth,
    this.createdAt,
    this.expenseId,
    this.chargeId,
    this.aggregateFlatCount = 0,
    this.allocationStyle,
    this.distributedAt,
    this.allocations = const [],
    this.counterpartyNames = const [],
  });

  final String id;
  final String? recordMode;
  final String destination;
  final double totalAmount;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? title;
  final String? notes;
  final String? transactionId;
  final String? transactionDate;
  final String? entryMonth;
  final String? createdAt;
  final String? expenseId;
  final String? chargeId;
  final double aggregateFlatCount;
  final String? allocationStyle;
  final String? distributedAt;
  final List<FinanceEntryAllocation> allocations;
  final List<String> counterpartyNames;

  /// From a raw `finance_entries` row, optionally with embedded
  /// `finance_entry_allocations(*)` / `finance_entry_counterparties(*)`.
  factory FinancePeriodLedgerEntry.fromJson(Map<String, dynamic> j) {
    final allocs = j['finance_entry_allocations'];
    final cps = j['finance_entry_counterparties'];
    return FinancePeriodLedgerEntry(
      id: (j['id'] ?? '').toString(),
      recordMode: j['record_mode']?.toString(),
      destination: (j['destination'] ?? '').toString(),
      totalAmount: jsAmount(j['total_amount']),
      paymentMethod: j['payment_method']?.toString(),
      paymentStatus: j['payment_status']?.toString(),
      title: j['title']?.toString(),
      notes: j['notes']?.toString(),
      transactionId: j['transaction_id']?.toString(),
      transactionDate: j['transaction_date']?.toString(),
      entryMonth: j['entry_month']?.toString(),
      createdAt: j['created_at']?.toString(),
      expenseId: j['expense_id']?.toString(),
      chargeId: j['charge_id']?.toString(),
      aggregateFlatCount: jsAmount(j['aggregate_flat_count']),
      allocationStyle: j['allocation_style']?.toString(),
      distributedAt: j['distributed_at']?.toString(),
      allocations: allocs is List
          ? allocs
              .whereType<Map>()
              .map((e) =>
                  FinanceEntryAllocation.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      counterpartyNames: cps is List
          ? cps
              .whereType<Map>()
              .map((e) => (e['name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
    );
  }

  /// `String(e.payment_status ?? 'verified')`.
  String get effectiveStatus => paymentStatus ?? 'verified';

  bool get isVerified => effectiveStatus == 'verified';

  /// `ledgerTransactionDate(e)`.
  String get ledgerDate => ledgerTransactionDate(
      transactionDate: transactionDate,
      entryMonth: entryMonth,
      createdAt: createdAt);

  bool get isExpense => destination == 'separate_entry';

  bool get isInflowDestination =>
      destination == 'current_month_maintenance' || destination == 'corpus';
}

/// `reserve_fund_transfers` row.
class FinancePeriodReserveTransfer {
  const FinancePeriodReserveTransfer({
    required this.id,
    required this.entryMonth,
    required this.amount,
    required this.direction,
    required this.paymentMethod,
    this.notes,
    this.createdAt = '',
  });

  final String id;
  final String entryMonth;
  final double amount;
  final String direction;
  final String paymentMethod;
  final String? notes;
  final String createdAt;

  factory FinancePeriodReserveTransfer.fromJson(Map<String, dynamic> j) =>
      FinancePeriodReserveTransfer(
        id: (j['id'] ?? '').toString(),
        entryMonth: (j['entry_month'] ?? '').toString(),
        amount: jsAmount(j['amount']),
        direction: (j['direction'] ?? '').toString(),
        paymentMethod: (j['payment_method'] ?? '').toString(),
        notes: j['notes']?.toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

/// Manual "as on" opening balance (`finance_opening_balance_anchors`).
class FinanceOpeningBalanceAnchor {
  const FinanceOpeningBalanceAnchor({
    required this.asOnDate,
    this.cashAmount,
    this.bankAmount,
    this.otherAmount,
    this.notes,
    this.id,
  });

  final String? id;
  final String asOnDate;
  final double? cashAmount;
  final double? bankAmount;
  final double? otherAmount;
  final String? notes;

  factory FinanceOpeningBalanceAnchor.fromJson(Map<String, dynamic> j) {
    double? n(Object? v) => v == null ? null : jsAmount(v);
    final d = (j['as_on_date'] ?? '').toString();
    return FinanceOpeningBalanceAnchor(
      id: j['id']?.toString(),
      asOnDate: d.length > 10 ? d.substring(0, 10) : d,
      cashAmount: n(j['cash_amount']),
      bankAmount: n(j['bank_amount']),
      otherAmount: n(j['other_amount']),
      notes: j['notes']?.toString(),
    );
  }

  String get _ymd =>
      asOnDate.length > 10 ? asOnDate.substring(0, 10) : asOnDate;
}

/// Cash / bank / other + total for one receipt or expense head.
class ChannelByHeadRow {
  ChannelByHeadRow(
      {this.cash = 0, this.bank = 0, this.other = 0, this.total = 0});

  double cash;
  double bank;
  double other;
  double total;

  @override
  bool operator ==(Object other) =>
      other is ChannelByHeadRow &&
      other.cash == cash &&
      other.bank == bank &&
      other.other == this.other &&
      other.total == total;

  @override
  int get hashCode => Object.hash(cash, bank, other, total);

  @override
  String toString() =>
      '{cash: $cash, bank: $bank, other: $other, total: $total}';
}

/// One `[head, row]` pair of `receiptByHead` / `expenseByHead`.
class HeadAmount {
  const HeadAmount(this.head, this.row);

  final String head;
  final ChannelByHeadRow row;

  @override
  bool operator ==(Object other) =>
      other is HeadAmount && other.head == head && other.row == row;

  @override
  int get hashCode => Object.hash(head, row);

  @override
  String toString() => '[$head, $row]';
}

// ─── Constants & period helpers ──────────────────────────────────────────────

const String kDefaultOpeningAnchorDate = '2026-02-28';

/// First month with society finance reporting (pre-go-live expenses e.g. Feb 2026).
const String kFinanceReportingEarliestMonth = '2026-02';
const String kFinanceReportingEarliestDate = '2026-02-01';

/// Last period start (inclusive) that shows manual opening-balance setup — Feb–Mar 2026 go-live window.
const String kManualOpeningBalanceLastPeriodFrom = '2026-03-31';

String _ymd10(String s) => s.length > 10 ? s.substring(0, 10) : s;

bool isManualOpeningBalanceSetupPeriod(String periodFrom) =>
    _ymd10(periodFrom).compareTo(kManualOpeningBalanceLastPeriodFrom) <= 0;

String clampFinancePeriodFrom(String date) {
  final d = _ymd10(date);
  return d.compareTo(kFinanceReportingEarliestDate) < 0
      ? kFinanceReportingEarliestDate
      : d;
}

/// Inclusive `yyyy-MM-dd` range for a reporting month (`yyyy-MM`).
({String from, String to}) financeReportingMonthRange(String ym) {
  final prefix = ym.length > 7 ? ym.substring(0, 7) : ym;
  final parts = prefix.split('-');
  final y =
      int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? DateTime.now().year;
  final mo = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final lastDay = DateTime(y, mo + 1, 0).day;
  return (from: '$prefix-01', to: '$prefix-${pad2(lastDay)}');
}

/// First day of the current month (clamped to the earliest reporting date).
String defaultFinancePeriodFrom([DateTime? now]) {
  final n = now ?? DateTime.now();
  return clampFinancePeriodFrom('${n.year}-${pad2(n.month)}-01');
}

/// Today (`yyyy-MM-dd`).
String defaultFinancePeriodTo([DateTime? now]) {
  final n = now ?? DateTime.now();
  return '${n.year}-${pad2(n.month)}-${pad2(n.day)}';
}

/// 1 April of the current year (clamped).
String defaultFinanceFyPeriodFrom([DateTime? now]) {
  final y = (now ?? DateTime.now()).year;
  return clampFinancePeriodFrom('$y-04-01');
}

/// Editable opening-anchor form (web `OpeningAnchorFormState`).
class OpeningAnchorFormState {
  const OpeningAnchorFormState({
    this.id = '',
    required this.asOnDate,
    this.cashAmount = '',
    this.bankAmount = '',
    this.otherAmount = '',
    this.notes = '',
  });

  final String id;
  final String asOnDate;
  final String cashAmount;
  final String bankAmount;
  final String otherAmount;
  final String notes;
}

/// Default form — cash ₹0 as on 28 Feb 2026; bank editable; blank = use transaction totals.
OpeningAnchorFormState createDefaultOpeningAnchorForm() =>
    const OpeningAnchorFormState(
      asOnDate: kDefaultOpeningAnchorDate,
      cashAmount: '0',
      bankAmount: '18145',
      otherAmount: '',
      notes: '',
    );

OpeningAnchorFormState openingAnchorRowToForm(
        FinanceOpeningBalanceAnchor row) =>
    OpeningAnchorFormState(
      id: row.id ?? '',
      asOnDate: row.asOnDate,
      cashAmount: row.cashAmount == null ? '' : jsNumberString(row.cashAmount!),
      bankAmount: row.bankAmount == null ? '' : jsNumberString(row.bankAmount!),
      otherAmount:
          row.otherAmount == null ? '' : jsNumberString(row.otherAmount!),
      notes: row.notes ?? '',
    );

double? parseOptionalAnchorAmount(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return (n != null && n.isFinite) ? n : null;
}

// ─── Result ──────────────────────────────────────────────────────────────────

class FinancePeriodReportResult {
  const FinancePeriodReportResult({
    required this.verifiedPaymentCount,
    required this.maintenanceReceipts,
    required this.corpusReceipts,
    required this.receiptByMethod,
    required this.receiptByHead,
    required this.totalReceipts,
    required this.expenseByMethod,
    required this.expenseByHead,
    required this.totalExpenses,
    required this.cashInHand,
    required this.cashInBank,
    required this.otherNet,
    required this.totalBalance,
    required this.extraLedgerReceipt,
    required this.openingCash,
    required this.openingBank,
    required this.openingOther,
    required this.openingBalance,
    required this.closingCash,
    required this.closingBank,
    required this.closingOther,
    required this.closingBalance,
    required this.appliedOpeningAnchor,
    required this.openingBankFromManualAnchor,
    required this.openingCashFromManualAnchor,
    required this.openingOtherFromManualAnchor,
  });

  final int verifiedPaymentCount;
  final double maintenanceReceipts;
  final double corpusReceipts;
  final ChannelTotals receiptByMethod;
  final List<HeadAmount> receiptByHead;
  final double totalReceipts;
  final ChannelTotals expenseByMethod;
  final List<HeadAmount> expenseByHead;
  final double totalExpenses;

  /// Period net cash (receipts − expenses on the cash channel).
  final double cashInHand;
  final double cashInBank;
  final double otherNet;
  final double totalBalance;
  final double extraLedgerReceipt;
  final double openingCash;
  final double openingBank;
  final double openingOther;
  final double openingBalance;
  final double closingCash;
  final double closingBank;
  final double closingOther;
  final double closingBalance;

  /// Anchor applied when computing opening balances (if any).
  final FinanceOpeningBalanceAnchor? appliedOpeningAnchor;
  final bool openingBankFromManualAnchor;
  final bool openingCashFromManualAnchor;
  final bool openingOtherFromManualAnchor;
}

// ─── Core maths ──────────────────────────────────────────────────────────────

/// Finance entry ids linked from verified maintenance payments (counted once).
Set<String> collectLinkedFinanceEntryIds(
    Iterable<FinancePeriodPayment> payments) {
  final ids = <String>{};
  for (final p in payments) {
    if (!p.isVerified) continue;
    final feId = p.financeEntryId;
    if (feId != null && feId.isNotEmpty) ids.add(feId);
  }
  return ids;
}

/// Exclude event food / contribution / head-scoped ledger rows — same rule as Finance.
List<FinancePeriodLedgerEntry> filterSocietyLedgerEntries(
  Iterable<FinancePeriodLedgerEntry> entries,
  Map<String, String> expenseCategoryById,
) =>
    entries
        .where((e) => !isEventFoodLedgerEntry(
              expenseId: e.expenseId,
              title: e.title,
              expenseCategoryById: expenseCategoryById,
            ))
        .toList();

/// Latest anchor strictly before period start (balance is end-of-day on `as_on_date`).
FinanceOpeningBalanceAnchor? findApplicableOpeningAnchor(
  Iterable<FinanceOpeningBalanceAnchor> anchors,
  String periodFrom,
) {
  FinanceOpeningBalanceAnchor? best;
  final from = _ymd10(periodFrom);
  for (final a in anchors) {
    final d = a._ymd;
    if (d.compareTo(from) >= 0) continue;
    if (best == null || d.compareTo(best._ymd) > 0) best = a;
  }
  return best;
}

ChannelTotals _computeChannelNetBetween(
  String fromYmd,
  String toYmd,
  List<FinancePeriodPayment> payments,
  List<FinancePeriodLedgerEntry> ledgerEntries,
  Set<String> allLinkedFeIds,
) {
  final receipt = ChannelTotals();
  final expense = ChannelTotals();

  for (final p in payments) {
    if (!p.isVerified) continue;
    final d = p.billingDate;
    if (d.isEmpty || !dateInInclusiveRange(d, fromYmd, toYmd)) continue;
    receipt.add(normalizePaymentChannel(p.paymentMethod), p.amount);
  }

  for (final e in ledgerEntries) {
    if (!e.isVerified) continue;
    final ledgerDate = e.ledgerDate;
    if (ledgerDate.isEmpty ||
        !dateInInclusiveRange(ledgerDate, fromYmd, toYmd)) {
      continue;
    }
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.isExpense) {
      expense.add(ch, e.totalAmount);
    } else if (e.isInflowDestination) {
      if (!allLinkedFeIds.contains(e.id)) receipt.add(ch, e.totalAmount);
    }
  }

  return netChannels(receipt, expense);
}

void _addToHeadRow(Map<String, ChannelByHeadRow> map, String head,
    PaymentChannel ch, double amt) {
  final trimmed = head.trim();
  final label = trimmed.isEmpty ? 'Uncategorized' : trimmed;
  final cur = map.putIfAbsent(label, ChannelByHeadRow.new);
  switch (ch) {
    case PaymentChannel.cash:
      cur.cash += amt;
    case PaymentChannel.bank:
      cur.bank += amt;
    case PaymentChannel.other:
      cur.other += amt;
  }
  cur.total += amt;
}

List<HeadAmount> _sortedHeads(Map<String, ChannelByHeadRow> map) {
  final list = [for (final e in map.entries) HeadAmount(e.key, e.value)];
  list.sort((a, b) {
    final d = b.row.total.compareTo(a.row.total);
    if (d != 0) return d;
    return jsLocaleCompare(a.head, b.head);
  });
  return list;
}

/// Core period report maths — single source of truth for Reports → Financial,
/// head-wise breakdown, and Cash Flow Statement opening/closing/receipts/expenses.
FinancePeriodReportResult computeFinancePeriodReport({
  required String periodFrom,
  required String periodTo,
  required List<FinancePeriodPayment> payments,
  required List<FinancePeriodLedgerEntry> ledgerEntries,
  Map<String, String>? expenseCategoryById,
  Map<String, String>? chargeMajorHeadById,
  List<FinanceOpeningBalanceAnchor>? openingBalanceAnchors,
}) {
  final categories = expenseCategoryById ?? const <String, String>{};
  final chargeHeads = chargeMajorHeadById ?? const <String, String>{};
  final anchors =
      openingBalanceAnchors ?? const <FinanceOpeningBalanceAnchor>[];
  final allLinkedFeIds = collectLinkedFinanceEntryIds(payments);

  final openingReceipt = ChannelTotals();
  final openingExpense = ChannelTotals();

  for (final p in payments) {
    if (!p.isVerified) continue;
    final d = p.billingDate;
    if (d.isEmpty || !isDateBefore(d, periodFrom)) continue;
    openingReceipt.add(normalizePaymentChannel(p.paymentMethod), p.amount);
  }

  for (final e in ledgerEntries) {
    if (!e.isVerified) continue;
    final ledgerDate = e.ledgerDate;
    if (ledgerDate.isEmpty || !isDateBefore(ledgerDate, periodFrom)) continue;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.isExpense) {
      openingExpense.add(ch, e.totalAmount);
    } else if (e.isInflowDestination) {
      if (!allLinkedFeIds.contains(e.id)) openingReceipt.add(ch, e.totalAmount);
    }
  }

  final openingCashComputed = openingReceipt.cash - openingExpense.cash;
  final openingBankComputed = openingReceipt.bank - openingExpense.bank;
  final openingOtherComputed = openingReceipt.other - openingExpense.other;

  // resolveOpeningBalances
  final anchor = findApplicableOpeningAnchor(anchors, periodFrom);
  double openingCash, openingBank, openingOther;
  var openingCashFromManualAnchor = false;
  var openingBankFromManualAnchor = false;
  var openingOtherFromManualAnchor = false;
  if (anchor == null) {
    openingCash = openingCashComputed;
    openingBank = openingBankComputed;
    openingOther = openingOtherComputed;
  } else {
    final deltaFrom = addDaysYmd(anchor.asOnDate, 1);
    final deltaTo = addDaysYmd(periodFrom, -1);
    final delta = deltaFrom.compareTo(deltaTo) <= 0
        ? _computeChannelNetBetween(
            deltaFrom, deltaTo, payments, ledgerEntries, allLinkedFeIds)
        : ChannelTotals();
    openingCashFromManualAnchor = anchor.cashAmount != null;
    openingBankFromManualAnchor = anchor.bankAmount != null;
    openingOtherFromManualAnchor = anchor.otherAmount != null;
    openingCash = openingCashFromManualAnchor
        ? anchor.cashAmount! + delta.cash
        : openingCashComputed;
    openingBank = openingBankFromManualAnchor
        ? anchor.bankAmount! + delta.bank
        : openingBankComputed;
    openingOther = openingOtherFromManualAnchor
        ? anchor.otherAmount! + delta.other
        : openingOtherComputed;
  }

  final openingBalance = openingCash + openingBank + openingOther;

  final receiptByMethod = ChannelTotals();
  final receiptByHead = <String, ChannelByHeadRow>{};
  var verifiedPaymentCount = 0;
  var maintenanceReceipts = 0.0;

  for (final p in payments) {
    if (!p.isVerified) continue;
    final d = p.billingDate;
    if (d.isEmpty || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    final amt = p.amount;
    final ch = normalizePaymentChannel(p.paymentMethod);
    receiptByMethod.add(ch, amt);
    _addToHeadRow(receiptByHead,
        financeReceiptHeadForPayment(p.chargeId, chargeHeads), ch, amt);
    maintenanceReceipts += amt;
    verifiedPaymentCount += 1;
  }

  final expenseByMethod = ChannelTotals();
  final expenseByHead = <String, ChannelByHeadRow>{};
  var extraLedgerReceipt = 0.0;
  var corpusReceipts = 0.0;

  for (final e in ledgerEntries) {
    if (!e.isVerified) continue;
    final ledgerDate = e.ledgerDate;
    if (ledgerDate.isEmpty ||
        !dateInInclusiveRange(ledgerDate, periodFrom, periodTo)) {
      continue;
    }
    final amt = e.totalAmount;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.isExpense) {
      expenseByMethod.add(ch, amt);
      final head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expenseId != null && e.expenseId!.isNotEmpty
            ? categories[e.expenseId]
            : null,
      );
      _addToHeadRow(expenseByHead, head, ch, amt);
    } else if (e.isInflowDestination) {
      if (!allLinkedFeIds.contains(e.id)) {
        extraLedgerReceipt += amt;
        receiptByMethod.add(ch, amt);
        _addToHeadRow(
          receiptByHead,
          financeReceiptHeadFromLedgerEntry(
            destination: e.destination,
            title: e.title,
            chargeId: e.chargeId,
            chargeMajorHeadById: chargeHeads,
          ),
          ch,
          amt,
        );
        if (e.destination == 'corpus') corpusReceipts += amt;
      }
    }
  }

  final totalReceipts =
      receiptByMethod.cash + receiptByMethod.bank + receiptByMethod.other;
  final totalExpenses =
      expenseByMethod.cash + expenseByMethod.bank + expenseByMethod.other;
  final cashInHand = receiptByMethod.cash - expenseByMethod.cash;
  final cashInBank = receiptByMethod.bank - expenseByMethod.bank;
  final otherNet = receiptByMethod.other - expenseByMethod.other;
  final totalBalance = cashInHand + cashInBank + otherNet;

  return FinancePeriodReportResult(
    verifiedPaymentCount: verifiedPaymentCount,
    maintenanceReceipts: maintenanceReceipts,
    corpusReceipts: corpusReceipts,
    receiptByMethod: receiptByMethod,
    receiptByHead: _sortedHeads(receiptByHead),
    totalReceipts: totalReceipts,
    expenseByMethod: expenseByMethod,
    expenseByHead: _sortedHeads(expenseByHead),
    totalExpenses: totalExpenses,
    cashInHand: cashInHand,
    cashInBank: cashInBank,
    otherNet: otherNet,
    totalBalance: totalBalance,
    extraLedgerReceipt: extraLedgerReceipt,
    openingCash: openingCash,
    openingBank: openingBank,
    openingOther: openingOther,
    openingBalance: openingBalance,
    closingCash: openingCash + cashInHand,
    closingBank: openingBank + cashInBank,
    closingOther: openingOther + otherNet,
    closingBalance: openingBalance + totalBalance,
    appliedOpeningAnchor: anchor,
    openingBankFromManualAnchor: openingBankFromManualAnchor,
    openingCashFromManualAnchor: openingCashFromManualAnchor,
    openingOtherFromManualAnchor: openingOtherFromManualAnchor,
  );
}

/// One-line summary used by the send panel and Finance → Totals
/// (`Receipts ₹… · Expenses ₹… · Net ₹… for {periodLabel}.`).
String financePeriodSummaryMessage(
        FinancePeriodReportResult r, String periodLabel) =>
    'Receipts ₹${toLocaleIn(r.totalReceipts)} · Expenses ₹${toLocaleIn(r.totalExpenses)} · '
    'Net ₹${toLocaleIn(r.totalBalance)} for $periodLabel.';
