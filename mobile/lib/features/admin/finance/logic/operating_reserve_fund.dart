// Port of `src/lib/operatingReserveFund.ts` (Totals → Monthly operating fund & reserve).

import 'finance_models.dart';

const String kOperatingToReserve = 'operating_to_reserve';
const String kReserveToOperating = 'reserve_to_operating';
const String kReserveToFixed = 'reserve_to_fixed';
const String kReserveToEmergency = 'reserve_to_emergency';

/// English labels (also used as success toasts on web).
const Map<String, String> kReserveTransferLabels = {
  kOperatingToReserve: 'Surplus → Reserve fund',
  kReserveToOperating: 'Reserve → Monthly operating (shortfall)',
  kReserveToFixed: 'Reserve → Fixed asset / investment',
  kReserveToEmergency: 'Reserve → Emergency / contingency',
};

const Map<String, String> kReserveTransferLabelsHi = {
  kOperatingToReserve: 'अधिशेष → आरक्षित निधि',
  kReserveToOperating: 'आरक्षित → मासिक संचालन (कमी)',
  kReserveToFixed: 'आरक्षित → स्थायी संपत्ति / निवेश',
  kReserveToEmergency: 'आरक्षित → आपात / आकस्मिक',
};

/// Month of a ledger row for the operating fund (`entry_month` first, then `transaction_date`).
String operatingLedgerMonthValue(FinanceLedgerRow e) {
  final em = e.entryMonth?.trim() ?? '';
  if (em.isNotEmpty) return em.length > 7 ? em.substring(0, 7) : em;
  final td = e.transactionDate ?? '';
  if (td.isNotEmpty) return td.length > 7 ? td.substring(0, 7) : td;
  return '';
}

// Mirrors the web table exactly — note it has no 'may' abbreviation, so index i + 12
// is shifted for months after April (web behaviour kept for identical totals).
const List<String?> _monthTokens = [
  'january', 'february', 'march', 'april', 'may', 'june', //
  'july', 'august', 'september', 'october', 'november', 'december', //
  'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', //
  null,
];

String? extractMonthFromChargeTitle(String title, [DateTime? now]) {
  final m = RegExp(r'(\d{4})-(\d{2})').firstMatch(title);
  if (m != null) return '${m.group(1)}-${m.group(2)}';
  final lower = title.toLowerCase();
  for (var i = 0; i < 12; i++) {
    final full = _monthTokens[i]!;
    final abbr = _monthTokens[i + 12];
    // JS `includes(undefined)` checks for the text "undefined".
    if (lower.contains(full) || lower.contains(abbr ?? 'undefined')) {
      final yearMatch = RegExp(r'20\d{2}').firstMatch(title);
      final year = yearMatch != null ? yearMatch.group(0)! : '${(now ?? DateTime.now()).year}';
      return '$year-${(i + 1).toString().padLeft(2, '0')}';
    }
  }
  return null;
}

/// Monthly maintenance collections — excludes one-time / head-linked receipt types.
double monthlyOperatingInflow(
  String month,
  List<FinancePayment> payments,
  List<FinanceCharge> charges,
  Map<String, String> chargeTitleById,
) {
  final monthlyChargeIds = {
    for (final c in charges)
      if (c.frequency == 'monthly' && (c.expenseGroupId == null || c.expenseGroupId!.isEmpty)) c.id,
  };
  var sum = 0.0;
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final cid = p.chargeId;
    if (cid == null || cid.isEmpty || !monthlyChargeIds.contains(cid)) continue;
    final due = p.dueDate ?? '';
    final dueMonth = due.length > 7 ? due.substring(0, 7) : due;
    final titleMonth = extractMonthFromChargeTitle(chargeTitleById[cid] ?? '');
    final pm = (titleMonth == null || titleMonth.isEmpty) ? dueMonth : titleMonth;
    if (pm == month) sum += p.amount;
  }
  return sum;
}

/// Operational outflows for the month (society payment ledger, separate_entry).
double monthlyOperatingOutflow(String month, List<FinanceLedgerRow> ledgerEntries, bool Function(FinanceLedgerRow) isOutflowEntry) {
  var sum = 0.0;
  for (final e in ledgerEntries) {
    if (!isOutflowEntry(e)) continue;
    if (operatingLedgerMonthValue(e) != month) continue;
    sum += e.totalAmount;
  }
  return sum;
}

final RegExp _reserveFundTitle = RegExp(r'^reserve fund\s*[—–-]', caseSensitive: false);

double reserveFundBalance(List<FinanceLedgerRow> ledgerEntries, List<ReserveTransfer> transfers) {
  var balance = 0.0;
  for (final e in ledgerEntries) {
    if (e.destination != 'corpus') continue;
    if (_reserveFundTitle.hasMatch(e.title ?? '')) continue;
    balance += e.totalAmount;
  }
  for (final t in transfers) {
    if (t.direction == kOperatingToReserve) {
      balance += t.amount;
    } else {
      balance -= t.amount;
    }
  }
  return balance;
}

List<ReserveTransfer> transfersForMonth(List<ReserveTransfer> transfers, String month) =>
    transfers.where((t) => t.entryMonth == month).toList();

double netTransferEffectForMonth(List<ReserveTransfer> transfers, String month) {
  var net = 0.0;
  for (final t in transfersForMonth(transfers, month)) {
    if (t.direction == kOperatingToReserve) {
      net -= t.amount;
    } else {
      net += t.amount;
    }
  }
  return net;
}
