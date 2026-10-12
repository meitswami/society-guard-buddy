// Private port of `src/lib/financePeriodReport.ts` for the Finance → Totals tab.
// (REPORTS owns the shared copy at lib/features/admin/reports/logic/finance_period_report.dart.)

import 'cash_bank_channel.dart';
import 'finance_dates.dart';
import 'finance_expense_head.dart';
import 'finance_format.dart';
import 'finance_ledger_display.dart';
import 'finance_models.dart';

const String kDefaultOpeningAnchorDate = '2026-02-28';

/// First month with society finance reporting (pre-go-live expenses e.g. Feb 2026).
const String kFinanceReportingEarliestMonth = '2026-02';
const String kFinanceReportingEarliestDate = '2026-02-01';

/// Last period start (inclusive) that shows manual opening-balance setup.
const String kManualOpeningBalanceLastPeriodFrom = '2026-03-31';

bool isManualOpeningBalanceSetupPeriod(String periodFrom) =>
    _ymd(periodFrom).compareTo(kManualOpeningBalanceLastPeriodFrom) <= 0;

String _ymd(String s) => s.length > 10 ? s.substring(0, 10) : s;

String clampFinancePeriodFrom(String date) {
  final d = _ymd(date);
  return d.compareTo(kFinanceReportingEarliestDate) < 0 ? kFinanceReportingEarliestDate : d;
}

/// Inclusive `yyyy-MM-dd` range for a reporting month (`yyyy-MM`).
({String from, String to}) financeReportingMonthRange(String ym) {
  final prefix = ym.length > 7 ? ym.substring(0, 7) : ym;
  final parts = prefix.split('-');
  final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? DateTime.now().year;
  final mo = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final last = daysInMonth(y, mo);
  return (from: '$prefix-01', to: '$prefix-${last.toString().padLeft(2, '0')}');
}

String defaultFinancePeriodFrom([DateTime? now]) {
  final n = now ?? DateTime.now();
  return clampFinancePeriodFrom('${ymOf(n)}-01');
}

String defaultFinancePeriodTo([DateTime? now]) => ymdOf(now ?? DateTime.now());

String defaultFinanceFyPeriodFrom([DateTime? now]) => clampFinancePeriodFrom('${(now ?? DateTime.now()).year}-04-01');

class ChannelByHeadRow {
  ChannelByHeadRow({this.cash = 0, this.bank = 0, this.other = 0, this.total = 0});

  double cash;
  double bank;
  double other;
  double total;

  @override
  bool operator ==(Object other) =>
      other is ChannelByHeadRow && other.cash == cash && other.bank == bank && other.other == this.other && other.total == total;

  @override
  int get hashCode => Object.hash(cash, bank, other, total);

  @override
  String toString() => 'ChannelByHeadRow(cash: $cash, bank: $bank, other: $other, total: $total)';
}

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
  final List<MapEntry<String, ChannelByHeadRow>> receiptByHead;
  final double totalReceipts;
  final ChannelTotals expenseByMethod;
  final List<MapEntry<String, ChannelByHeadRow>> expenseByHead;
  final double totalExpenses;
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
  final OpeningBalanceAnchor? appliedOpeningAnchor;
  final bool openingBankFromManualAnchor;
  final bool openingCashFromManualAnchor;
  final bool openingOtherFromManualAnchor;
}

Set<String> collectLinkedFinanceEntryIds(List<FinancePayment> payments) {
  final ids = <String>{};
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final fe = p.financeEntryId;
    if (fe != null && fe.isNotEmpty) ids.add(fe);
  }
  return ids;
}

/// Exclude event food / contribution / head-scoped ledger rows — same rule as the Finance module.
List<FinanceLedgerRow> filterSocietyLedgerEntries(List<FinanceLedgerRow> entries, Map<String, String> expenseCategoryById) =>
    entries.where((e) => !isEventFoodLedgerEntry(e.expenseId, e.title, expenseCategoryById)).toList();

/// Latest anchor strictly before period start (balance is end-of-day on `as_on_date`).
OpeningBalanceAnchor? findApplicableOpeningAnchor(List<OpeningBalanceAnchor> anchors, String periodFrom) {
  OpeningBalanceAnchor? best;
  for (final a in anchors) {
    final d = _ymd(a.asOnDate);
    if (d.compareTo(_ymd(periodFrom)) >= 0) continue;
    if (best == null || d.compareTo(_ymd(best.asOnDate)) > 0) best = a;
  }
  return best;
}

/// JS `String(e.payment_status ?? 'verified') === 'verified'` (null already maps to `verified`).
bool _verifiedLedger(FinanceLedgerRow e) => e.paymentStatus == 'verified';

bool _isInflowDest(String? d) => d == 'current_month_maintenance' || d == 'corpus';

ChannelTotals _computeChannelNetBetween(
  String fromYmd,
  String toYmd,
  List<FinancePayment> payments,
  List<FinanceLedgerRow> ledgerEntries,
  Set<String> linked,
) {
  final receipt = ChannelTotals();
  final expense = ChannelTotals();
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final d = paymentBillingDate(p.dueDate);
    if (d.isEmpty || !dateInInclusiveRange(d, fromYmd, toYmd)) continue;
    receipt.add(normalizePaymentChannel(p.paymentMethod), p.amount);
  }
  for (final e in ledgerEntries) {
    if (!_verifiedLedger(e)) continue;
    final d = ledgerTransactionDate(e);
    if (d.isEmpty || !dateInInclusiveRange(d, fromYmd, toYmd)) continue;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.destination == 'separate_entry') {
      expense.add(ch, e.totalAmount);
    } else if (_isInflowDest(e.destination)) {
      if (!linked.contains(e.id)) receipt.add(ch, e.totalAmount);
    }
  }
  return netChannels(receipt, expense);
}

void _addToHeadRow(Map<String, ChannelByHeadRow> map, String head, PaymentChannel ch, double amt) {
  final label = head.trim().isEmpty ? 'Uncategorized' : head.trim();
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

List<MapEntry<String, ChannelByHeadRow>> _sortedHeads(Map<String, ChannelByHeadRow> map) {
  final list = map.entries.toList();
  list.sort((a, b) {
    final t = b.value.total.compareTo(a.value.total);
    if (t != 0) return t;
    return compareText(a.key, b.key);
  });
  return list;
}

/// Core period report math — single source for Totals report, head-wise breakdown and cash flow.
FinancePeriodReportResult computeFinancePeriodReport({
  required String periodFrom,
  required String periodTo,
  required List<FinancePayment> payments,
  required List<FinanceLedgerRow> ledgerEntries,
  Map<String, String>? expenseCategoryById,
  Map<String, String>? chargeMajorHeadById,
  List<OpeningBalanceAnchor>? openingBalanceAnchors,
}) {
  final cats = expenseCategoryById ?? const <String, String>{};
  final heads = chargeMajorHeadById ?? const <String, String>{};
  final anchors = openingBalanceAnchors ?? const <OpeningBalanceAnchor>[];
  final linked = collectLinkedFinanceEntryIds(payments);

  final openingReceipt = ChannelTotals();
  final openingExpense = ChannelTotals();
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final d = paymentBillingDate(p.dueDate);
    if (d.isEmpty || !isDateBefore(d, periodFrom)) continue;
    openingReceipt.add(normalizePaymentChannel(p.paymentMethod), p.amount);
  }
  for (final e in ledgerEntries) {
    if (!_verifiedLedger(e)) continue;
    final d = ledgerTransactionDate(e);
    if (d.isEmpty || !isDateBefore(d, periodFrom)) continue;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.destination == 'separate_entry') {
      openingExpense.add(ch, e.totalAmount);
    } else if (_isInflowDest(e.destination)) {
      if (!linked.contains(e.id)) openingReceipt.add(ch, e.totalAmount);
    }
  }

  final computedCash = openingReceipt.cash - openingExpense.cash;
  final computedBank = openingReceipt.bank - openingExpense.bank;
  final computedOther = openingReceipt.other - openingExpense.other;

  var openingCash = computedCash, openingBank = computedBank, openingOther = computedOther;
  var bankManual = false, cashManual = false, otherManual = false;
  final anchor = findApplicableOpeningAnchor(anchors, periodFrom);
  if (anchor != null) {
    final deltaFrom = addDaysYmd(anchor.asOnDate, 1);
    final deltaTo = addDaysYmd(periodFrom, -1);
    final delta = deltaFrom.compareTo(deltaTo) <= 0
        ? _computeChannelNetBetween(deltaFrom, deltaTo, payments, ledgerEntries, linked)
        : ChannelTotals();
    cashManual = anchor.cashAmount != null;
    bankManual = anchor.bankAmount != null;
    otherManual = anchor.otherAmount != null;
    openingCash = cashManual ? anchor.cashAmount! + delta.cash : computedCash;
    openingBank = bankManual ? anchor.bankAmount! + delta.bank : computedBank;
    openingOther = otherManual ? anchor.otherAmount! + delta.other : computedOther;
  }
  final openingBalance = openingCash + openingBank + openingOther;

  final receiptByMethod = ChannelTotals();
  final receiptByHead = <String, ChannelByHeadRow>{};
  var verifiedPaymentCount = 0;
  var maintenanceReceipts = 0.0;
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final d = paymentBillingDate(p.dueDate);
    if (d.isEmpty || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    final ch = normalizePaymentChannel(p.paymentMethod);
    receiptByMethod.add(ch, p.amount);
    _addToHeadRow(receiptByHead, financeReceiptHeadForPayment(p.chargeId, heads), ch, p.amount);
    maintenanceReceipts += p.amount;
    verifiedPaymentCount += 1;
  }

  final expenseByMethod = ChannelTotals();
  final expenseByHead = <String, ChannelByHeadRow>{};
  var extraLedgerReceipt = 0.0;
  var corpusReceipts = 0.0;
  for (final e in ledgerEntries) {
    if (!_verifiedLedger(e)) continue;
    final d = ledgerTransactionDate(e);
    if (d.isEmpty || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.destination == 'separate_entry') {
      expenseByMethod.add(ch, e.totalAmount);
      final head = financeExpenseHeadFromLedgerEntry(e.title, e.expenseId != null ? cats[e.expenseId] : null);
      _addToHeadRow(expenseByHead, head, ch, e.totalAmount);
    } else if (_isInflowDest(e.destination)) {
      if (!linked.contains(e.id)) {
        extraLedgerReceipt += e.totalAmount;
        receiptByMethod.add(ch, e.totalAmount);
        _addToHeadRow(receiptByHead, financeReceiptHeadFromLedgerEntry(e.destination, e.title, e.chargeId, heads), ch, e.totalAmount);
        if (e.destination == 'corpus') corpusReceipts += e.totalAmount;
      }
    }
  }

  final totalReceipts = receiptByMethod.total;
  final totalExpenses = expenseByMethod.total;
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
    openingBankFromManualAnchor: bankManual,
    openingCashFromManualAnchor: cashManual,
    openingOtherFromManualAnchor: otherManual,
  );
}
