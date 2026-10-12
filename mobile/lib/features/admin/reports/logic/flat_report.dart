import '../data/report_models.dart';
import 'finance_period_report.dart';
import 'flat_sort.dart';
import 'js_compat.dart';

/// Port of `src/lib/financeFlatReport.ts` (Reports → Financial → Flat wise).

class FlatReportDetailRow {
  const FlatReportDetailRow({
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    this.groupName,
  });

  /// `maintenance` | `expense`
  final String type;
  final String title;
  final double amount;
  final String date;
  final String method;
  final String status;
  final String? groupName;
}

class FlatReportRow {
  FlatReportRow({required this.flatNumber, required this.residentName});

  final String flatNumber;
  final String residentName;
  double maintenancePaid = 0;
  int maintenanceCount = 0;
  double expenseShare = 0;
  int expenseCount = 0;
  double settledAmount = 0;
  double unsettledAmount = 0;
  double netPosition = 0;
  final List<FlatReportDetailRow> details = [];
}

/// `expenses` row joined with its group name (`fetchFinanceFlatReport`).
class FlatReportExpense {
  const FlatReportExpense({
    required this.id,
    required this.title,
    required this.expenseDate,
    required this.paymentMethod,
    this.groupName,
    this.totalAmount = 0,
  });

  final String id;
  final String title;
  final String expenseDate;
  final String paymentMethod;
  final String? groupName;
  final double totalAmount;

  factory FlatReportExpense.fromJson(Map<String, dynamic> j,
          {String? groupName}) =>
      FlatReportExpense(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        expenseDate: (j['expense_date'] ?? '').toString(),
        paymentMethod: (j['payment_method'] ?? '').toString(),
        groupName: groupName ?? j['group_name']?.toString(),
        totalAmount: jsAmount(j['total_amount']),
      );
}

/// `expense_splits` row.
class FlatReportSplit {
  const FlatReportSplit(
      {required this.expenseId,
      required this.flatNumber,
      this.amount = 0,
      this.isSettled = false});

  final String expenseId;
  final String flatNumber;
  final double amount;
  final bool isSettled;

  factory FlatReportSplit.fromJson(Map<String, dynamic> j) => FlatReportSplit(
        expenseId: (j['expense_id'] ?? '').toString(),
        flatNumber: (j['flat_number'] ?? '').toString(),
        amount: jsAmount(j['amount']),
        isSettled: j['is_settled'] == true,
      );
}

List<FlatReportRow> buildFlatReportRows({
  required String from,
  required String to,
  required String selectedFlat,
  required List<FinancePeriodPayment> payments,
  required List<FinancePeriodLedgerEntry> ledgerEntries,
  required List<FlatReportExpense> flatReportExpenses,
  required List<FlatReportSplit> flatReportSplits,
  required List<ReportFlat> flats,
  required Map<String, String> primaryByFlatId,
  required List<ReportCharge> charges,
}) {
  final fromMs = localDayStartMs(from);
  final toMs = localDayEndMs(to);
  bool isInRange(String iso) {
    final t = jsDateMs(iso);
    if (t == null || fromMs == null || toMs == null) return false;
    return t >= fromMs && t <= toMs;
  }

  final flatMap = <String, FlatReportRow>{};
  FlatReportRow getRow(String flatNum) {
    return flatMap.putIfAbsent(flatNum, () {
      ReportFlat? flat;
      for (final f in flats) {
        if (f.flatNumber == flatNum) {
          flat = f;
          break;
        }
      }
      String resName;
      if (flat != null && flat.id.isNotEmpty) {
        final primary = primaryByFlatId[flat.id];
        resName = (primary != null && primary.isNotEmpty)
            ? primary
            : ((flat.ownerName != null && flat.ownerName!.isNotEmpty)
                ? flat.ownerName!
                : flatNum);
      } else {
        resName = flatNum;
      }
      return FlatReportRow(flatNumber: flatNum, residentName: resName);
    });
  }

  final chargeTitleById = {for (final c in charges) c.id: c.title};

  final countedFinanceEntryIds = <String>{};
  for (final p in payments) {
    if (!p.isVerified) continue;
    final d = p.billingDate;
    if (d.isEmpty || !isInRange(d)) continue;
    final flatNum = p.flatNumber ?? '';
    if (flatNum.isEmpty) continue;
    final amt = p.amount;
    final row = getRow(flatNum);
    row.maintenancePaid += amt;
    row.maintenanceCount += 1;
    row.details.add(FlatReportDetailRow(
      type: 'maintenance',
      title: chargeTitleById[p.chargeId] ?? 'Maintenance',
      amount: amt,
      date: d.length > 10 ? d.substring(0, 10) : d,
      method: (p.paymentMethod == null || p.paymentMethod!.isEmpty)
          ? 'cash'
          : p.paymentMethod!,
      status: 'paid',
    ));
    final feId = p.financeEntryId;
    if (feId != null && feId.isNotEmpty) countedFinanceEntryIds.add(feId);
  }

  for (final e in ledgerEntries) {
    if (e.destination == 'separate_entry') continue;
    final ledgerDate = e.ledgerDate;
    if (ledgerDate.isEmpty || !isInRange(ledgerDate)) continue;
    if (e.recordMode == 'flats_only' && countedFinanceEntryIds.contains(e.id))
      continue;
    for (final alloc in e.allocations) {
      final flatNum = alloc.flatNumber;
      if (flatNum.isEmpty || flatNum == 'SOCIETY') continue;
      final amt = alloc.amount;
      final row = getRow(flatNum);
      row.maintenancePaid += amt;
      row.maintenanceCount += 1;
      row.details.add(FlatReportDetailRow(
        type: 'maintenance',
        title:
            (e.title == null || e.title!.isEmpty) ? 'Ledger receipt' : e.title!,
        amount: amt,
        date: ledgerDate.length > 10 ? ledgerDate.substring(0, 10) : ledgerDate,
        method: (e.paymentMethod == null || e.paymentMethod!.isEmpty)
            ? 'other'
            : e.paymentMethod!,
        status: 'verified',
      ));
    }
  }

  final expenseById = <String, FlatReportExpense>{};
  for (final e in flatReportExpenses) {
    expenseById.putIfAbsent(e.id, () => e);
  }
  for (final split in flatReportSplits) {
    final exp = expenseById[split.expenseId];
    if (exp == null) continue;
    final expDate = exp.expenseDate;
    if (!isInRange(expDate)) continue;
    final flatNum = split.flatNumber;
    if (flatNum.isEmpty || flatNum == 'SOCIETY') continue;
    final amt = split.amount;
    final row = getRow(flatNum);
    row.expenseShare += amt;
    row.expenseCount += 1;
    if (split.isSettled) {
      row.settledAmount += amt;
    } else {
      row.unsettledAmount += amt;
    }
    row.details.add(FlatReportDetailRow(
      type: 'expense',
      title: exp.title.isEmpty ? 'Expense' : exp.title,
      amount: amt,
      date: expDate.length > 10 ? expDate.substring(0, 10) : expDate,
      method: exp.paymentMethod.isEmpty ? 'cash' : exp.paymentMethod,
      status: split.isSettled ? 'settled' : 'pending',
      groupName: exp.groupName,
    ));
  }

  for (final row in flatMap.values) {
    row.netPosition = row.maintenancePaid - row.expenseShare;
    row.details.sort((a, b) => jsLocaleCompare(b.date, a.date));
  }

  var rows = flatMap.values.toList()
    ..sort((a, b) => compareFlatNumbers(a.flatNumber, b.flatNumber));
  if (selectedFlat != 'all') {
    rows = rows.where((r) => r.flatNumber == selectedFlat).toList();
  }
  return rows;
}
