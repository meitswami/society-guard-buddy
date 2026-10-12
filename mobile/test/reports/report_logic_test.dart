// Ports of financeFlatReport.test.ts, statementAmountTotals.test.ts,
// financeLedgerDisplay.test.ts plus coverage for the report aggregations,
// query filters, cash-flow statement, monthly export sheets and the
// metadata reporting engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/reports/data/report_models.dart';
import 'package:kutumbika_mobile/features/admin/reports/engine/report_export_service.dart';
import 'package:kutumbika_mobile/features/admin/reports/engine/report_metadata.dart';
import 'package:kutumbika_mobile/features/admin/reports/engine/report_service.dart';
import 'package:kutumbika_mobile/features/admin/reports/engine/report_types.dart';
import 'package:kutumbika_mobile/features/admin/reports/export/monthly_report_export.dart';
import 'package:kutumbika_mobile/features/admin/reports/export/report_detail_pdf.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/cash_flow_statement.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_period_report.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/flat_report.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/flat_sort.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/js_compat.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/report_aggregations.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/report_detail_row.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/report_formatters.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/report_query_filter.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/statement_amount_totals.dart';

ReportVisitor visitor(String id, {String name = 'Ravi', String cat = 'visitor', String? vehicle, String? exit, String flat = '101'}) =>
    ReportVisitor(
      id: id,
      name: name,
      phone: '9876543210',
      flatNumber: flat,
      purpose: 'Guest',
      entryTime: '2026-04-05T10:00:00Z',
      exitTime: exit,
      guardId: 'G1',
      guardName: 'Ramesh',
      category: cat,
      vehicleNumber: vehicle,
    );

class MemorySource implements ReportRowSource {
  MemorySource(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, Object?>>> fetchRows({
    required ReportDefinition definition,
    required String societyId,
    required ReportFilterValues filters,
    ReportSortDef? sort,
    required List<String> columnKeys,
  }) async =>
      const DynamicQueryBuilder().projectRows(definition, rows, columnKeys);
}

void main() {
  group('buildFlatReportRows', () {
    const flats = [ReportFlat(id: 'f1', flatNumber: 'A-101', ownerName: 'Owner', isOccupied: true)];

    test('aggregates verified maintenance payments in range', () {
      final rows = buildFlatReportRows(
        from: '2026-03-01',
        to: '2026-03-31',
        selectedFlat: 'all',
        payments: const [
          FinancePeriodPayment(
            paymentStatus: 'verified',
            flatNumber: 'A-101',
            amount: 1000,
            chargeId: 'c1',
            paymentMethod: 'cash',
            dueDate: '2026-03-10',
          ),
        ],
        ledgerEntries: const [],
        flatReportExpenses: const [],
        flatReportSplits: const [],
        flats: flats,
        primaryByFlatId: const {'f1': 'Ravi'},
        charges: const [ReportCharge(id: 'c1', title: 'March Maintenance')],
      );
      expect(rows, hasLength(1));
      expect(rows[0].maintenancePaid, 1000);
      expect(rows[0].residentName, 'Ravi');
      expect(rows[0].netPosition, 1000);
      expect(rows[0].details.single.title, 'March Maintenance');
    });

    test('filters by selected flat', () {
      final rows = buildFlatReportRows(
        from: '2026-03-01',
        to: '2026-03-31',
        selectedFlat: 'B-202',
        payments: const [FinancePeriodPayment(paymentStatus: 'verified', flatNumber: 'A-101', amount: 1000, dueDate: '2026-03-10')],
        ledgerEntries: const [],
        flatReportExpenses: const [],
        flatReportSplits: const [],
        flats: const [ReportFlat(id: 'f1', flatNumber: 'A-101'), ReportFlat(id: 'f2', flatNumber: 'B-202')],
        primaryByFlatId: const {},
        charges: const [],
      );
      expect(rows, isEmpty);
    });

    test('subtracts expense splits from net position', () {
      final rows = buildFlatReportRows(
        from: '2026-03-01',
        to: '2026-03-31',
        selectedFlat: 'all',
        payments: const [FinancePeriodPayment(paymentStatus: 'verified', flatNumber: 'A-101', amount: 2000, dueDate: '2026-03-10')],
        ledgerEntries: const [],
        flatReportExpenses: const [
          FlatReportExpense(id: 'e1', title: 'Lift repair', expenseDate: '2026-03-15', paymentMethod: 'cash', groupName: 'Repairs'),
        ],
        flatReportSplits: const [FlatReportSplit(expenseId: 'e1', flatNumber: 'A-101', amount: 500, isSettled: true)],
        flats: flats,
        primaryByFlatId: const {},
        charges: const [],
      );
      expect(rows[0].expenseShare, 500);
      expect(rows[0].settledAmount, 500);
      expect(rows[0].netPosition, 1500);
      expect(rows[0].residentName, 'Owner');
    });

    test('ledger allocations count unless a flats_only entry is linked to a payment', () {
      final rows = buildFlatReportRows(
        from: '2026-03-01',
        to: '2026-03-31',
        selectedFlat: 'all',
        payments: const [
          FinancePeriodPayment(paymentStatus: 'verified', flatNumber: '101', amount: 100, dueDate: '2026-03-02', financeEntryId: 'fe1'),
        ],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'fe1',
            recordMode: 'flats_only',
            destination: 'current_month_maintenance',
            transactionDate: '2026-03-02',
            allocations: [FinanceEntryAllocation(flatNumber: '101', amount: 100)],
          ),
          FinancePeriodLedgerEntry(
            id: 'fe2',
            recordMode: 'mixed',
            destination: 'corpus',
            transactionDate: '2026-03-04',
            allocations: [
              FinanceEntryAllocation(flatNumber: '102', amount: 50),
              FinanceEntryAllocation(flatNumber: 'SOCIETY', amount: 70),
            ],
          ),
        ],
        flatReportExpenses: const [],
        flatReportSplits: const [],
        flats: const [],
        primaryByFlatId: const {},
        charges: const [],
      );
      expect(rows.map((r) => r.flatNumber), ['101', '102']);
      expect(rows[0].maintenancePaid, 100);
      expect(rows[1].maintenancePaid, 50);
    });
  });

  group('statementAmountTotals', () {
    test('sums row amounts', () {
      expect(sumAmountRows(const [100, -30, null]), 70);
    });

    test('groups by month from dateIso', () {
      expect(
        monthlyAmountTotals(const [
          AmountRow(amount: 500, dateIso: '2026-04-05'),
          AmountRow(amount: 200, dateIso: '2026-04-20'),
          AmountRow(amount: 100, dateIso: '2026-05-01'),
        ]),
        const [
          MonthlyAmountTotal(monthKey: '2026-04', label: '04/2026', total: 700, count: 2),
          MonthlyAmountTotal(monthKey: '2026-05', label: '05/2026', total: 100, count: 1),
        ],
      );
    });

    test('parses display dates when dateIso is missing', () {
      expect(monthlyAmountTotals(const [AmountRow(amount: 50, date: '15/03/2026')]), const [
        MonthlyAmountTotal(monthKey: '2026-03', label: '03/2026', total: 50, count: 1),
      ]);
    });
  });

  group('formatLedgerFieldLabel', () {
    test('formats snake_case enums', () {
      expect(formatLedgerFieldLabel('society_pool'), 'society pool');
      expect(formatLedgerFieldLabel('current_month_maintenance'), 'current month maintenance');
    });

    test('returns fallback for nullish values', () {
      expect(formatLedgerFieldLabel(null), '—');
      expect(formatLedgerFieldLabel('', fallback: 'unknown'), 'unknown');
    });
  });

  group('JS compat + formatters', () {
    test('toLocaleString en-IN and money', () {
      expect(toLocaleIn(1234567), '12,34,567');
      expect(toLocaleIn(1234.5), '1,234.5');
      expect(toLocaleIn(1.23456), '1.235');
      expect(moneyInr(1234.567), '₹1,234.57');
      expect(rupees(-1500), '₹-1,500');
      expect(fmtSignedRupees(-1500), '−₹1,500');
      expect(fmtCashFlowAmount(0), '—');
      expect(jsNumberString(1500.0), '1500');
      expect(jsNumberString(12.5), '12.5');
    });

    test('date display helpers', () {
      expect(fmtIsoMonthToDisplay('2026-04'), '04/2026');
      expect(fmtIsoMonthToDisplay('bad'), 'bad');
      expect(fmtIsoDateToDisplay('2026-04-09'), '09/04/2026');
      expect(fmtDate('2026-04-09'), '09/04/2026');
      expect(jsDateMs('2026-04-09'), DateTime.utc(2026, 4, 9).millisecondsSinceEpoch);
      expect(jsDateMs('nope'), isNull);
    });

    test('numeric localeCompare orders flats like the web', () {
      final flats = ['A-110', 'A-12', 'A-101', '605', '101', 'b-1'];
      flats.sort(compareFlatNumbers);
      expect(flats, ['101', '605', 'A-12', 'A-101', 'A-110', 'b-1']);
      expect(compareByFlatThenDate(null, '101', '2026-01-02', '2026-01-01'), greaterThan(0));
    });
  });

  group('report aggregations', () {
    const entries = [
      FinancePeriodLedgerEntry(id: '1', recordMode: 'flats_only', destination: 'current_month_maintenance', totalAmount: 100, aggregateFlatCount: 2, transactionDate: '2026-04-01'),
      FinancePeriodLedgerEntry(id: '2', recordMode: 'flats_only', destination: 'current_month_maintenance', totalAmount: 50, aggregateFlatCount: 1, transactionDate: '2026-04-30'),
      FinancePeriodLedgerEntry(id: '3', recordMode: 'society_pool', destination: 'separate_entry', totalAmount: 70, paymentStatus: 'pending', transactionDate: '2026-05-01'),
    ];

    test('inflow groups by mode + destination', () {
      final g = computeLedgerInflowGroups(entries);
      expect(g, hasLength(2));
      expect(g.first.total, 150);
      expect(g.first.flatUnits, 3);
      expect(g.first.count, 2);
      expect(computeLedgerInflowGroups(entries, excludeSeparateEntry: true), hasLength(1));
    });

    test('status buckets and date-range filter', () {
      final b = computeLedgerStatusBuckets(entries);
      expect(b, const [StatusBucket(status: 'verified', count: 2, total: 150), StatusBucket(status: 'pending', count: 1, total: 70)]);
      expect(filterLedgerByTransactionDateRange(entries, '2026-04-01', '2026-04-30').map((e) => e.id), ['1', '2']);
    });
  });

  group('report query filter', () {
    test('visitors / ledger / detail rows / shifts', () {
      final vs = [visitor('a', name: 'Sunita', vehicle: 'RJ14AB1234'), visitor('b', name: 'Mohan', cat: 'delivery')];
      expect(filterVisitorRows(vs, ' rj14 ').map((v) => v.id), ['a']);
      expect(filterVisitorRows(vs, '').length, 2);
      const l = [FinancePeriodLedgerEntry(id: 'x', destination: 'corpus', totalAmount: 1500, transactionId: 'TXN9')];
      expect(filterLedgerEntries(l, '1500').length, 1);
      expect(filterLedgerEntries(l, 'txn9').length, 1);
      expect(filterLedgerEntries(l, 'zzz'), isEmpty);
      const rows = [ReportDetailRow(id: '1', label: 'Flat 101', amount: 250), ReportDetailRow(id: '2', label: 'Other', status: 'pending')];
      expect(filterReportDetailRows(rows, '250').map((r) => r.id), ['1']);
      expect(filterReportDetailRows(rows, 'PEND').map((r) => r.id), ['2']);
      const shifts = [ReportShiftRow(id: 's', guardId: 'G7', guardName: 'Kishan', loginTime: '2026-04-01T08:00:00Z')];
      expect(filterShiftRows(shifts, 'g7').length, 1);
    });
  });

  group('cash flow statement', () {
    test('lines, statement entries and drill filters', () {
      final cfs = computeCashFlowStatement(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePeriodPayment(id: 'p1', paymentStatus: 'verified', amount: 1000, paymentMethod: 'cash', dueDate: '2026-04-03', flatNumber: '102'),
          FinancePeriodPayment(id: 'p2', paymentStatus: 'verified', amount: 400, paymentMethod: 'upi', dueDate: '2026-04-03', flatNumber: '101'),
        ],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(id: 'e1', destination: 'separate_entry', totalAmount: 300, paymentMethod: 'cash', title: 'Electricity', transactionDate: '2026-04-10'),
          FinancePeriodLedgerEntry(id: 'c1', destination: 'corpus', totalAmount: 200, paymentMethod: 'neft', transactionDate: '2026-04-12'),
        ],
        reserveTransfers: const [
          FinancePeriodReserveTransfer(id: 'r1', entryMonth: '2026-04', amount: 150, direction: 'operating_to_reserve', paymentMethod: 'bank_transfer'),
          FinancePeriodReserveTransfer(id: 'r2', entryMonth: '2026-04', amount: 50, direction: 'reserve_to_operating', paymentMethod: 'cash'),
        ],
      );
      double line(String id) => cfs.lines.firstWhere((l) => l.id == id).amount;
      expect(line('op-receipts'), 1400);
      expect(line('op-corpus'), 200);
      expect(line('op-exp-Electricity'), -300);
      expect(line('op-net'), 1300);
      expect(line('inv-reserve'), -150);
      expect(line('fin-reserve'), 50);
      expect(line('net-change'), 1200);
      expect(cfs.statementEntries, hasLength(5));
      final receipts = filterStatementEntriesForDrill(cfs.statementEntries, CashFlowDrillKind.receipts);
      expect(receipts.map((e) => e.id), ['p2', 'p1', 'c1']);
      final cash = addRunningBalance(filterStatementByChannel(cfs.statementEntries, PaymentChannel.cash), 100);
      expect(cash.last.runningBalance, 100 + 1000 - 300 + 50);
      expect(filterStatementEntriesForDrill(cfs.statementEntries, CashFlowDrillKind.expenseHead, 'Electricity').single.id, 'e1');
    });
  });

  group('monthly report export', () {
    test('financial + visitor sheets', () {
      final r = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(id: 'e', destination: 'separate_entry', totalAmount: 300, paymentMethod: 'cash', transactionDate: '2026-04-10'),
        ],
      );
      final sheets = monthlyReportSheets(ReportExportContext(
        societyName: 'S',
        reportMonth: '04/2026',
        tab: MonthlyReportTab.allModules,
        financeEntries: const [
          FinancePeriodLedgerEntry(id: 'e', destination: 'separate_entry', totalAmount: 300, paymentMethod: 'cash', transactionDate: '2026-04-10'),
        ],
        periodReport: r,
        reportMonthNet: r,
        visitors: [visitor('a', vehicle: 'X1'), visitor('b', cat: 'service', exit: '2026-04-05T11:00:00Z')],
      ));
      expect(sheets.map((s) => s.name), [
        'Summary',
        'Receipts by head',
        'Expenses by head',
        'Monthly totals',
        'Totals by mode',
        'All entries',
        'Summary',
        'Visitors',
      ]);
      expect(sheets[0].rows[5], ['Total balance', -300]);
      expect(sheets[3].rows.last, ['Total', 1, 300]);
      expect(sheets[6].rows[1], ['Total visitors', 1]);
      expect(sheets[6].rows[4], ['Currently inside', 1]);
      final stats = ReportVisitorStats.of([visitor('a', vehicle: 'X1'), visitor('b', cat: 'delivery', flat: '102')]);
      expect(stats.totalVehicles, 1);
      expect(stats.totalDeliveries, 1);
      expect(stats.uniqueFlats, 2);
    });

    test('report detail filename slug', () {
      expect(reportDetailPdfFilename('Finance — All Entries', DateTime.utc(2026, 4, 9)), 'finance-all-entries-2026-04-09.pdf');
      expect(reportDetailPdfFilename('हिंदी', DateTime.utc(2026, 4, 9)), 'report-detail-2026-04-09.pdf');
    });
  });

  group('metadata reporting engine', () {
    final rows = <Map<String, dynamic>>[
      {'id': '1', 'transaction_date': '2026-04-02', 'title': 'Maint', 'record_mode': 'flats_only', 'destination': 'corpus', 'payment_method': 'upi', 'payment_status': 'verified', 'total_amount': 500},
      {'id': '2', 'transaction_date': '2026-04-05', 'title': 'Hall', 'record_mode': 'society_pool', 'destination': 'corpus', 'payment_method': 'cash', 'payment_status': 'pending', 'total_amount': 300},
      {'id': '3', 'transaction_date': '2026-04-01', 'title': 'Maint 2', 'record_mode': 'flats_only', 'destination': 'current_month_maintenance', 'payment_method': 'upi', 'payment_status': 'verified', 'total_amount': 200},
    ];
    ReportService service() => ReportService(source: MemorySource(rows));
    bool allow(String _) => true;

    test('catalog honours permissions and validates definitions', () {
      expect(service().listCatalog(allow).map((d) => d.id), kBuiltinReportDefinitions.map((d) => d.id));
      expect(service().listCatalog((k) => k != 'report'), isEmpty);
      for (final d in kBuiltinReportDefinitions) {
        MetadataLoader().validate(d);
      }
      expect(() => MetadataLoader().require('nope'), throwsStateError);
    });

    test('select string includes base fields, id and joins', () {
      const b = DynamicQueryBuilder();
      expect(b.buildSelect(maintenancePaymentsReport), contains('maintenance_charges!inner(id,title,society_id)'));
      expect(b.buildSelect(maintenancePaymentsReport).split(','), contains('id'));
      expect(b.sortField(maintenancePaymentsReport, const ReportSortDef(field: 'maintenance_charges.title', ascending: true)), isNull);
      expect(b.sortField(financeReceiptsReport, null), 'transaction_date');
      expect(b.dateBound('2026-04-01', start: false), '2026-04-01T23:59:59.999');
    });

    test('runs with default sort, totals, search and paging', () async {
      final r = await service().run(ReportRequest(reportId: 'finance_receipts', societyId: 's', permissions: allow));
      expect(r.rows.map((x) => x['id']), ['2', '1', '3']);
      expect(r.totals.single.value, 1000);
      expect(r.columns.length, 7);
      final searched = await service().run(ReportRequest(reportId: 'finance_receipts', societyId: 's', permissions: allow, search: 'maint'));
      expect(searched.totalRows, 2);
      final paged = await service().run(ReportRequest(reportId: 'finance_receipts', societyId: 's', permissions: allow, pageSize: 2, page: 2));
      expect(paged.rows, hasLength(1));
      expect(paged.totalPages, 2);
      expect(() => service().run(ReportRequest(reportId: 'finance_receipts', societyId: 's', permissions: (_) => false)), throwsStateError);
    });

    test('grouping aggregates numeric columns and labels the rest', () async {
      final r = await service().run(ReportRequest(
        reportId: 'finance_receipts',
        societyId: 's',
        permissions: allow,
        columns: const ['record_mode', 'title', 'total_amount'],
        groupBy: const ['record_mode'],
        sort: const ReportSortDef(field: 'record_mode', ascending: true),
      ));
      expect(r.grouped, isTrue);
      expect(r.rows.first['record_mode'], 'flats_only');
      expect(r.rows.first['total_amount'], 700);
      expect(r.rows.first['title'], '2 rows');
      expect(r.rows.last['title'], 'Hall');
    });

    test('export matrix adds a TOTAL row', () async {
      final r = await service().run(ReportRequest(
        reportId: 'finance_receipts',
        societyId: 's',
        permissions: allow,
        columns: const ['title', 'total_amount'],
      ));
      final m = reportResultMatrix(r);
      expect(m.headers, ['Title', 'Amount']);
      expect(m.rows.last, ['TOTAL', '₹1,000']);
      expect(m.numericCols, {1});
      expect(formatReportCell(financeReceiptsReport.columns[6], 1234.5), '₹1,234.5');
      expect(formatReportCell(guardShiftsReport.columns[2], '2026-04-01T08:30:00.123+00:00'), '2026-04-01 08:30:00');
      expect(formatReportCell(guardShiftsReport.columns[3], null), '—');
    });
  });
}
