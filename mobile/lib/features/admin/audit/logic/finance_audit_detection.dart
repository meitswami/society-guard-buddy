import 'finance_dates.dart';
import 'js_compat.dart';

/// Port of `src/lib/financeAuditDetection.ts` (pure logic, no Flutter).
///
/// Text builders take `hi` (Hindi output); the default is the web's English copy.

String _l(bool hi, String en, String hindi) => hi ? hindi : en;

bool _truthy(String? s) => s != null && s.isNotEmpty;

/* ─── Payment channel ─── */

enum PaymentChannel { cash, bank, other }

const List<String> _bankChannelKeys = [
  'upi',
  'bank_transfer',
  'razorpay',
  'online',
  'card',
  'neft',
  'rtgs',
  'imps',
  'netbanking',
  'cheque',
  'dd',
];

/// `normalizePaymentChannel` — cash / bank (UPI, NEFT, cheque …) / other.
PaymentChannel normalizePaymentChannel(Object? method) {
  final x =
      (method ?? 'cash').toString().toLowerCase().replaceAll(RegExp(r'\s'), '');
  if (x == 'cash') return PaymentChannel.cash;
  if (_bankChannelKeys.any((k) => x == k || x.contains(k)))
    return PaymentChannel.bank;
  return PaymentChannel.other;
}

/* ─── Rows ─── */

class AuditPaymentRow {
  const AuditPaymentRow({
    required this.id,
    required this.chargeId,
    required this.flatNumber,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.dueDate,
    this.paymentDate,
    required this.createdAt,
    this.transactionId,
    this.notes,
    this.financeEntryId,
  });

  final String id;
  final String chargeId;
  final String flatNumber;
  final double amount;
  final String? paymentMethod;
  final String paymentStatus;
  final String? dueDate;
  final String? paymentDate;
  final String createdAt;
  final String? transactionId;
  final String? notes;
  final String? financeEntryId;

  factory AuditPaymentRow.fromJson(Map<String, dynamic> j) => AuditPaymentRow(
        id: (j['id'] ?? '').toString(),
        chargeId: (j['charge_id'] ?? '').toString(),
        flatNumber: (j['flat_number'] ?? '').toString(),
        amount: jsNumber(j['amount']),
        paymentMethod: jsStrOrNull(j['payment_method']),
        paymentStatus: (j['payment_status'] ?? '').toString(),
        dueDate: jsStrOrNull(j['due_date']),
        paymentDate: jsStrOrNull(j['payment_date']),
        createdAt: (j['created_at'] ?? '').toString(),
        transactionId: jsStrOrNull(j['transaction_id']),
        notes: jsStrOrNull(j['notes']),
        financeEntryId: jsStrOrNull(j['finance_entry_id']),
      );

  /// `paymentBillingDate(p)`.
  String get billingDate => paymentBillingDate(dueDate);

  bool get hasFinanceEntry => _truthy(financeEntryId);

  bool get isVerifiedOrPending =>
      paymentStatus == 'verified' || paymentStatus == 'pending';

  AuditPaymentRow copyWith(
          {double? amount,
          String? paymentMethod,
          String? paymentStatus,
          String? notes,
          String? dueDate}) =>
      AuditPaymentRow(
        id: id,
        chargeId: chargeId,
        flatNumber: flatNumber,
        amount: amount ?? this.amount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        dueDate: dueDate ?? this.dueDate,
        paymentDate: paymentDate,
        createdAt: createdAt,
        transactionId: transactionId,
        notes: notes ?? this.notes,
        financeEntryId: financeEntryId,
      );
}

class AuditLedgerRow {
  const AuditLedgerRow({
    required this.id,
    required this.recordMode,
    required this.destination,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.entryMonth,
    required this.createdAt,
    this.title,
    this.chargeId,
    this.aggregateFlatCount,
    this.transactionDate,
  });

  final String id;
  final String recordMode;
  final String destination;
  final double totalAmount;
  final String? paymentMethod;
  final String paymentStatus;
  final String? entryMonth;
  final String createdAt;
  final String? title;
  final String? chargeId;
  final int? aggregateFlatCount;

  /// Only present when the query selected it (the audit panels do not — like the web).
  final String? transactionDate;

  factory AuditLedgerRow.fromJson(Map<String, dynamic> j) => AuditLedgerRow(
        id: (j['id'] ?? '').toString(),
        recordMode: (j['record_mode'] ?? '').toString(),
        destination: (j['destination'] ?? '').toString(),
        totalAmount: jsNumber(j['total_amount']),
        paymentMethod: jsStrOrNull(j['payment_method']),
        paymentStatus: (j['payment_status'] ?? '').toString(),
        entryMonth: jsStrOrNull(j['entry_month']),
        createdAt: (j['created_at'] ?? '').toString(),
        title: jsStrOrNull(j['title']),
        chargeId: jsStrOrNull(j['charge_id']),
        aggregateFlatCount: j['aggregate_flat_count'] == null
            ? null
            : jsNumber(j['aggregate_flat_count']).round(),
        transactionDate: jsStrOrNull(j['transaction_date']),
      );

  /// `ledgerTransactionDate(e)`.
  String get ledgerDate => ledgerTransactionDate(
      transactionDate: transactionDate,
      entryMonth: entryMonth,
      createdAt: createdAt);
}

class DuplicatePaymentGroup {
  const DuplicatePaymentGroup({
    required this.flatNumber,
    required this.chargeId,
    required this.chargeTitle,
    required this.month,
    required this.paymentMethod,
    required this.count,
    required this.totalAmount,
    required this.payments,
  });

  final String flatNumber;
  final String chargeId;
  final String chargeTitle;
  final String month;

  /// `cash` | `bank` | `other` | `mixed`
  final String paymentMethod;
  final int count;
  final double totalAmount;
  final List<AuditPaymentRow> payments;
}

String _channelOf(Iterable<AuditPaymentRow> rows) {
  final channels = <PaymentChannel>{
    for (final r in rows) normalizePaymentChannel(r.paymentMethod)
  };
  return channels.length == 1 ? channels.first.name : 'mixed';
}

double _sumAmounts(Iterable<AuditPaymentRow> rows) =>
    rows.fold(0.0, (s, r) => s + r.amount);

/* ─── Receipt head keys / conflicts ─── */

/// Same flat + charge + calendar month (verified or pending).
String paymentDuplicateGroupKey(AuditPaymentRow p) {
  final dateStr = p.billingDate;
  final month = dateStr.isNotEmpty ? (ymOf(dateStr) ?? 'unknown') : 'unknown';
  return '${p.flatNumber}||${p.chargeId}||$month';
}

/// Same flat + billing month for any monthly-maintenance charge.
String monthlyMaintenanceMonthKey(String flatNumber, String dueDateYmd) =>
    '$flatNumber||${jsSlice(dueDateYmd, 0, 7)}';

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

/// Key used to block a new payment when the receipt head is already recorded.
String receiptHeadKeyFromRecording(
        String flatNumber, String chargeId, String dueDate,
        [String? paymentMethod]) =>
    '$flatNumber||$chargeId||${jsSlice(dueDate, 0, 7)}';

/// Verified / pending payments that already occupy the same receipt-head slot.
List<AuditPaymentRow> findReceiptHeadConflicts(
    List<AuditPaymentRow> existingPayments,
    List<ReceiptHeadRecordingTarget> targets) {
  final targetKeys = {
    for (final t in targets)
      receiptHeadKeyFromRecording(
          t.flatNumber, t.chargeId, t.dueDate, t.paymentMethod),
  };
  final seen = <String>{};
  final conflicts = <AuditPaymentRow>[];
  for (final p in existingPayments) {
    if (!p.isVerifiedOrPending) continue;
    final key = paymentDuplicateGroupKey(p);
    if (!targetKeys.contains(key) || seen.contains(p.id)) continue;
    seen.add(p.id);
    conflicts.add(p);
  }
  return conflicts;
}

/// Block a second monthly-maintenance receipt for the same flat + billing month
/// across all monthly maintenance charge types.
List<AuditPaymentRow> findMonthlyMaintenanceMonthConflicts(
  List<AuditPaymentRow> existingPayments,
  Iterable<String> monthlyChargeIds,
  List<({String flatNumber, String dueDate})> targets,
) {
  final monthlyIds = monthlyChargeIds.toSet();
  if (monthlyIds.isEmpty || targets.isEmpty) return const [];
  final targetKeys = {
    for (final t in targets) monthlyMaintenanceMonthKey(t.flatNumber, t.dueDate)
  };
  final seen = <String>{};
  final conflicts = <AuditPaymentRow>[];
  for (final p in existingPayments) {
    if (!p.isVerifiedOrPending) continue;
    if (!monthlyIds.contains(p.chargeId)) continue;
    final dateStr = p.billingDate;
    if (dateStr.isEmpty) continue;
    final key = monthlyMaintenanceMonthKey(p.flatNumber, dateStr);
    if (!targetKeys.contains(key) || seen.contains(p.id)) continue;
    seen.add(p.id);
    conflicts.add(p);
  }
  return conflicts;
}

class ReceiptHeadLookupFilter {
  const ReceiptHeadLookupFilter({this.flatNumber, this.chargeId, this.month});

  final String? flatNumber;
  final String? chargeId;
  final String? month;
}

int _groupCompare(DuplicatePaymentGroup a, DuplicatePaymentGroup b) {
  if (a.month != b.month) return jsLocaleCompare(b.month, a.month);
  return jsLocaleCompare(a.flatNumber, b.flatNumber);
}

/// Lookup recorded receipt-head payments (including single entries) for audit edit / delete.
List<DuplicatePaymentGroup> findReceiptHeadLookupGroups(
  List<AuditPaymentRow> payments,
  Map<String, String> chargeTitleById,
  ReceiptHeadLookupFilter filter,
) {
  final flat = filter.flatNumber?.trim().toUpperCase();
  final chargeId = filter.chargeId?.trim();
  final month = filter.month?.trim();

  final groups = <String, List<AuditPaymentRow>>{};
  for (final p in payments) {
    if (!p.isVerifiedOrPending) continue;
    if (_truthy(flat) && p.flatNumber.toUpperCase() != flat) continue;
    if (_truthy(chargeId) && p.chargeId != chargeId) continue;
    final key = paymentDuplicateGroupKey(p);
    final pMonth = key.split('||')[2];
    if (_truthy(month) && pMonth != month) continue;
    groups.putIfAbsent(key, () => []).add(p);
  }

  final results = <DuplicatePaymentGroup>[];
  groups.forEach((key, group) {
    final parts = key.split('||');
    results.add(DuplicatePaymentGroup(
      flatNumber: parts[0],
      chargeId: parts[1],
      chargeTitle: chargeTitleById[parts[1]] ?? 'Unknown receipt head',
      month: parts[2],
      paymentMethod: _channelOf(group),
      count: group.length,
      totalAmount: _sumAmounts(group),
      payments: group,
    ));
  });
  return stableSorted(results, _groupCompare);
}

/// Duplicate verified / pending payment rows (same flat + charge + month, or same
/// flat + month across all allowed charges when [groupAcrossCharges]).
List<DuplicatePaymentGroup> findDuplicatePaymentGroups(
  List<AuditPaymentRow> payments,
  Map<String, String> chargeTitleById, {
  List<String>? chargeIds,
  bool groupAcrossCharges = false,
}) {
  final allowed = chargeIds?.toSet();
  final groups = <String, List<AuditPaymentRow>>{};

  for (final p in payments) {
    if (!p.isVerifiedOrPending) continue;
    if (allowed != null && !allowed.contains(p.chargeId)) continue;
    final dateStr = p.billingDate;
    final month = dateStr.isNotEmpty ? (ymOf(dateStr) ?? 'unknown') : 'unknown';
    final key = groupAcrossCharges
        ? '${p.flatNumber}||$month'
        : paymentDuplicateGroupKey(p);
    groups.putIfAbsent(key, () => []).add(p);
  }

  final duplicates = <DuplicatePaymentGroup>[];
  groups.forEach((key, group) {
    if (group.length <= 1) return;
    final method = _channelOf(group);
    final parts = key.split('||');
    if (groupAcrossCharges) {
      final ids = <String>[];
      for (final r in group) {
        if (!ids.contains(r.chargeId)) ids.add(r.chargeId);
      }
      duplicates.add(DuplicatePaymentGroup(
        flatNumber: parts[0],
        chargeId: ids.isEmpty ? '' : ids.first,
        chargeTitle: ids.length == 1
            ? (chargeTitleById[ids.first] ?? 'Unknown charge')
            : ids.map((id) => chargeTitleById[id] ?? id).join(' + '),
        month: parts[1],
        paymentMethod: method,
        count: group.length,
        totalAmount: _sumAmounts(group),
        payments: group,
      ));
      return;
    }
    duplicates.add(DuplicatePaymentGroup(
      flatNumber: parts[0],
      chargeId: parts[1],
      chargeTitle: chargeTitleById[parts[1]] ?? 'Unknown charge',
      month: parts[2],
      paymentMethod: method,
      count: group.length,
      totalAmount: _sumAmounts(group),
      payments: group,
    ));
  });

  return stableSorted(duplicates, _groupCompare);
}

/* ─── Ledger double-count (period reports) ─── */

class LedgerOvercountEntry {
  const LedgerOvercountEntry({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.entryMonth,
    required this.recordMode,
    required this.destination,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String? title;
  final double totalAmount;
  final String? entryMonth;
  final String recordMode;
  final String destination;
  final String? paymentMethod;
  final String createdAt;

  /// `ledgerTransactionDate(e)` (these rows never carry `transaction_date`).
  String get ledgerDate =>
      ledgerTransactionDate(entryMonth: entryMonth, createdAt: createdAt);
}

class DateBoundaryMismatch {
  const DateBoundaryMismatch({
    required this.payment,
    required this.paymentMonth,
    required this.entryMonth,
    required this.entryTitle,
    required this.entryId,
  });

  final AuditPaymentRow payment;
  final String paymentMonth;
  final String entryMonth;
  final String? entryTitle;
  final String entryId;
}

class LedgerOvercountMonth {
  const LedgerOvercountMonth({
    required this.month,
    required this.paymentTotal,
    required this.reportTotal,
    required this.excess,
    required this.unlinkedLedger,
    required this.dateBoundary,
  });

  final String month;
  final double paymentTotal;
  final double reportTotal;
  final double excess;
  final List<LedgerOvercountEntry> unlinkedLedger;
  final List<DateBoundaryMismatch> dateBoundary;
}

bool _isReceiptDestination(String destination) =>
    destination == 'current_month_maintenance' || destination == 'corpus';

/// Matches FinanceManager period-report receipt logic for each calendar month.
List<LedgerOvercountMonth> analyzeLedgerOvercountByMonth(
  List<AuditPaymentRow> verifiedPayments,
  List<AuditLedgerRow> allLedger,
) {
  final linkedFeIds = <String>{
    for (final p in verifiedPayments)
      if (p.hasFinanceEntry) p.financeEntryId!,
  };
  final ledgerById = {for (final e in allLedger) e.id: e};

  final monthlyPaymentTotals = <String, double>{};
  for (final p in verifiedPayments) {
    final d = p.billingDate;
    if (d.isEmpty) continue;
    final month = ymOf(d);
    if (month == null) continue;
    monthlyPaymentTotals[month] = (monthlyPaymentTotals[month] ?? 0) + p.amount;
  }

  final months = <String>{...monthlyPaymentTotals.keys};
  for (final e in allLedger) {
    if (!_isReceiptDestination(e.destination)) continue;
    final m = ymOf(e.ledgerDate);
    if (m != null && m.isNotEmpty) months.add(m);
  }

  final issues = <LedgerOvercountMonth>[];
  for (final month in months) {
    final bounds = monthBoundsMs(month);
    if (bounds == null) continue;

    var reportTotal = 0.0;
    for (final p in verifiedPayments) {
      final d = p.billingDate;
      if (d.isEmpty) continue;
      final t = jsTimeMs(d);
      if (t != null && t >= bounds.fromMs && t <= bounds.toMs)
        reportTotal += p.amount;
    }

    final unlinked = <LedgerOvercountEntry>[];
    for (final e in allLedger) {
      if (!_isReceiptDestination(e.destination)) continue;
      final t = jsTimeMs(e.ledgerDate);
      if (t == null || t < bounds.fromMs || t > bounds.toMs) continue;
      if (!linkedFeIds.contains(e.id)) {
        reportTotal += e.totalAmount;
        unlinked.add(LedgerOvercountEntry(
          id: e.id,
          title: e.title,
          totalAmount: e.totalAmount,
          entryMonth: e.entryMonth,
          recordMode: e.recordMode,
          destination: e.destination,
          paymentMethod: e.paymentMethod,
          createdAt: e.createdAt,
        ));
      }
    }

    final paymentTotal = monthlyPaymentTotals[month] ?? 0;
    final excess = reportTotal - paymentTotal;
    if (excess <= 1) continue;

    final boundary = <DateBoundaryMismatch>[];
    for (final p in verifiedPayments) {
      if (!p.hasFinanceEntry) continue;
      final entry = ledgerById[p.financeEntryId];
      if (entry == null) continue;
      final pDate = p.billingDate;
      final pMonth = pDate.isNotEmpty ? (ymOf(pDate) ?? '') : '';
      final eMonth = _truthy(entry.entryMonth)
          ? entry.entryMonth!
          : (_truthy(entry.transactionDate)
              ? (ymOf(entry.transactionDate) ?? '')
              : '');
      if (pMonth.isNotEmpty &&
          eMonth.isNotEmpty &&
          pMonth != eMonth &&
          (pMonth == month || eMonth == month)) {
        boundary.add(DateBoundaryMismatch(
          payment: p,
          paymentMonth: pMonth,
          entryMonth: eMonth,
          entryTitle: entry.title,
          entryId: entry.id,
        ));
      }
    }

    issues.add(LedgerOvercountMonth(
      month: month,
      paymentTotal: paymentTotal,
      reportTotal: reportTotal,
      excess: excess,
      unlinkedLedger: unlinked,
      dateBoundary: boundary,
    ));
  }

  return stableSorted(issues, (a, b) => jsLocaleCompare(b.month, a.month));
}

/* ─── Channel balance tracing (negative cash / bank) ─── */

enum BalanceTxnType { receipt, expense }

enum BalanceTxnSource { payment, ledger }

class BalanceTransaction {
  const BalanceTransaction({
    required this.date,
    required this.type,
    required this.amount,
    required this.channel,
    required this.source,
    required this.id,
    required this.label,
  });

  final String date;
  final BalanceTxnType type;
  final double amount;
  final PaymentChannel channel;
  final BalanceTxnSource source;
  final String id;
  final String label;
}

class ChannelBalanceCulprit {
  const ChannelBalanceCulprit({
    required this.date,
    required this.label,
    required this.amount,
    required this.type,
    required this.balanceAfter,
    required this.source,
    required this.id,
  });

  final String date;
  final String label;
  final double amount;
  final BalanceTxnType type;
  final double balanceAfter;
  final BalanceTxnSource source;
  final String id;
}

class ChannelMonthlyBalance {
  const ChannelMonthlyBalance({
    required this.month,
    required this.receipts,
    required this.expenses,
    required this.netChange,
    required this.closingBalance,
  });

  final String month;
  final double receipts;
  final double expenses;
  final double netChange;
  final double closingBalance;
}

class ChannelBalanceTrace {
  const ChannelBalanceTrace({
    required this.channel,
    required this.finalBalance,
    required this.firstNegativeDate,
    required this.firstNegativeMonth,
    required this.balanceBeforeFault,
    required this.culprits,
    required this.monthlyBreakdown,
  });

  final PaymentChannel channel;
  final double finalBalance;
  final String? firstNegativeDate;
  final String? firstNegativeMonth;
  final double balanceBeforeFault;
  final List<ChannelBalanceCulprit> culprits;
  final List<ChannelMonthlyBalance> monthlyBreakdown;
}

/// Billing date → payment date → created date (first 10 chars).
String paymentTransactionDate(AuditPaymentRow p) {
  final billing = p.billingDate;
  if (billing.isNotEmpty) return billing;
  final pd = slice10(p.paymentDate);
  if (pd.isNotEmpty) return pd;
  return slice10(p.createdAt);
}

String _ledgerMonthKey(AuditLedgerRow e) {
  if (_truthy(e.entryMonth)) return jsSlice(e.entryMonth, 0, 7);
  final d = e.ledgerDate;
  return d.isNotEmpty ? (ymOf(d) ?? '') : '';
}

List<BalanceTransaction> buildChannelTransactions(
  List<AuditPaymentRow> verifiedPayments,
  List<AuditLedgerRow> allLedger,
  Set<String> linkedFeIds, {
  bool hi = false,
}) {
  final txns = <BalanceTransaction>[];
  for (final p in verifiedPayments) {
    final date = paymentTransactionDate(p);
    if (date.isEmpty) continue;
    txns.add(BalanceTransaction(
      date: date,
      type: BalanceTxnType.receipt,
      amount: p.amount,
      channel: normalizePaymentChannel(p.paymentMethod),
      source: BalanceTxnSource.payment,
      id: p.id,
      label: _l(hi, 'Flat ${p.flatNumber} maintenance receipt',
          'फ्लैट ${p.flatNumber} रखरखाव रसीद'),
    ));
  }
  for (final e in allLedger) {
    final date = e.ledgerDate;
    if (date.isEmpty) continue;
    final ch = normalizePaymentChannel(e.paymentMethod);
    if (e.destination == 'separate_entry') {
      txns.add(BalanceTransaction(
        date: date,
        type: BalanceTxnType.expense,
        amount: e.totalAmount,
        channel: ch,
        source: BalanceTxnSource.ledger,
        id: e.id,
        label: _truthy(e.title)
            ? e.title!
            : _l(hi, 'Expense entry', 'खर्च प्रविष्टि'),
      ));
    } else if (!linkedFeIds.contains(e.id)) {
      txns.add(BalanceTransaction(
        date: date,
        type: BalanceTxnType.receipt,
        amount: e.totalAmount,
        channel: ch,
        source: BalanceTxnSource.ledger,
        id: e.id,
        label: _truthy(e.title)
            ? e.title!
            : _l(hi, 'Ledger receipt (no linked payments)',
                'लेजर रसीद (कोई जुड़ा भुगतान नहीं)'),
      ));
    }
  }
  return txns;
}

/// Running balance per channel; finds the first date the balance turns negative.
ChannelBalanceTrace? traceChannelBalanceDeficit(
    List<BalanceTransaction> transactions, PaymentChannel channel) {
  final channelTxns =
      stableSorted(transactions.where((t) => t.channel == channel),
          (BalanceTransaction a, BalanceTransaction b) {
    final cmp = jsLocaleCompare(a.date, b.date);
    if (cmp != 0) return cmp;
    if (a.type == b.type) return 0;
    return a.type == BalanceTxnType.receipt ? -1 : 1;
  });
  if (channelTxns.isEmpty) return null;

  var balance = 0.0;
  String? firstNegativeDate;
  String? firstNegativeMonth;
  var balanceBeforeFault = 0.0;
  final culprits = <ChannelBalanceCulprit>[];
  final monthly = <String, ({double receipts, double expenses})>{};

  for (final t in channelTxns) {
    final month = jsSlice(t.date, 0, 7);
    final m = monthly[month] ?? (receipts: 0.0, expenses: 0.0);
    monthly[month] = t.type == BalanceTxnType.receipt
        ? (receipts: m.receipts + t.amount, expenses: m.expenses)
        : (receipts: m.receipts, expenses: m.expenses + t.amount);

    final prev = balance;
    balance += t.type == BalanceTxnType.receipt ? t.amount : -t.amount;

    ChannelBalanceCulprit culprit() => ChannelBalanceCulprit(
          date: t.date,
          label: t.label,
          amount: t.amount,
          type: t.type,
          balanceAfter: balance,
          source: t.source,
          id: t.id,
        );

    if (firstNegativeDate == null && prev >= 0 && balance < 0) {
      firstNegativeDate = t.date;
      firstNegativeMonth = month;
      balanceBeforeFault = prev;
      culprits.add(culprit());
    } else if (firstNegativeDate == t.date) {
      culprits.add(culprit());
    }
  }

  final breakdown = <ChannelMonthlyBalance>[];
  var running = 0.0;
  final sortedMonths = monthly.keys.toList()..sort();
  for (final month in sortedMonths) {
    final v = monthly[month]!;
    final net = v.receipts - v.expenses;
    running += net;
    breakdown.add(ChannelMonthlyBalance(
      month: month,
      receipts: v.receipts,
      expenses: v.expenses,
      netChange: net,
      closingBalance: running,
    ));
  }

  return ChannelBalanceTrace(
    channel: channel,
    finalBalance: balance,
    firstNegativeDate: firstNegativeDate,
    firstNegativeMonth: firstNegativeMonth,
    balanceBeforeFault: balanceBeforeFault,
    culprits: culprits,
    monthlyBreakdown: breakdown,
  );
}

/* ─── Recording vs reporting mismatch by month ─── */

enum MismatchSourceKind { orphanPayment, orphanLedger, amountDiff }

class RecordingMismatchSource {
  const RecordingMismatchSource({
    required this.kind,
    required this.id,
    required this.date,
    required this.label,
    required this.amount,
  });

  final MismatchSourceKind kind;
  final String id;
  final String date;
  final String label;
  final double amount;

  /// Web id: `orphan_payment` | `orphan_ledger` | `amount_diff`.
  String get kindId => switch (kind) {
        MismatchSourceKind.orphanPayment => 'orphan_payment',
        MismatchSourceKind.orphanLedger => 'orphan_ledger',
        MismatchSourceKind.amountDiff => 'amount_diff',
      };
}

class RecordingMismatchMonth {
  const RecordingMismatchMonth({
    required this.month,
    required this.paymentsTotal,
    required this.ledgerTotal,
    required this.difference,
    required this.sources,
  });

  final String month;
  final double paymentsTotal;
  final double ledgerTotal;
  final double difference;
  final List<RecordingMismatchSource> sources;
}

bool _isVerifiedFlatsOnly(AuditLedgerRow e) =>
    e.recordMode == 'flats_only' && e.paymentStatus == 'verified';

List<RecordingMismatchMonth> analyzeRecordingMismatchByMonth(
  List<AuditPaymentRow> verifiedPayments,
  List<AuditLedgerRow> allLedger, {
  bool hi = false,
}) {
  final months = <String>{};
  for (final p in verifiedPayments) {
    final d = paymentTransactionDate(p);
    if (d.isNotEmpty) months.add(jsSlice(d, 0, 7));
  }
  for (final e in allLedger) {
    if (!_isVerifiedFlatsOnly(e)) continue;
    final m = _ledgerMonthKey(e);
    if (m.isNotEmpty) months.add(m);
  }

  final issues = <RecordingMismatchMonth>[];
  for (final month in months) {
    var paymentsTotal = 0.0;
    final monthPayments = <AuditPaymentRow>[];
    for (final p in verifiedPayments) {
      final d = paymentTransactionDate(p);
      if (d.isEmpty || jsSlice(d, 0, 7) != month) continue;
      paymentsTotal += p.amount;
      monthPayments.add(p);
    }

    var ledgerTotal = 0.0;
    final monthLedger = <AuditLedgerRow>[];
    for (final e in allLedger) {
      if (!_isVerifiedFlatsOnly(e)) continue;
      if (_ledgerMonthKey(e) != month) continue;
      ledgerTotal += e.totalAmount;
      monthLedger.add(e);
    }

    final difference = paymentsTotal - ledgerTotal;
    if (difference.abs() <= 1) continue;

    final sources = <RecordingMismatchSource>[];
    for (final p in monthPayments) {
      if (!p.hasFinanceEntry) {
        sources.add(RecordingMismatchSource(
          kind: MismatchSourceKind.orphanPayment,
          id: p.id,
          date: paymentTransactionDate(p),
          label: _l(hi, 'Flat ${p.flatNumber} — no ledger link',
              'फ्लैट ${p.flatNumber} — कोई लेजर लिंक नहीं'),
          amount: p.amount,
        ));
      }
    }
    for (final e in monthLedger) {
      final linked = monthPayments.any((p) => p.financeEntryId == e.id);
      if (!linked) {
        sources.add(RecordingMismatchSource(
          kind: MismatchSourceKind.orphanLedger,
          id: e.id,
          date: e.ledgerDate,
          label: _truthy(e.title)
              ? e.title!
              : _l(hi, 'Ledger entry — no linked payments',
                  'लेजर प्रविष्टि — कोई जुड़ा भुगतान नहीं'),
          amount: e.totalAmount,
        ));
      }
    }

    issues.add(RecordingMismatchMonth(
      month: month,
      paymentsTotal: paymentsTotal,
      ledgerTotal: ledgerTotal,
      difference: difference,
      sources: sources,
    ));
  }

  return stableSorted(
      issues, (a, b) => numDesc(a.difference.abs(), b.difference.abs()));
}

String formatChannelBalanceFaultTrace(ChannelBalanceTrace trace,
    {bool hi = false}) {
  final firstDate = trace.firstNegativeDate;
  if (firstDate == null) {
    return _l(
      hi,
      'Could not pinpoint the exact date — review channel entries in Reports → Financial.',
      'सटीक तिथि का पता नहीं चल सका — रिपोर्ट → वित्तीय में माध्यम की प्रविष्टियाँ जाँचें।',
    );
  }

  final monthLabel = trace.firstNegativeMonth ?? jsSlice(firstDate, 0, 7);
  final culpritLines = trace.culprits.take(4).map((c) {
    final kind = c.type == BalanceTxnType.expense
        ? _l(hi, 'Expense', 'खर्च')
        : _l(hi, 'Receipt', 'रसीद');
    return hi
        ? '  • ${c.date}: $kind "${c.label}" ${jsInr(c.amount)} → शेष ${jsInr(c.balanceAfter)}'
        : '  • ${c.date}: $kind "${c.label}" ${jsInr(c.amount)} → balance ${jsInr(c.balanceAfter)}';
  }).join('\n');

  final fromMonth = trace.firstNegativeMonth ?? '';
  final monthLines = trace.monthlyBreakdown
      .where((m) => m.closingBalance < 0 || m.month.compareTo(fromMonth) >= 0)
      .take(6)
      .map((m) => hi
          ? '  • ${m.month}: रसीदें ${jsInr(m.receipts)} − खर्च ${jsInr(m.expenses)} → अंतिम शेष ${jsInr(m.closingBalance)}'
          : '  • ${m.month}: receipts ${jsInr(m.receipts)} − expenses ${jsInr(m.expenses)} → closing ${jsInr(m.closingBalance)}')
      .join('\n');

  return [
    hi
        ? 'गड़बड़ी का आरंभ: $firstDate ($monthLabel) — इस तिथि से पहले शेष ${jsInr(trace.balanceBeforeFault)} था।'
        : 'Fault origin: $firstDate ($monthLabel) — balance was ${jsInr(trace.balanceBeforeFault)} before this date.',
    if (culpritLines.isNotEmpty)
      '${_l(hi, 'Entries on fault date:', 'गड़बड़ी की तिथि की प्रविष्टियाँ:')}\n$culpritLines',
    if (monthLines.isNotEmpty)
      '${_l(hi, 'Month-wise trail from fault:', 'गड़बड़ी से माहवार क्रम:')}\n$monthLines',
  ].join('\n\n');
}

String formatRecordingMismatchFaultTrace(List<RecordingMismatchMonth> issues,
    {bool hi = false}) {
  if (issues.isEmpty) return '';
  final chronological =
      stableSorted(issues, (a, b) => jsLocaleCompare(a.month, b.month));
  final lines = chronological.map((m) {
    final dir = m.difference > 0
        ? _l(hi, 'payments exceed ledger', 'भुगतान लेजर से अधिक')
        : _l(hi, 'ledger exceeds payments', 'लेजर भुगतान से अधिक');
    final sourceHint = m.sources.isNotEmpty
        ? ' — ${_l(hi, 'entries', 'प्रविष्टियाँ')}: ${m.sources.map((s) => '${s.date} ${s.label} (${jsInr(s.amount)})').join('; ')}'
        : '';
    return '  • ${m.month}: ${jsInr(m.difference.abs())} ($dir)$sourceHint';
  });
  final earliest = chronological.first;
  return [
    '${_l(hi, 'Earliest affected month', 'सबसे पहला प्रभावित माह')}: ${earliest.month}',
    '${_l(hi, 'Months with mismatch (oldest first):', 'अंतर वाले माह (पुराने पहले):')}\n${lines.join('\n')}',
  ].join('\n\n');
}

/* ─── Chronological fix queue for self-audit ─── */

enum AuditFixAction {
  delete,
  edit,
  alignPaymentMonth,
  alignLedgerMonth,
  review
}

enum FixSeverity { critical, warning, info }

enum FixEntryKind { payment, ledger }

enum FixFindingKind {
  duplicatePayments,
  ledgerOvercount,
  recordingMismatch,
  orphanedPayments,
  channelBalance
}

class AuditFixQueueItem {
  const AuditFixQueueItem({
    required this.queueKey,
    required this.sortDate,
    required this.month,
    required this.issueLabel,
    required this.entryKind,
    required this.entryId,
    required this.title,
    required this.amount,
    required this.detail,
    required this.action,
    required this.actionHint,
    required this.severity,
    required this.findingKind,
    this.alignTargetMonth,
    this.relatedEntryId,
    this.financeEntryId,
  });

  final String queueKey;
  final String sortDate;
  final String month;
  final String issueLabel;
  final FixEntryKind entryKind;
  final String entryId;
  final String title;
  final double amount;
  final String detail;
  final AuditFixAction action;
  final String actionHint;
  final FixSeverity severity;
  final FixFindingKind findingKind;
  final String? alignTargetMonth;
  final String? relatedEntryId;
  final String? financeEntryId;
}

class AuditFixQueueInput {
  const AuditFixQueueInput({
    required this.duplicateGroups,
    required this.ledgerOvercountIssues,
    required this.recordingMismatchMonths,
    required this.orphanedPayments,
    required this.cashTrace,
    required this.bankTrace,
  });

  final List<DuplicatePaymentGroup> duplicateGroups;
  final List<LedgerOvercountMonth> ledgerOvercountIssues;
  final List<RecordingMismatchMonth> recordingMismatchMonths;
  final List<AuditPaymentRow> orphanedPayments;
  final ChannelBalanceTrace? cashTrace;
  final ChannelBalanceTrace? bankTrace;
}

/// Channel label used in fix-queue text (`Cash` / `Bank/UPI` / `Other`).
String channelLabel(PaymentChannel ch, {bool hi = false}) => switch (ch) {
      PaymentChannel.cash => _l(hi, 'Cash', 'नकद'),
      PaymentChannel.bank => _l(hi, 'Bank/UPI', 'बैंक/UPI'),
      PaymentChannel.other => _l(hi, 'Other', 'अन्य'),
    };

/// Ordered list of exact entries to inspect — earliest discrepancy date first.
List<AuditFixQueueItem> buildAuditFixQueue(AuditFixQueueInput input,
    {bool hi = false}) {
  final items = <AuditFixQueueItem>[];
  final seen = <String>{};
  void push(AuditFixQueueItem item) {
    if (seen.contains(item.entryId)) return;
    seen.add(item.entryId);
    items.add(item);
  }

  for (final group in input.duplicateGroups) {
    final sorted = stableSorted(
      group.payments,
      (AuditPaymentRow a, AuditPaymentRow b) =>
          jsLocaleCompare(paymentTransactionDate(a), paymentTransactionDate(b)),
    );
    for (var idx = 0; idx < sorted.length; idx++) {
      final p = sorted[idx];
      final isExtra = idx > 0;
      push(AuditFixQueueItem(
        queueKey: 'dupe-${p.id}',
        sortDate: paymentTransactionDate(p),
        month: group.month,
        issueLabel: _l(hi, 'Duplicate payment', 'डुप्लिकेट भुगतान'),
        entryKind: FixEntryKind.payment,
        entryId: p.id,
        title: _l(hi, 'Flat ${group.flatNumber} — ${group.chargeTitle}',
            'फ्लैट ${group.flatNumber} — ${group.chargeTitle}'),
        amount: p.amount,
        detail: hi
            ? '${group.paymentMethod.toUpperCase()} · ${fmtIsoMonthToDisplay(group.month)} · एक ही रसीद शीर्ष के लिए ${group.count} पंक्तियाँ'
            : '${group.paymentMethod.toUpperCase()} · ${fmtIsoMonthToDisplay(group.month)} · ${group.count} rows for same receipt head',
        action: isExtra ? AuditFixAction.delete : AuditFixAction.review,
        actionHint: isExtra
            ? _l(
                hi,
                'Delete this extra duplicate — keep one verified row per flat per billing month',
                'यह अतिरिक्त डुप्लिकेट हटाएँ — प्रति फ्लैट प्रति बिलिंग माह एक सत्यापित पंक्ति रखें')
            : _l(
                hi,
                'Keep this entry — delete the newer duplicate(s) for this flat/month',
                'यह प्रविष्टि रखें — इस फ्लैट/माह की नई डुप्लिकेट प्रविष्टियाँ हटाएँ'),
        severity: FixSeverity.critical,
        findingKind: FixFindingKind.duplicatePayments,
        financeEntryId: p.financeEntryId,
      ));
    }
  }

  for (final issue in input.ledgerOvercountIssues) {
    for (final e in issue.unlinkedLedger) {
      push(AuditFixQueueItem(
        queueKey: 'ledger-orphan-${e.id}',
        sortDate: e.ledgerDate,
        month: issue.month,
        issueLabel: _l(hi, 'Orphan ledger receipt', 'बिना लिंक की लेजर रसीद'),
        entryKind: FixEntryKind.ledger,
        entryId: e.id,
        title: _truthy(e.title)
            ? e.title!
            : _l(hi, 'Ledger entry', 'लेजर प्रविष्टि'),
        amount: e.totalAmount,
        detail: hi
            ? '${fmtIsoMonthToDisplay(issue.month)} की अवधि रिपोर्ट बढ़ाता है — कोई जुड़ा रखरखाव भुगतान नहीं'
            : 'Inflates ${fmtIsoMonthToDisplay(issue.month)} period report — no linked maintenance payment',
        action: AuditFixAction.delete,
        actionHint: _l(hi, 'Delete this orphan finance_entries row',
            'यह बिना लिंक की finance_entries पंक्ति हटाएँ'),
        severity: FixSeverity.critical,
        findingKind: FixFindingKind.ledgerOvercount,
      ));
    }
    for (final row in issue.dateBoundary) {
      final titleSuffix = _truthy(row.entryTitle) ? ' — ${row.entryTitle}' : '';
      push(AuditFixQueueItem(
        queueKey: 'boundary-pay-${row.payment.id}',
        sortDate: paymentTransactionDate(row.payment),
        month: issue.month,
        issueLabel: _l(hi, 'Payment vs ledger month mismatch',
            'भुगतान बनाम लेजर माह असंगति'),
        entryKind: FixEntryKind.payment,
        entryId: row.payment.id,
        title: _l(hi, 'Flat ${row.payment.flatNumber}$titleSuffix',
            'फ्लैट ${row.payment.flatNumber}$titleSuffix'),
        amount: row.payment.amount,
        detail: hi
            ? 'भुगतान माह ${row.paymentMonth} ≠ लेजर माह ${row.entryMonth}'
            : 'Payment month ${row.paymentMonth} ≠ ledger month ${row.entryMonth}',
        action: AuditFixAction.alignPaymentMonth,
        actionHint: hi
            ? 'भुगतान की देय तिथि ${row.entryMonth} पर करें, या लेजर ${row.paymentMonth} पर करें'
            : 'Align payment due date to ${row.entryMonth}, or align ledger to ${row.paymentMonth}',
        severity: FixSeverity.critical,
        findingKind: FixFindingKind.ledgerOvercount,
        alignTargetMonth: row.entryMonth,
        relatedEntryId: row.entryId,
        financeEntryId: row.payment.financeEntryId,
      ));
    }
  }

  final mismatchMonths = stableSorted(input.recordingMismatchMonths,
      (a, b) => jsLocaleCompare(a.month, b.month));
  for (final monthIssue in mismatchMonths) {
    final sources = stableSorted(
        monthIssue.sources,
        (RecordingMismatchSource a, RecordingMismatchSource b) =>
            jsLocaleCompare(a.date, b.date));
    for (final source in sources) {
      final isOrphanLedger = source.kind == MismatchSourceKind.orphanLedger;
      final isOrphanPayment = source.kind == MismatchSourceKind.orphanPayment;
      push(AuditFixQueueItem(
        queueKey: 'rec-${source.kindId}-${source.id}',
        sortDate: slice10(source.date),
        month: monthIssue.month,
        issueLabel: isOrphanPayment
            ? _l(hi, 'Orphan payment (no ledger)',
                'बिना लिंक भुगतान (लेजर नहीं)')
            : _l(hi, 'Orphan ledger (no payment)',
                'बिना लिंक लेजर (भुगतान नहीं)'),
        entryKind: isOrphanLedger ? FixEntryKind.ledger : FixEntryKind.payment,
        entryId: source.id,
        title: source.label,
        amount: source.amount,
        detail: hi
            ? '${fmtIsoMonthToDisplay(monthIssue.month)} में दर्ज बनाम लेजर अंतर — ${jsInr(monthIssue.difference.abs())} असंगति'
            : 'Recording vs ledger gap in ${fmtIsoMonthToDisplay(monthIssue.month)} — ${jsInr(monthIssue.difference.abs())} mismatch',
        action: AuditFixAction.delete,
        actionHint: isOrphanPayment
            ? _l(hi, 'Delete orphan payment or re-record with ledger link',
                'बिना लिंक भुगतान हटाएँ या लेजर लिंक के साथ फिर से दर्ज करें')
            : _l(hi, 'Delete orphan ledger row if it has no linked payments',
                'यदि कोई जुड़ा भुगतान नहीं है तो बिना लिंक लेजर पंक्ति हटाएँ'),
        severity: FixSeverity.warning,
        findingKind: FixFindingKind.recordingMismatch,
      ));
    }
  }

  for (final p in input.orphanedPayments) {
    final sortDate = paymentTransactionDate(p);
    final month =
        sortDate.isNotEmpty ? (ymOf(sortDate) ?? 'unknown') : 'unknown';
    push(AuditFixQueueItem(
      queueKey: 'orphan-pay-${p.id}',
      sortDate: sortDate.isNotEmpty ? sortDate : '9999-12-31',
      month: month,
      issueLabel: _l(hi, 'Orphan payment', 'बिना लिंक भुगतान'),
      entryKind: FixEntryKind.payment,
      entryId: p.id,
      title: _l(hi, 'Flat ${p.flatNumber}', 'फ्लैट ${p.flatNumber}'),
      amount: p.amount,
      detail: _l(hi, 'Verified payment with no finance_entry_id',
          'सत्यापित भुगतान जिसका finance_entry_id नहीं है'),
      action: AuditFixAction.delete,
      actionHint: _l(
          hi,
          'Delete if mistaken, or re-record from Finance → Payments with ledger',
          'गलत हो तो हटाएँ, या वित्त → भुगतान से लेजर के साथ फिर से दर्ज करें'),
      severity: FixSeverity.warning,
      findingKind: FixFindingKind.orphanedPayments,
    ));
  }

  for (final trace in [input.cashTrace, input.bankTrace]) {
    if (trace == null || trace.firstNegativeDate == null) continue;
    final chLabel = channelLabel(trace.channel, hi: hi);
    for (final c in trace.culprits) {
      final kind = c.type == BalanceTxnType.expense
          ? _l(hi, 'Expense', 'खर्च')
          : _l(hi, 'Receipt', 'रसीद');
      push(AuditFixQueueItem(
        queueKey: 'channel-${trace.channel.name}-${c.id}',
        sortDate: c.date,
        month: jsSlice(c.date, 0, 7),
        issueLabel: hi
            ? 'ऋणात्मक $chLabel शेष'
            : 'Negative ${chLabel.toLowerCase()} balance',
        entryKind: c.source == BalanceTxnSource.payment
            ? FixEntryKind.payment
            : FixEntryKind.ledger,
        entryId: c.id,
        title: c.label,
        amount: c.amount,
        detail: hi
            ? 'गड़बड़ी की तिथि पर $kind → शेष ${jsInr(c.balanceAfter)}'
            : '$kind on fault date → balance ${jsInr(c.balanceAfter)}',
        action: AuditFixAction.review,
        actionHint: hi
            ? 'payment_method माध्यम टैग जाँचें — वित्त → लेन-देन ($chLabel) में संपादन या हटाना पड़ सकता है'
            : 'Review payment_method channel tag — may need edit or delete in Finance → Transactions ($chLabel)',
        severity: FixSeverity.critical,
        findingKind: FixFindingKind.channelBalance,
      ));
    }
  }

  return stableSorted(items, (a, b) {
    final dateCmp = jsLocaleCompare(a.sortDate, b.sortDate);
    if (dateCmp != 0) return dateCmp;
    return a.severity.index.compareTo(b.severity.index);
  });
}

/// `paymentMonthKey` from `financeAuditRemediation.ts`.
String paymentMonthKey(
    {String? dueDate, String? paymentDate, String? createdAt}) {
  final d = _truthy(dueDate)
      ? dueDate!
      : (_truthy(paymentDate) ? paymentDate! : (createdAt ?? ''));
  return d.isNotEmpty ? (ymOf(d) ?? '') : '';
}
