import 'finance_audit_detection.dart'
    show normalizePaymentChannel, PaymentChannel;
import 'finance_dates.dart';
import 'js_compat.dart';

/// Port of `src/lib/bankReconciliation.ts` (pure logic, no Flutter).

const int bankReconDateToleranceDays = 3;
const double highConfidenceThreshold = 0.8;

/// Error thrown by [parseBankStatementCsv] (web throws `Error` with the same text).
class BankCsvException implements Exception {
  const BankCsvException(this.code, this.message);

  /// `missing_date` | `missing_amount`
  final String code;
  final String message;

  @override
  String toString() => message;
}

class BankStatementCsvRow {
  const BankStatementCsvRow({
    required this.lineDate,
    required this.amount,
    required this.description,
    required this.reference,
    required this.rawRow,
  });

  final String lineDate;
  final double amount;
  final String description;
  final String reference;
  final Map<String, String> rawRow;
}

enum ReconTargetKind { maintenancePayment, financeEntry }

String reconKindId(ReconTargetKind k) => k == ReconTargetKind.maintenancePayment
    ? 'maintenance_payment'
    : 'finance_entry';

/// A maintenance payment or ledger entry that a statement line can be linked to.
sealed class ReconcilableTarget {
  const ReconcilableTarget({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.transactionId,
    required this.label,
    this.savedFallback = false,
  });

  final String id;

  /// Signed: expenses are negative.
  final double amount;
  final String date;
  final String paymentMethod;
  final String? transactionId;

  /// English label exactly as the web builds it.
  final String label;

  /// Hydrated from a saved suggestion whose record is outside the loaded period.
  final bool savedFallback;

  ReconTargetKind get kind;

  /// Label in the UI language.
  String displayLabel({bool hi = false});
}

class ReconcilablePayment extends ReconcilableTarget {
  const ReconcilablePayment({
    required super.id,
    required super.amount,
    required super.date,
    required super.paymentMethod,
    required super.transactionId,
    required this.flatNumber,
    required super.label,
    this.chargeTitle,
    super.savedFallback,
  });

  final String flatNumber;
  final String? chargeTitle;

  @override
  ReconTargetKind get kind => ReconTargetKind.maintenancePayment;

  @override
  String displayLabel({bool hi = false}) {
    if (!hi) return label;
    if (savedFallback)
      return label == 'Linked record' ? 'जुड़ा रिकॉर्ड' : label;
    return 'फ्लैट $flatNumber — ${chargeTitle ?? 'रखरखाव'} — ${jsInr(amount)}';
  }
}

class ReconcilableLedgerEntry extends ReconcilableTarget {
  const ReconcilableLedgerEntry({
    required super.id,
    required super.amount,
    required super.date,
    required super.paymentMethod,
    required super.transactionId,
    required this.title,
    required this.destination,
    required super.label,
    this.labelAmount = 0,
    super.savedFallback,
  });

  final String? title;
  final String destination;

  /// `Number(e.total_amount)` as shown in the label (unsigned original value).
  final double labelAmount;

  bool get isExpense => destination == 'separate_entry';

  @override
  ReconTargetKind get kind => ReconTargetKind.financeEntry;

  @override
  String displayLabel({bool hi = false}) {
    if (!hi) return label;
    if (savedFallback)
      return label == 'Linked record' ? 'जुड़ा रिकॉर्ड' : label;
    return '${isExpense ? 'खर्च' : 'रसीद'} — ${title ?? 'लेजर'} — ${jsInr(labelAmount)}';
  }
}

class StatementLineForMatch {
  const StatementLineForMatch({
    required this.id,
    required this.lineDate,
    required this.amount,
    this.description,
    this.reference,
  });

  final String id;
  final String lineDate;
  final double amount;
  final String? description;
  final String? reference;
}

class SuggestedMatch {
  const SuggestedMatch({
    required this.statementLineId,
    required this.matchType,
    this.maintenancePaymentId,
    this.financeEntryId,
    required this.matchConfidence,
    required this.target,
    required this.reasons,
  });

  final String statementLineId;

  /// `maintenance_payment` | `finance_entry`
  final String matchType;
  final String? maintenancePaymentId;
  final String? financeEntryId;
  final double matchConfidence;
  final ReconcilableTarget target;
  final List<String> reasons;
}

const List<String> _dateAliases = [
  'date',
  'transaction date',
  'txn date',
  'value date',
  'posting date',
  'tran date'
];
const List<String> _amountAliases = [
  'amount',
  'transaction amount',
  'txn amount'
];
const List<String> _debitAliases = [
  'debit',
  'withdrawal',
  'dr',
  'debit amount'
];
const List<String> _creditAliases = [
  'credit',
  'deposit',
  'cr',
  'credit amount'
];
const List<String> _descAliases = [
  'description',
  'narration',
  'particulars',
  'remarks',
  'details'
];
const List<String> _refAliases = [
  'reference',
  'ref',
  'utr',
  'upi ref',
  'cheque no',
  'transaction id',
  'txn id',
  'ref no'
];

String _normalizeHeader(String h) => h
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

int _findColumnIndex(List<String> headers, List<String> aliases) {
  final normalized = headers.map(_normalizeHeader).toList();
  for (final alias in aliases) {
    final idx = normalized.indexWhere((h) => h == alias || h.contains(alias));
    if (idx >= 0) return idx;
  }
  return -1;
}

/// JS `Number(s)` for already-trimmed numeric text (`null` when not finite).
double? _jsNumberOrNull(String s) {
  final n = double.tryParse(s);
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n;
}

double? parseStatementAmount(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[₹,\s]'), '')
      .replaceFirstMapped(RegExp(r'\((.*)\)'), (m) => '-${m.group(1)}');
  if (cleaned.isEmpty) return null;
  return _jsNumberOrNull(cleaned);
}

/// CSV line → cells (quoted cells, `""` escapes, trimmed).
List<String> parseCsvLine(String line) {
  final cells = <String>[];
  final current = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      cells.add(current.toString().trim());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  cells.add(current.toString().trim());
  return cells;
}

const List<String> _monthsShort = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec'
];
const List<String> _monthsLong = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

int? _monthFromName(String name) {
  final n = name.toLowerCase();
  final s = _monthsShort.indexOf(n);
  if (s >= 0) return s + 1;
  final l = _monthsLong.indexOf(n);
  if (l >= 0) return l + 1;
  if (n == 'sept') return 9;
  return null;
}

String? _ymd(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final dt = DateTime(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return ymdOfDate(dt);
}

/// date-fns `yy` handling: closest century to the current year.
int _twoDigitYear(int yy, [DateTime? now]) {
  final current = (now ?? DateTime.now()).year;
  final century = (current ~/ 100) * 100;
  var y = century + yy;
  if (y > current + 50) y -= 100;
  if (y <= current - 50) y += 100;
  return y;
}

/// `parseFlexibleDate`: yyyy-MM-dd, dd/MM/yyyy, dd-MM-yyyy, dd-MMM-yyyy, MMM dd, yyyy,
/// dd/MM/yy, then a best-effort `new Date(s)` fallback. Returns `yyyy-MM-dd`.
String? parseFlexibleDate(String raw, [DateTime? now]) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  RegExpMatch? m;

  m = RegExp(r'^(\d{1,4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m != null) {
    final r = _ymd(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    if (r != null) return r;
  }
  m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m != null) {
    final r = _ymd(
        int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    if (r != null) return r;
  }
  m = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$').firstMatch(s);
  if (m != null) {
    final r = _ymd(
        int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    if (r != null) return r;
  }
  m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(s);
  if (m != null) {
    final mo = _monthFromName(m.group(2)!);
    if (mo != null) {
      final r = _ymd(int.parse(m.group(3)!), mo, int.parse(m.group(1)!));
      if (r != null) return r;
    }
  }
  m = RegExp(r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$').firstMatch(s);
  if (m != null) {
    final mo = _monthFromName(m.group(1)!);
    if (mo != null) {
      final r = _ymd(int.parse(m.group(3)!), mo, int.parse(m.group(2)!));
      if (r != null) return r;
    }
  }
  m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2})$').firstMatch(s);
  if (m != null) {
    final r = _ymd(_twoDigitYear(int.parse(m.group(3)!), now),
        int.parse(m.group(2)!), int.parse(m.group(1)!));
    if (r != null) return r;
  }

  // Fallback (`new Date(s)` on the web): ISO timestamps and common bank formats.
  final iso = DateTime.tryParse(s);
  if (iso != null) return ymdOfDate(iso.isUtc ? iso.toLocal() : iso);
  m = RegExp(r'^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$').firstMatch(s);
  if (m != null)
    return _ymd(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  m = RegExp(r'^(\d{1,2})[.\-/ ](\d{1,2})[.\-/ ](\d{2}|\d{4})$').firstMatch(s);
  if (m != null) {
    final yRaw = m.group(3)!;
    final y = yRaw.length == 2
        ? _twoDigitYear(int.parse(yRaw), now)
        : int.parse(yRaw);
    return _ymd(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
  m = RegExp(r'^(\d{1,2})[\s\-/.]*([A-Za-z]{3,9})[\s\-/.,]*(\d{2}|\d{4})$')
      .firstMatch(s);
  if (m != null) {
    final mo = _monthFromName(m.group(2)!);
    final yRaw = m.group(3)!;
    if (mo != null) {
      final y = yRaw.length == 2
          ? _twoDigitYear(int.parse(yRaw), now)
          : int.parse(yRaw);
      return _ymd(y, mo, int.parse(m.group(1)!));
    }
  }
  m = RegExp(
          r'^([A-Za-z]{3,9})[\s\-/.]*(\d{1,2})(?:st|nd|rd|th)?[\s,]*(\d{4})$')
      .firstMatch(s);
  if (m != null) {
    final mo = _monthFromName(m.group(1)!);
    if (mo != null)
      return _ymd(int.parse(m.group(3)!), mo, int.parse(m.group(2)!));
  }
  return null;
}

/// Parse a bank CSV with flexible column headers.
List<BankStatementCsvRow> parseBankStatementCsv(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return const [];

  final headers = parseCsvLine(lines.first.replaceFirst('﻿', ''));
  final dateIdx = _findColumnIndex(headers, _dateAliases);
  final amountIdx = _findColumnIndex(headers, _amountAliases);
  final debitIdx = _findColumnIndex(headers, _debitAliases);
  final creditIdx = _findColumnIndex(headers, _creditAliases);
  final descIdx = _findColumnIndex(headers, _descAliases);
  final refIdx = _findColumnIndex(headers, _refAliases);

  if (dateIdx < 0) {
    throw const BankCsvException(
      'missing_date',
      'CSV must include a date column (date, value date, transaction date, etc.)',
    );
  }
  if (amountIdx < 0 && (debitIdx < 0 || creditIdx < 0)) {
    throw const BankCsvException(
        'missing_amount', 'CSV must include amount or debit/credit columns');
  }

  String cell(List<String> cells, int idx) =>
      idx >= 0 && idx < cells.length ? cells[idx] : '';

  final rows = <BankStatementCsvRow>[];
  for (var i = 1; i < lines.length; i++) {
    final cells = parseCsvLine(lines[i]);
    if (cells.every((c) => c.isEmpty)) continue;

    final lineDate = parseFlexibleDate(cell(cells, dateIdx));
    if (lineDate == null) continue;

    double? amount;
    if (amountIdx >= 0) {
      amount = parseStatementAmount(cell(cells, amountIdx));
    } else {
      final debit = parseStatementAmount(cell(cells, debitIdx)) ?? 0;
      final credit = parseStatementAmount(cell(cells, creditIdx)) ?? 0;
      if (debit == 0 && credit == 0) continue;
      amount = credit - debit;
    }
    if (amount == null || amount == 0) continue;

    final raw = <String, String>{};
    for (var idx = 0; idx < headers.length; idx++) {
      raw[headers[idx]] = cell(cells, idx);
    }

    rows.add(BankStatementCsvRow(
      lineDate: lineDate,
      amount: amount,
      description: descIdx >= 0 ? cell(cells, descIdx) : '',
      reference: refIdx >= 0 ? cell(cells, refIdx) : '',
      rawRow: raw,
    ));
  }
  return rows;
}

String bankReconCsvTemplate() =>
    'date,amount,description,reference\n2026-04-01,5000.00,UPI/FLAT A-101 maint,UTR123456789\n2026-04-02,-12000.00,NEFT Vendor ABC,NEFT987654321\n';

String _normalizeRef(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s'), '').toLowerCase();

bool _refsOverlap(String? a, String? b) {
  final na = _normalizeRef(a), nb = _normalizeRef(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.length >= 6 && nb.contains(na)) return true;
  if (nb.length >= 6 && na.contains(nb)) return true;
  return false;
}

bool _flatInText(String flatNumber, String text) {
  if (flatNumber.isEmpty || text.isEmpty) return false;
  final norm = text.replaceAll(RegExp(r'\s'), '').toLowerCase();
  final flat = flatNumber.replaceAll(RegExp(r'\s'), '').toLowerCase();
  return norm.contains(flat);
}

bool _signedAmountsMatch(double statementAmount, double targetAmount) =>
    (statementAmount.abs() - targetAmount.abs()).abs() < 0.01;

DateTime? _ymdUtc(String s) {
  final m = RegExp(r'^(\d{1,4})-(\d{1,2})-(\d{1,2})$').firstMatch(slice10(s));
  if (m == null) return null;
  final y = int.parse(m.group(1)!),
      mo = int.parse(m.group(2)!),
      d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

int _daysApart(String a, String b) {
  final da = _ymdUtc(a), db = _ymdUtc(b);
  if (da == null || db == null) return 999;
  return (da.difference(db).inHours / 24).round().abs();
}

/// Confidence 0…1 that [line] is [target]; 0 when amounts differ.
({double confidence, List<String> reasons}) computeMatchConfidence(
  StatementLineForMatch line,
  ReconcilableTarget target, [
  int dateToleranceDays = bankReconDateToleranceDays,
]) {
  final reasons = <String>[];
  if (!_signedAmountsMatch(line.amount, target.amount)) {
    return (confidence: 0.0, reasons: const ['Amount mismatch']);
  }
  reasons.add('Exact amount');
  var confidence = 0.5;

  final dayDiff = _daysApart(line.lineDate, target.date);
  if (dayDiff <= dateToleranceDays) {
    confidence += dayDiff == 0 ? 0.25 : 0.15;
    reasons.add(
        dayDiff == 0 ? 'Same date' : 'Date within ±$dateToleranceDays days');
  }

  final narration = '${line.description ?? ''} ${line.reference ?? ''}';
  if (_refsOverlap(line.reference, target.transactionId)) {
    confidence += 0.25;
    reasons.add('Reference / UTR match');
  }

  switch (target) {
    case ReconcilablePayment(:final flatNumber):
      if (_flatInText(flatNumber, narration)) {
        confidence += 0.1;
        reasons.add('Flat number in narration');
      }
    case ReconcilableLedgerEntry(:final title):
      if (title != null &&
          title.isNotEmpty &&
          narration
              .toLowerCase()
              .contains(jsSlice(title.toLowerCase(), 0, 8))) {
        confidence += 0.08;
        reasons.add('Title in narration');
      }
  }

  return (confidence: confidence > 1 ? 1.0 : confidence, reasons: reasons);
}

/// Translated match reason for the UI.
String reconReasonLabel(String reason, {bool hi = false}) {
  if (!hi) return reason;
  final within = RegExp(r'^Date within ±(\d+) days$').firstMatch(reason);
  if (within != null) return 'तिथि ±${within.group(1)} दिन के भीतर';
  return switch (reason) {
    'Amount mismatch' => 'राशि मेल नहीं खाती',
    'Exact amount' => 'सटीक राशि',
    'Same date' => 'समान तिथि',
    'Reference / UTR match' => 'संदर्भ / UTR मेल',
    'Flat number in narration' => 'विवरण में फ्लैट नंबर',
    'Title in narration' => 'विवरण में शीर्षक',
    'Saved suggestion' => 'सहेजा गया सुझाव',
    _ => reason,
  };
}

/// Payment rows for [buildReconcilableTargets].
class ReconPaymentInput {
  const ReconPaymentInput({
    required this.id,
    required this.flatNumber,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.dueDate,
    required this.paymentDate,
    required this.createdAt,
    this.transactionId,
    this.chargeTitle,
  });

  final String id;
  final String flatNumber;
  final double amount;
  final String paymentMethod;
  final String paymentStatus;
  final String? dueDate;
  final String? paymentDate;
  final String createdAt;
  final String? transactionId;
  final String? chargeTitle;

  factory ReconPaymentInput.fromJson(Map<String, dynamic> j,
          {String? chargeTitle}) =>
      ReconPaymentInput(
        id: (j['id'] ?? '').toString(),
        flatNumber: (j['flat_number'] ?? '').toString(),
        amount: jsNumber(j['amount']),
        paymentMethod: (j['payment_method'] ?? '').toString(),
        paymentStatus: (j['payment_status'] ?? '').toString(),
        dueDate: jsStrOrNull(j['due_date']),
        paymentDate: jsStrOrNull(j['payment_date']),
        createdAt: (j['created_at'] ?? '').toString(),
        transactionId: jsStrOrNull(j['transaction_id']),
        chargeTitle: chargeTitle,
      );
}

/// Ledger rows for [buildReconcilableTargets].
class ReconLedgerInput {
  const ReconLedgerInput({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionDate,
    this.entryMonth,
    required this.createdAt,
    this.transactionId,
    this.title,
    required this.destination,
  });

  final String id;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionDate;
  final String? entryMonth;
  final String createdAt;
  final String? transactionId;
  final String? title;
  final String destination;

  factory ReconLedgerInput.fromJson(Map<String, dynamic> j) => ReconLedgerInput(
        id: (j['id'] ?? '').toString(),
        totalAmount: jsNumber(j['total_amount']),
        paymentMethod: (j['payment_method'] ?? '').toString(),
        paymentStatus: (j['payment_status'] ?? '').toString(),
        transactionDate: jsStrOrNull(j['transaction_date']),
        entryMonth: jsStrOrNull(j['entry_month']),
        createdAt: (j['created_at'] ?? '').toString(),
        transactionId: jsStrOrNull(j['transaction_id']),
        title: jsStrOrNull(j['title']),
        destination: (j['destination'] ?? '').toString(),
      );
}

/// Verified bank-channel payments and ledger rows not yet confirmed to a statement line.
List<ReconcilableTarget> buildReconcilableTargets(
  List<ReconPaymentInput> payments,
  List<ReconLedgerInput> ledgerEntries,
  Set<String> alreadyMatchedPaymentIds,
  Set<String> alreadyMatchedEntryIds,
) {
  final targets = <ReconcilableTarget>[];
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    if (normalizePaymentChannel(p.paymentMethod) != PaymentChannel.bank)
      continue;
    if (alreadyMatchedPaymentIds.contains(p.id)) continue;
    final billing = paymentBillingDate(p.dueDate);
    targets.add(ReconcilablePayment(
      id: p.id,
      amount: p.amount,
      date: billing.isNotEmpty ? billing : slice10(p.createdAt),
      paymentMethod: p.paymentMethod,
      transactionId: p.transactionId,
      flatNumber: p.flatNumber,
      chargeTitle: p.chargeTitle,
      label:
          'Flat ${p.flatNumber} — ${p.chargeTitle ?? 'Maintenance'} — ${jsInr(p.amount)}',
    ));
  }
  for (final e in ledgerEntries) {
    if (e.paymentStatus != 'verified') continue;
    if (normalizePaymentChannel(e.paymentMethod) != PaymentChannel.bank)
      continue;
    if (alreadyMatchedEntryIds.contains(e.id)) continue;
    final isExpense = e.destination == 'separate_entry';
    targets.add(ReconcilableLedgerEntry(
      id: e.id,
      amount: isExpense ? -e.totalAmount.abs() : e.totalAmount,
      date: ledgerTransactionDate(
          transactionDate: e.transactionDate,
          entryMonth: e.entryMonth,
          createdAt: e.createdAt),
      paymentMethod: e.paymentMethod,
      transactionId: e.transactionId,
      title: e.title,
      destination: e.destination,
      labelAmount: e.totalAmount,
      label:
          '${isExpense ? 'Expense' : 'Receipt'} — ${e.title ?? 'Ledger'} — ${jsInr(e.totalAmount)}',
    ));
  }
  return targets;
}

String targetKey(ReconcilableTarget target) =>
    '${reconKindId(target.kind)}:${target.id}';

SuggestedMatch suggestionFromTarget(
  StatementLineForMatch line,
  ReconcilableTarget target, [
  int dateToleranceDays = bankReconDateToleranceDays,
]) {
  final r = computeMatchConfidence(line, target, dateToleranceDays);
  final isPayment = target.kind == ReconTargetKind.maintenancePayment;
  return SuggestedMatch(
    statementLineId: line.id,
    matchType: isPayment ? 'maintenance_payment' : 'finance_entry',
    maintenancePaymentId: isPayment ? target.id : null,
    financeEntryId: isPayment ? null : target.id,
    matchConfidence: r.confidence,
    target: target,
    reasons: r.reasons,
  );
}

/// Candidates for manual linking, sorted by confidence (amount mismatches excluded).
List<SuggestedMatch> rankCandidatesForLine(
  StatementLineForMatch line,
  List<ReconcilableTarget> targets, {
  Set<String> usedTargetKeys = const {},
  int limit = 10,
  int dateToleranceDays = bankReconDateToleranceDays,
}) {
  final ranked = stableSorted(
    targets
        .where((t) => !usedTargetKeys.contains(targetKey(t)))
        .map((t) => suggestionFromTarget(line, t, dateToleranceDays))
        .where((s) => s.matchConfidence > 0),
    (SuggestedMatch a, SuggestedMatch b) =>
        numDesc(a.matchConfidence, b.matchConfidence),
  );
  return ranked.take(limit).toList();
}

List<ReconcilableTarget> filterTargetsToPeriod(
  List<ReconcilableTarget> targets,
  String periodFrom,
  String periodTo, [
  int toleranceDays = bankReconDateToleranceDays,
]) {
  final from = _ymdUtc(periodFrom), to = _ymdUtc(periodTo);
  if (from == null || to == null) return targets;
  final minMs = from.millisecondsSinceEpoch - toleranceDays * 86400000;
  final maxMs = to.millisecondsSinceEpoch + toleranceDays * 86400000;
  return targets.where((t) {
    final d = _ymdUtc(t.date);
    if (d == null) return true;
    final ms = d.millisecondsSinceEpoch;
    return ms >= minMs && ms <= maxMs;
  }).toList();
}

/// One-to-one greedy pairing of lines to their best target.
List<SuggestedMatch> suggestMatches(
  List<StatementLineForMatch> lines,
  List<ReconcilableTarget> targets, [
  int dateToleranceDays = bankReconDateToleranceDays,
]) {
  final suggestions = <SuggestedMatch>[];
  final used = <String>{};
  for (final line in lines) {
    SuggestedMatch? best;
    for (final target in targets) {
      if (used.contains(targetKey(target))) continue;
      final r = computeMatchConfidence(line, target, dateToleranceDays);
      if (r.confidence <= 0) continue;
      if (best == null || r.confidence > best.matchConfidence) {
        final isPayment = target.kind == ReconTargetKind.maintenancePayment;
        best = SuggestedMatch(
          statementLineId: line.id,
          matchType: isPayment ? 'maintenance_payment' : 'finance_entry',
          maintenancePaymentId: isPayment ? target.id : null,
          financeEntryId: isPayment ? null : target.id,
          matchConfidence: r.confidence,
          target: target,
          reasons: r.reasons,
        );
      }
    }
    if (best != null) {
      suggestions.add(best);
      used.add(targetKey(best.target));
    }
  }
  return stableSorted(
      suggestions,
      (SuggestedMatch a, SuggestedMatch b) =>
          numDesc(a.matchConfidence, b.matchConfidence));
}

class ReconciliationSummary {
  const ReconciliationSummary({
    required this.statementCredits,
    required this.statementDebits,
    required this.matchedCredits,
    required this.matchedDebits,
    required this.unmatchedCredits,
    required this.unmatchedDebits,
    required this.lineCount,
    required this.matchedCount,
    required this.suggestedCount,
    required this.exceptionCount,
  });

  final double statementCredits;
  final double statementDebits;
  final double matchedCredits;
  final double matchedDebits;
  final double unmatchedCredits;
  final double unmatchedDebits;
  final int lineCount;
  final int matchedCount;
  final int suggestedCount;
  final int exceptionCount;
}

ReconciliationSummary computeReconciliationSummary(
  List<({String id, double amount})> lines,
  Map<String, String> statusByLineId,
) {
  var credits = 0.0, debits = 0.0, matchedCredits = 0.0, matchedDebits = 0.0;
  var matchedCount = 0, suggestedCount = 0;
  for (final line in lines) {
    final amt = line.amount;
    if (amt > 0) {
      credits += amt;
    } else {
      debits += amt.abs();
    }
    final status = statusByLineId[line.id];
    if (status == null) continue;
    if (status == 'confirmed' || status == 'manual') {
      matchedCount++;
      if (amt > 0) {
        matchedCredits += amt;
      } else {
        matchedDebits += amt.abs();
      }
    } else if (status == 'suggested') {
      suggestedCount++;
    }
  }
  return ReconciliationSummary(
    statementCredits: credits,
    statementDebits: debits,
    matchedCredits: matchedCredits,
    matchedDebits: matchedDebits,
    unmatchedCredits: credits - matchedCredits,
    unmatchedDebits: debits - matchedDebits,
    lineCount: lines.length,
    matchedCount: matchedCount,
    suggestedCount: suggestedCount,
    exceptionCount: lines.length - matchedCount,
  );
}

/// `lineStatus` from `BankReconciliation.tsx`: confirmed / rejected / suggested / unmatched.
String reconLineStatus(String lineId, Map<String, String> matchStatusByLineId,
    Set<String> suggestedLineIds) {
  final m = matchStatusByLineId[lineId];
  if (m == 'confirmed' || m == 'manual') return 'confirmed';
  if (m == 'rejected') return 'rejected';
  if (m == 'suggested' || suggestedLineIds.contains(lineId)) return 'suggested';
  return 'unmatched';
}

/// CSV text of non-confirmed lines (web `exportExceptions`).
String bankReconExceptionsCsv(
    List<
            ({
              String lineDate,
              double amount,
              String? description,
              String? reference,
              String status
            })>
        rows) {
  String esc(String s) => '"${s.replaceAll('"', '""')}"';
  final body = rows
      .map((l) => [
            l.lineDate,
            jsNumStr(l.amount),
            esc(l.description ?? ''),
            esc(l.reference ?? ''),
            l.status
          ].join(','))
      .join('\n');
  return 'date,amount,description,reference,status\n$body';
}
