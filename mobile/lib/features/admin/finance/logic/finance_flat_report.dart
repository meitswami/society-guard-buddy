// Port of `src/lib/financeFlatReport.ts` (Reports → Flat-wise financial report).

import 'finance_dates.dart';
import 'finance_ledger_display.dart';
import 'finance_models.dart';
import 'flat_sort.dart';

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

List<FlatReportRow> buildFlatReportRows({
  required String from,
  required String to,
  required String selectedFlat,
  required List<FinancePayment> payments,
  required List<FinanceLedgerRow> ledgerEntries,
  required List<FlatReportExpense> flatReportExpenses,
  required List<FlatReportSplit> flatReportSplits,
  required List<SocietyFlatRow> flats,
  required Map<String, String> primaryByFlatId,
  required List<FinanceCharge> charges,
}) {
  bool isInRange(String iso) => dateInInclusiveRange(iso, from, to);

  final flatMap = <String, FlatReportRow>{};
  FlatReportRow getRow(String flatNum) {
    return flatMap.putIfAbsent(flatNum, () {
      SocietyFlatRow? flat;
      for (final f in flats) {
        if (f.flatNumber == flatNum) {
          flat = f;
          break;
        }
      }
      String resName = flatNum;
      if (flat != null && flat.id.isNotEmpty) {
        final primary = primaryByFlatId[flat.id];
        if (primary != null && primary.isNotEmpty) {
          resName = primary;
        } else if (flat.ownerName != null && flat.ownerName!.isNotEmpty) {
          resName = flat.ownerName!;
        }
      }
      return FlatReportRow(flatNumber: flatNum, residentName: resName);
    });
  }

  final countedFinanceEntryIds = <String>{};
  for (final p in payments) {
    if (p.paymentStatus != 'verified') continue;
    final d = paymentBillingDate(p.dueDate);
    if (d.isEmpty || !isInRange(d)) continue;
    final flatNum = p.flatNumber;
    if (flatNum.isEmpty) continue;
    final amt = p.amount;
    final row = getRow(flatNum);
    row.maintenancePaid += amt;
    row.maintenanceCount += 1;
    String chargeTitle = 'Maintenance';
    for (final c in charges) {
      if (c.id == p.chargeId) {
        chargeTitle = c.title;
        break;
      }
    }
    row.details.add(FlatReportDetailRow(
      type: 'maintenance',
      title: chargeTitle,
      amount: amt,
      date: d.length > 10 ? d.substring(0, 10) : d,
      method: p.paymentMethod.isEmpty ? 'cash' : p.paymentMethod,
      status: 'paid',
    ));
    final feId = p.financeEntryId;
    if (feId != null && feId.isNotEmpty) countedFinanceEntryIds.add(feId);
  }

  for (final e in ledgerEntries) {
    if (e.destination == 'separate_entry') continue;
    final ledgerDate = ledgerTransactionDate(e);
    if (ledgerDate.isEmpty || !isInRange(ledgerDate)) continue;
    if (e.recordMode == 'flats_only' && countedFinanceEntryIds.contains(e.id)) {
      continue;
    }
    for (final alloc in e.allocations) {
      final flatNum = alloc.flatNumber;
      if (flatNum.isEmpty || flatNum == 'SOCIETY') continue;
      final row = getRow(flatNum);
      row.maintenancePaid += alloc.amount;
      row.maintenanceCount += 1;
      row.details.add(FlatReportDetailRow(
        type: 'maintenance',
        title: (e.title ?? '').isEmpty ? 'Ledger receipt' : e.title!,
        amount: alloc.amount,
        date: ledgerDate.length > 10 ? ledgerDate.substring(0, 10) : ledgerDate,
        method: e.paymentMethod.isEmpty ? 'other' : e.paymentMethod,
        status: 'verified',
      ));
    }
  }

  final expenseById = {for (final e in flatReportExpenses) e.id: e};
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
    row.details.sort((a, b) => b.date.compareTo(a.date));
  }

  var rows =
      sortFlatsByNumber<FlatReportRow>(flatMap.values, (r) => r.flatNumber);
  if (selectedFlat != 'all') {
    rows = rows.where((r) => r.flatNumber == selectedFlat).toList();
  }
  return rows;
}
