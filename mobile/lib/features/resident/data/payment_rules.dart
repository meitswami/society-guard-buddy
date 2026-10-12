/// Maintenance payment logic of the resident Payments tab — ports of web
/// `src/lib/societyBankAccount.ts`, `maintenanceReceiptPdf.ts` (money / file name),
/// the receipt serial format (`maintenanceReceiptNumber.test.ts`), the charge
/// pre-selection in `ResidentDashboard.tsx`, and `statementAmountTotals.ts`.
library;

import 'dart:convert';

import 'package:intl/intl.dart';

import 'resident_models.dart';

// ---------------------------------------------------------------------------
// Receipts
// ---------------------------------------------------------------------------

/// Mirror of DB `format_maintenance_receipt_number`.
String formatMaintenanceReceiptNumber(int seq) => 'MR-${seq.toString().padLeft(6, '0')}';

/// `maintenance-receipt-<no>.pdf` (web `buildMaintenanceReceiptPdf` file name).
String maintenanceReceiptFileName(String receiptNumber) =>
    'maintenance-receipt-${receiptNumber.replaceAll(RegExp(r'[^\w.-]+'), '_')}.pdf';

final NumberFormat _inMoney = NumberFormat('#,##,##0.##', 'en_IN');

/// `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`.
String receiptMoney(num? n) => '₹${_inMoney.format(n ?? 0)}';

// ---------------------------------------------------------------------------
// Society bank account / UPI
// ---------------------------------------------------------------------------

/// JS `String(number)` for an amount (no trailing `.0`).
String jsNumberString(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}

/// WHATWG `application/x-www-form-urlencoded` (what `URLSearchParams.toString()` emits).
String formUrlEncode(String value) {
  final out = StringBuffer();
  for (final b in utf8.encode(value)) {
    final isAlnum = (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A);
    if (isAlnum || b == 0x2A || b == 0x2D || b == 0x2E || b == 0x5F) {
      out.writeCharCode(b);
    } else if (b == 0x20) {
      out.write('+');
    } else {
      out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// Web `buildUpiPayUrl`.
String buildUpiPayUrl({required String upiVpa, required String payeeName, num? amount, String? note}) {
  final params = <(String, String)>[
    ('pa', upiVpa.trim()),
    ('pn', payeeName.trim().isEmpty ? 'Society' : payeeName.trim()),
    ('cu', 'INR'),
    if (amount != null && amount > 0) ('am', jsNumberString(amount)),
    if ((note ?? '').trim().isNotEmpty) ('tn', note!.trim()),
  ];
  return 'upi://pay?${params.map((p) => '${p.$1}=${formUrlEncode(p.$2)}').join('&')}';
}

/// Web `copyableBankDetails`.
String copyableBankDetails(SocietyBankAccountRow a) {
  final lines = [
    'Account name: ${a.accountHolderName}',
    'Bank: ${a.bankName}',
    'Account number: ${a.accountNumber}',
    'IFSC: ${a.ifsc}',
  ];
  if ((a.branchName ?? '').isNotEmpty) lines.add('Branch: ${a.branchName}');
  if ((a.upiVpa ?? '').isNotEmpty) lines.add('UPI: ${a.upiVpa}');
  return lines.join('\n');
}

/// Web `maskAccountNumber`.
String maskAccountNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp(r'\s+'), '');
  if (digits.length <= 4) return digits;
  return '${'•' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
}

/// `Maintenance for Flat 101` (UPI note on web).
String maintenanceUpiNote(String flatNumber) => 'Maintenance for Flat $flatNumber';

// ---------------------------------------------------------------------------
// Charge pre-selection / payment form
// ---------------------------------------------------------------------------

const _monthNames = [
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

String _lc(String v) => v.trim().toLowerCase();

/// Web: monthly charge whose title has "maint" + current month name → any monthly
/// "maint" charge → first charge.
MaintenanceChargeRow? pickPreferredCharge(List<MaintenanceChargeRow> charges, DateTime now) {
  if (charges.isEmpty) return null;
  final month = _monthNames[now.month - 1];
  bool monthlyMaint(MaintenanceChargeRow c) => _lc(c.frequency) == 'monthly' && c.title.toLowerCase().contains('maint');
  for (final c in charges) {
    if (monthlyMaint(c) && c.title.toLowerCase().contains(month)) return c;
  }
  for (final c in charges) {
    if (monthlyMaint(c)) return c;
  }
  return charges.first;
}

/// Due date in the current month for a charge `due_day` (clamped to 1…28 like web).
String dueDateForDay(int dueDay, DateTime now) {
  final day = dueDay < 1 ? 1 : (dueDay > 28 ? 28 : dueDay);
  return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, day));
}

enum ResidentPaymentError { chargeRequired, amountInvalid, datesRequired, fileTooLarge }

/// Web `handleSubmitResidentPayment` checks (8 MB receipt limit included).
ResidentPaymentError? validateResidentPayment({
  required String chargeId,
  required String amountText,
  required String paidOn,
  required String dueDate,
  int? fileBytes,
}) {
  if (chargeId.isEmpty) return ResidentPaymentError.chargeRequired;
  final amount = double.tryParse(amountText.trim()) ?? 0;
  if (amountText.trim().isEmpty || amount <= 0) return ResidentPaymentError.amountInvalid;
  if (paidOn.isEmpty || dueDate.isEmpty) return ResidentPaymentError.datesRequired;
  if (fileBytes != null && fileBytes > 8 * 1024 * 1024) return ResidentPaymentError.fileTooLarge;
  return null;
}

/// `new Date('${paidOn}T12:00:00').toISOString()` — local noon as UTC ISO.
String paidAtIso(String paidOnYmd) => DateTime.parse('${paidOnYmd}T12:00:00').toUtc().toIso8601String();

// ---------------------------------------------------------------------------
// Dues (current period status per charge)
// ---------------------------------------------------------------------------

enum DueState { paid, pending, rejected, due }

/// Billing period key: monthly → `2026-10`, quarterly → `2026-Q4`, yearly → `FY2026`
/// (April–March), one-time / other → `once`.
String chargePeriodKey(String frequency, DateTime d) {
  switch (_lc(frequency)) {
    case 'monthly':
      return DateFormat('yyyy-MM').format(d);
    case 'quarterly':
      return '${d.year}-Q${((d.month - 1) ~/ 3) + 1}';
    case 'yearly':
      return 'FY${d.month >= 4 ? d.year : d.year - 1}';
    default:
      return 'once';
  }
}

String? _periodKeyForYmd(String frequency, String ymd) {
  if (ymd.length < 10) return null;
  final d = DateTime.tryParse(ymd.substring(0, 10));
  if (d == null) return null;
  return chargePeriodKey(frequency, d);
}

/// Human period label (`10/2026`, `Q4 2026`, `FY 2026-27`, `One-time`).
String chargePeriodLabel(String frequency, DateTime d) {
  switch (_lc(frequency)) {
    case 'monthly':
      return DateFormat('MM/yyyy').format(d);
    case 'quarterly':
      return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
    case 'yearly':
      final start = d.month >= 4 ? d.year : d.year - 1;
      return 'FY $start-${((start + 1) % 100).toString().padLeft(2, '0')}';
    default:
      return 'One-time';
  }
}

class ChargeDue {
  const ChargeDue({required this.charge, required this.state, required this.periodLabel, required this.dueDate, this.payment});

  final MaintenanceChargeRow charge;
  final DueState state;
  final String periodLabel;
  /// Suggested due date for a new payment (`yyyy-MM-dd`).
  final String dueDate;
  /// Payment that decided the state (verified / pending / rejected), if any.
  final MaintenancePaymentRow? payment;

  bool get payable => state == DueState.due || state == DueState.rejected;
}

/// Status of each active charge for the current billing period, from the flat's payments
/// (billing date = `due_date`, like web finance).
List<ChargeDue> computeChargeDues(List<MaintenanceChargeRow> charges, List<MaintenancePaymentRow> payments, DateTime now) {
  final out = <ChargeDue>[];
  for (final c in charges) {
    if (!c.isActive) continue;
    final key = chargePeriodKey(c.frequency, now);
    final inPeriod = payments.where((p) => p.chargeId == c.id && _periodKeyForYmd(c.frequency, p.dueDate) == key).toList();
    MaintenancePaymentRow? pick(String status) {
      for (final p in inPeriod) {
        if (p.paymentStatus == status) return p;
      }
      return null;
    }

    final verified = pick('verified');
    final pending = verified == null ? pick('pending') : null;
    final rejected = verified == null && pending == null ? pick('rejected') : null;
    final state = verified != null
        ? DueState.paid
        : pending != null
            ? DueState.pending
            : rejected != null
                ? DueState.rejected
                : DueState.due;
    out.add(ChargeDue(
      charge: c,
      state: state,
      periodLabel: chargePeriodLabel(c.frequency, now),
      dueDate: dueDateForDay(c.dueDay, now),
      payment: verified ?? pending ?? rejected,
    ));
  }
  return out;
}

/// Sum of amounts still due this period (due + rejected rows).
double totalOutstanding(List<ChargeDue> dues) =>
    dues.where((d) => d.payable).fold<double>(0, (s, d) => s + d.charge.amount);

// ---------------------------------------------------------------------------
// Statements (web `statementAmountTotals.ts` + report-detail PDF helpers)
// ---------------------------------------------------------------------------

class AmountRow {
  const AmountRow({this.amount, this.dateIso, this.date});

  final double? amount;
  /// Preferred for grouping — `yyyy-MM-dd` or ISO timestamp.
  final String? dateIso;
  /// Display date (`dd/MM/yyyy`) when ISO is unavailable.
  final String? date;
}

class MonthlyAmountTotal {
  const MonthlyAmountTotal({required this.monthKey, required this.label, required this.total, required this.count});

  final String monthKey;
  final String label;
  final double total;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is MonthlyAmountTotal &&
      other.monthKey == monthKey &&
      other.label == label &&
      other.total == total &&
      other.count == count;

  @override
  int get hashCode => Object.hash(monthKey, label, total, count);

  @override
  String toString() => 'MonthlyAmountTotal($monthKey, $label, $total, $count)';
}

double sumAmountRows(Iterable<AmountRow> rows) => rows.fold<double>(0, (s, r) => s + (r.amount ?? 0));

/// `yyyy-MM` → `MM/yyyy` (web `fmtIsoMonthToDisplay`).
String fmtIsoMonthToDisplay(String ym) {
  if (ym.length < 7) return ym;
  final s = ym.substring(0, 7);
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return ym;
  return '${m.group(2)}/${m.group(1)}';
}

String? _monthKeyFromRow(AmountRow row) {
  final iso = row.dateIso;
  if (iso != null && iso.length >= 10) {
    final s = iso.substring(0, 10);
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s.substring(0, 7);
  }
  final date = row.date?.trim();
  if (date != null && date.isNotEmpty) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(date)) return date.substring(0, 7);
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(date);
    if (m != null) {
      final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
      final dt = DateTime(y, mo, d);
      if (dt.year == y && dt.month == mo && dt.day == d) return '$y-${mo.toString().padLeft(2, '0')}';
    }
  }
  return null;
}

/// Group transaction amounts by calendar month (`yyyy-MM`), ascending.
List<MonthlyAmountTotal> monthlyAmountTotals(Iterable<AmountRow> rows) {
  final map = <String, (double, int)>{};
  for (final row in rows) {
    final amount = row.amount;
    if (amount == null) continue;
    final key = _monthKeyFromRow(row);
    if (key == null) continue;
    final cur = map[key] ?? (0.0, 0);
    map[key] = (cur.$1 + amount, cur.$2 + 1);
  }
  final keys = map.keys.toList()..sort();
  return [
    for (final k in keys) MonthlyAmountTotal(monthKey: k, label: fmtIsoMonthToDisplay(k), total: map[k]!.$1, count: map[k]!.$2),
  ];
}

/// Web `reportDetailPdfFilename`.
String reportDetailPdfFilename(String title, DateTime now) {
  var slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 48) slug = slug.substring(0, 48);
  final day = now.toUtc().toIso8601String().substring(0, 10);
  return '${slug.isEmpty ? 'report-detail' : slug}-$day.pdf';
}

enum StatementPeriod { all, thisMonth, last3Months, thisFinancialYear, lastFinancialYear }

/// Inclusive `yyyy-MM-dd` range for a statement period (null = all time).
({String from, String to})? statementRange(StatementPeriod period, DateTime now) {
  final f = DateFormat('yyyy-MM-dd');
  final fyStart = now.month >= 4 ? now.year : now.year - 1;
  switch (period) {
    case StatementPeriod.all:
      return null;
    case StatementPeriod.thisMonth:
      return (from: f.format(DateTime(now.year, now.month, 1)), to: f.format(DateTime(now.year, now.month + 1, 0)));
    case StatementPeriod.last3Months:
      return (from: f.format(DateTime(now.year, now.month - 2, 1)), to: f.format(DateTime(now.year, now.month + 1, 0)));
    case StatementPeriod.thisFinancialYear:
      return (from: f.format(DateTime(fyStart, 4, 1)), to: f.format(DateTime(fyStart + 1, 3, 31)));
    case StatementPeriod.lastFinancialYear:
      return (from: f.format(DateTime(fyStart - 1, 4, 1)), to: f.format(DateTime(fyStart, 3, 31)));
  }
}

/// Payments whose billing date (`due_date`) falls in the range.
List<MaintenancePaymentRow> paymentsInRange(List<MaintenancePaymentRow> payments, ({String from, String to})? range) {
  if (range == null) return List.of(payments);
  return payments.where((p) {
    if (p.dueDate.length < 10) return false;
    final d = p.dueDate.substring(0, 10);
    return d.compareTo(range.from) >= 0 && d.compareTo(range.to) <= 0;
  }).toList();
}
