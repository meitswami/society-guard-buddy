import 'finance_dates.dart';
import 'finance_heads.dart';
import 'finance_period_report.dart';
import 'flat_sort.dart';
import 'js_compat.dart';
import 'report_formatters.dart';

/// Port of `src/lib/cashFlowStatement.ts`.

enum StatementEntryType { receipt, expense, reserve, corpus }

enum StatementSource { payment, ledger, reserve }

class StatementEntry {
  const StatementEntry({
    required this.id,
    required this.date,
    required this.label,
    this.sublabel,
    required this.amount,
    required this.type,
    required this.channel,
    this.recordMode,
    this.destination,
    this.paymentMethod,
    this.notes,
    this.transactionId,
    this.aggregateFlatCount,
    this.source,
    this.expenseHead,
    this.runningBalance,
  });

  final String id;
  final String date;
  final String label;
  final String? sublabel;
  final double amount;
  final StatementEntryType type;
  final PaymentChannel channel;
  final String? recordMode;
  final String? destination;
  final String? paymentMethod;
  final String? notes;
  final String? transactionId;
  final double? aggregateFlatCount;
  final StatementSource? source;
  final String? expenseHead;

  /// Set by [addRunningBalance].
  final double? runningBalance;

  StatementEntry withRunningBalance(double bal) => StatementEntry(
        id: id,
        date: date,
        label: label,
        sublabel: sublabel,
        amount: amount,
        type: type,
        channel: channel,
        recordMode: recordMode,
        destination: destination,
        paymentMethod: paymentMethod,
        notes: notes,
        transactionId: transactionId,
        aggregateFlatCount: aggregateFlatCount,
        source: source,
        expenseHead: expenseHead,
        runningBalance: bal,
      );
}

enum CashFlowSection { operating, investing, financing, summary }

enum CashFlowDrillKind {
  receipts,
  expenses,
  expenseHead,
  corpus,
  reserve,
  cashStatement,
  bankStatement
}

class CashFlowLine {
  const CashFlowLine({
    required this.id,
    required this.label,
    required this.amount,
    required this.section,
    this.indent = false,
    this.bold = false,
    this.drillable = false,
    this.drillKind,
    this.drillKey,
  });

  final String id;
  final String label;
  final double amount;
  final CashFlowSection section;
  final bool indent;
  final bool bold;
  final bool drillable;
  final CashFlowDrillKind? drillKind;
  final String? drillKey;

  bool get isSeparator => id.startsWith('sep');

  /// Section header rows (bold, zero amount, not indented).
  bool get isSectionHeader => bold && amount == 0 && !indent;
}

class CashBalances {
  const CashBalances(
      {required this.cash,
      required this.bank,
      required this.other,
      required this.total});

  final double cash;
  final double bank;
  final double other;
  final double total;
}

class CashFlowResult {
  const CashFlowResult({
    required this.lines,
    required this.periodReport,
    required this.opening,
    required this.closing,
    required this.netChange,
    required this.periodReceipts,
    required this.periodExpenses,
    required this.expenseByHead,
    required this.statementEntries,
    required this.maintenanceReceipts,
    required this.corpusReceipts,
  });

  final List<CashFlowLine> lines;
  final FinancePeriodReportResult periodReport;
  final CashBalances opening;
  final CashBalances closing;
  final CashBalances netChange;
  final double periodReceipts;
  final double periodExpenses;
  final List<(String, double)> expenseByHead;
  final List<StatementEntry> statementEntries;
  final double maintenanceReceipts;
  final double corpusReceipts;
}

String _reserveTransferDate(FinancePeriodReserveTransfer r) =>
    '${r.entryMonth}-01';

bool _isReserveOutflow(String direction) =>
    direction == 'operating_to_reserve' ||
    direction == 'reserve_to_fixed' ||
    direction == 'reserve_to_emergency';

StatementEntry _reserveToStatement(FinancePeriodReserveTransfer r) {
  final outflow = _isReserveOutflow(r.direction);
  return StatementEntry(
    id: r.id,
    date: _reserveTransferDate(r),
    label: r.direction.replaceAll('_', ' '),
    sublabel: (r.notes == null || r.notes!.isEmpty)
        ? 'Reserve fund transfer'
        : r.notes,
    amount: outflow ? -r.amount : r.amount,
    type: StatementEntryType.reserve,
    channel: normalizePaymentChannel(r.paymentMethod),
    paymentMethod: r.paymentMethod,
    notes: r.notes,
    source: StatementSource.reserve,
  );
}

/// Chronological statement rows — same sources as Finance → Transactions.
List<StatementEntry> buildPeriodStatementEntries({
  required String periodFrom,
  required String periodTo,
  required List<FinancePeriodPayment> payments,
  required List<FinancePeriodLedgerEntry> ledgerEntries,
  List<FinancePeriodReserveTransfer> reserveTransfers = const [],
  Map<String, String>? expenseCategoryById,
}) {
  final categories = expenseCategoryById ?? const <String, String>{};
  final allLinkedFeIds = collectLinkedFinanceEntryIds(payments);
  final entries = <StatementEntry>[];

  for (final p in payments) {
    if (!p.isVerified) continue;
    final d = p.billingDate;
    if (d.isEmpty || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    entries.add(StatementEntry(
      id: p.id ?? 'mp-$d-${p.flatNumber}',
      date: d,
      label: 'Maintenance receipt · Flat ${p.flatNumber ?? '—'}',
      sublabel: (p.residentName == null || p.residentName!.isEmpty)
          ? null
          : p.residentName,
      amount: p.amount,
      type: StatementEntryType.receipt,
      channel: normalizePaymentChannel(p.paymentMethod),
      paymentMethod: p.paymentMethod,
      notes: p.notes,
      transactionId: p.transactionId,
      destination: 'current_month_maintenance',
      source: StatementSource.payment,
    ));
  }

  for (final e in ledgerEntries) {
    if (!e.isVerified) continue;
    final ledgerDate = e.ledgerDate;
    if (ledgerDate.isEmpty ||
        !dateInInclusiveRange(ledgerDate, periodFrom, periodTo)) {
      continue;
    }
    final ch = normalizePaymentChannel(e.paymentMethod);
    final isCorpus = e.destination == 'corpus';
    final method = (e.paymentMethod == null || e.paymentMethod!.isEmpty)
        ? 'N/A'
        : e.paymentMethod!;
    final hasTitle = e.title != null && e.title!.isNotEmpty;

    if (e.isExpense) {
      final head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expenseId != null && e.expenseId!.isNotEmpty
            ? categories[e.expenseId]
            : null,
      );
      entries.add(StatementEntry(
        id: e.id,
        date: ledgerDate,
        label: hasTitle ? e.title! : 'Society payment — $head',
        sublabel: 'Head: $head · $method',
        amount: -e.totalAmount,
        type: StatementEntryType.expense,
        channel: ch,
        recordMode: e.recordMode,
        destination: e.destination,
        paymentMethod: e.paymentMethod,
        notes: e.notes,
        transactionId: e.transactionId,
        aggregateFlatCount: e.aggregateFlatCount,
        source: StatementSource.ledger,
        expenseHead: head,
      ));
    } else if (e.isInflowDestination) {
      if (allLinkedFeIds.contains(e.id)) continue;
      entries.add(StatementEntry(
        id: e.id,
        date: ledgerDate,
        label: hasTitle
            ? e.title!
            : '${formatLedgerFieldLabel(e.recordMode, fallback: 'Ledger')} → ${formatLedgerFieldLabel(e.destination)}',
        sublabel: 'Method: $method',
        amount: e.totalAmount,
        type: isCorpus ? StatementEntryType.corpus : StatementEntryType.receipt,
        channel: ch,
        recordMode: e.recordMode,
        destination: e.destination,
        paymentMethod: e.paymentMethod,
        notes: e.notes,
        transactionId: e.transactionId,
        aggregateFlatCount: e.aggregateFlatCount,
        source: StatementSource.ledger,
      ));
    }
  }

  for (final r in reserveTransfers) {
    if (!dateInInclusiveRange(_reserveTransferDate(r), periodFrom, periodTo)) {
      continue;
    }
    entries.add(_reserveToStatement(r));
  }

  entries.sort((a, b) {
    final d = jsLocaleCompare(a.date, b.date);
    if (d != 0) return d;
    return jsLocaleCompare(a.label, b.label);
  });
  return entries;
}

CashFlowResult computeCashFlowStatement({
  required String periodFrom,
  required String periodTo,
  required List<FinancePeriodPayment> payments,
  required List<FinancePeriodLedgerEntry> ledgerEntries,
  List<FinancePeriodReserveTransfer> reserveTransfers = const [],
  Map<String, String>? expenseCategoryById,
  List<FinanceOpeningBalanceAnchor> openingBalanceAnchors = const [],
}) {
  final periodReport = computeFinancePeriodReport(
    periodFrom: periodFrom,
    periodTo: periodTo,
    payments: payments,
    ledgerEntries: ledgerEntries,
    expenseCategoryById: expenseCategoryById,
    openingBalanceAnchors: openingBalanceAnchors,
  );

  final periodReserve = reserveTransfers.where((r) =>
      dateInInclusiveRange(_reserveTransferDate(r), periodFrom, periodTo));

  var investingOut = 0.0;
  const investingIn = 0.0;
  var financingIn = 0.0;
  for (final r in periodReserve) {
    final amt = r.amount;
    if (_isReserveOutflow(r.direction)) {
      investingOut += amt;
    } else if (r.direction == 'reserve_to_operating') {
      financingIn += amt;
    }
  }

  final netOperating = periodReport.totalBalance;
  final netInvesting = investingIn - investingOut;
  final netFinancing = financingIn;
  final netChangeTotal = netOperating + netInvesting + netFinancing;

  final opening = CashBalances(
    cash: periodReport.openingCash,
    bank: periodReport.openingBank,
    other: periodReport.openingOther,
    total: periodReport.openingBalance,
  );
  final closing = CashBalances(
    cash: periodReport.closingCash,
    bank: periodReport.closingBank,
    other: periodReport.closingOther,
    total: periodReport.closingBalance,
  );
  final netChange = CashBalances(
    cash: periodReport.cashInHand,
    bank: periodReport.cashInBank,
    other: periodReport.otherNet,
    total: netChangeTotal,
  );

  final maintenanceReceipts = periodReport.maintenanceReceipts;
  final corpusReceipts = periodReport.corpusReceipts;
  final expenseByHeadFlat = [
    for (final h in periodReport.expenseByHead) (h.head, h.row.total)
  ];

  final lines = <CashFlowLine>[
    const CashFlowLine(
        id: 'sec-op',
        label: 'Operating Activities',
        amount: 0,
        section: CashFlowSection.operating,
        bold: true),
    CashFlowLine(
      id: 'op-receipts',
      label: 'Collections from members (verified receipts)',
      amount: maintenanceReceipts,
      section: CashFlowSection.operating,
      indent: true,
      drillable: maintenanceReceipts > 0,
      drillKind: CashFlowDrillKind.receipts,
    ),
    CashFlowLine(
      id: 'op-ledger-extra',
      label: 'Ledger-only inflows (not linked to receipts)',
      amount: periodReport.extraLedgerReceipt,
      section: CashFlowSection.operating,
      indent: true,
      drillable: periodReport.extraLedgerReceipt > 0,
      drillKind: CashFlowDrillKind.receipts,
    ),
    CashFlowLine(
      id: 'op-corpus',
      label: 'Corpus fund receipts',
      amount: corpusReceipts,
      section: CashFlowSection.operating,
      indent: true,
      drillable: corpusReceipts > 0,
      drillKind: CashFlowDrillKind.corpus,
    ),
    for (final (head, total) in expenseByHeadFlat)
      CashFlowLine(
        id: 'op-exp-$head',
        label: 'Payment — $head',
        amount: -total,
        section: CashFlowSection.operating,
        indent: true,
        drillable: true,
        drillKind: CashFlowDrillKind.expenseHead,
        drillKey: head,
      ),
    CashFlowLine(
      id: 'op-net',
      label: 'Net cash from operating activities',
      amount: netOperating,
      section: CashFlowSection.operating,
      bold: true,
    ),
    const CashFlowLine(
        id: 'sec-inv',
        label: 'Investing Activities',
        amount: 0,
        section: CashFlowSection.investing,
        bold: true),
    CashFlowLine(
      id: 'inv-reserve',
      label: 'Reserve fund transfers (out)',
      amount: -investingOut,
      section: CashFlowSection.investing,
      indent: true,
      drillable: investingOut > 0,
      drillKind: CashFlowDrillKind.reserve,
      drillKey: 'out',
    ),
    CashFlowLine(
      id: 'inv-net',
      label: 'Net cash from investing activities',
      amount: netInvesting,
      section: CashFlowSection.investing,
      bold: true,
    ),
    const CashFlowLine(
        id: 'sec-fin',
        label: 'Financing Activities',
        amount: 0,
        section: CashFlowSection.financing,
        bold: true),
    CashFlowLine(
      id: 'fin-reserve',
      label: 'Reserve draw to operating',
      amount: financingIn,
      section: CashFlowSection.financing,
      indent: true,
      drillable: financingIn > 0,
      drillKind: CashFlowDrillKind.reserve,
      drillKey: 'in',
    ),
    CashFlowLine(
      id: 'fin-net',
      label: 'Net cash from financing activities',
      amount: netFinancing,
      section: CashFlowSection.financing,
      bold: true,
    ),
    const CashFlowLine(
        id: 'sep1', label: '', amount: 0, section: CashFlowSection.summary),
    CashFlowLine(
      id: 'net-change',
      label: 'Net increase / (decrease) in cash & bank',
      amount: netChangeTotal,
      section: CashFlowSection.summary,
      bold: true,
    ),
    CashFlowLine(
      id: 'open-cash',
      label: 'Opening — Cash in hand',
      amount: opening.cash,
      section: CashFlowSection.summary,
      indent: true,
      drillable: true,
      drillKind: CashFlowDrillKind.cashStatement,
    ),
    CashFlowLine(
      id: 'open-bank',
      label: 'Opening — Balance in bank',
      amount: opening.bank,
      section: CashFlowSection.summary,
      indent: true,
      drillable: true,
      drillKind: CashFlowDrillKind.bankStatement,
    ),
    CashFlowLine(
      id: 'close-cash',
      label: 'Closing — Cash in hand',
      amount: closing.cash,
      section: CashFlowSection.summary,
      indent: true,
      drillable: true,
      drillKind: CashFlowDrillKind.cashStatement,
    ),
    CashFlowLine(
      id: 'close-bank',
      label: 'Closing — Balance in bank',
      amount: closing.bank,
      section: CashFlowSection.summary,
      indent: true,
      drillable: true,
      drillKind: CashFlowDrillKind.bankStatement,
    ),
  ];

  final statementEntries = buildPeriodStatementEntries(
    periodFrom: periodFrom,
    periodTo: periodTo,
    payments: payments,
    ledgerEntries: ledgerEntries,
    reserveTransfers: reserveTransfers,
    expenseCategoryById: expenseCategoryById,
  );

  return CashFlowResult(
    lines: lines,
    periodReport: periodReport,
    opening: opening,
    closing: closing,
    netChange: netChange,
    periodReceipts: periodReport.totalReceipts,
    periodExpenses: periodReport.totalExpenses,
    expenseByHead: expenseByHeadFlat,
    statementEntries: statementEntries,
    maintenanceReceipts: maintenanceReceipts,
    corpusReceipts: corpusReceipts,
  );
}

List<StatementEntry> filterStatementByChannel(
        List<StatementEntry> entries, PaymentChannel channel) =>
    entries.where((e) => e.channel == channel).toList();

List<StatementEntry> addRunningBalance(
    List<StatementEntry> entries, double openingBalance) {
  var bal = openingBalance;
  return [
    for (final e in entries) e.withRunningBalance(bal += e.amount),
  ];
}

String? _flatNumberFromStatementLabel(String label) =>
    RegExp(r'Flat\s+(\S+)', caseSensitive: false).firstMatch(label)?.group(1);

/// Flat maintenance receipts in numeric flat order (101 → 605); others interleaved by date.
List<StatementEntry> sortFlatMaintenanceReceiptEntries(
    List<StatementEntry> entries) {
  final list = [...entries];
  list.sort((a, b) {
    final byFlatOrDate = compareByFlatThenDate(
      _flatNumberFromStatementLabel(a.label),
      _flatNumberFromStatementLabel(b.label),
      a.date,
      b.date,
    );
    if (byFlatOrDate != 0) return byFlatOrDate;
    return jsLocaleCompare(a.label, b.label);
  });
  return list;
}

List<StatementEntry> filterStatementEntriesForDrill(
  List<StatementEntry> entries,
  CashFlowDrillKind kind, [
  String? drillKey,
]) {
  if (kind == CashFlowDrillKind.receipts) {
    return sortFlatMaintenanceReceiptEntries(
      entries
          .where((e) =>
              e.type == StatementEntryType.receipt ||
              e.type == StatementEntryType.corpus)
          .toList(),
    );
  }
  if (kind == CashFlowDrillKind.corpus) {
    return entries.where((e) => e.type == StatementEntryType.corpus).toList();
  }
  if (kind == CashFlowDrillKind.expenseHead &&
      drillKey != null &&
      drillKey.isNotEmpty) {
    return entries
        .where((e) =>
            e.type == StatementEntryType.expense && e.expenseHead == drillKey)
        .toList();
  }
  if (kind == CashFlowDrillKind.reserve) {
    return entries.where((e) => e.type == StatementEntryType.reserve).toList();
  }
  return entries;
}

/// Expose for the UI: `jsNumberString` of a value.
String statementNumber(num n) => jsNumberString(n);
