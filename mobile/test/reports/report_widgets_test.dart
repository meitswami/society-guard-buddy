// Render smoke tests for the report widgets that need no backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/theme/app_tokens.dart';
import 'package:kutumbika_mobile/features/admin/reports/data/report_models.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_period_report.dart';
import 'package:kutumbika_mobile/features/admin/reports/widgets/cash_flow_statement_view.dart';
import 'package:kutumbika_mobile/features/admin/reports/widgets/finance_period_head_tables.dart';
import 'package:kutumbika_mobile/features/admin/reports/widgets/flat_report_view.dart';
import 'package:kutumbika_mobile/features/admin/reports/widgets/report_detail_sheet.dart';

Widget host(Widget child, {AppLang lang = AppLang.en}) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTokens.light]),
        builder: (context, c) =>
            I18nScope(translator: Translator(lang), child: c!),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

const payments = [
  FinancePeriodPayment(
      id: 'p1',
      paymentStatus: 'verified',
      amount: 1000,
      paymentMethod: 'cash',
      dueDate: '2026-04-03',
      flatNumber: '101'),
];
const ledger = [
  FinancePeriodLedgerEntry(
      id: 'e1',
      destination: 'separate_entry',
      totalAmount: 300,
      paymentMethod: 'upi',
      title: 'Electricity',
      transactionDate: '2026-04-10'),
];

void main() {
  testWidgets('head-wise tables render receipts and expenses', (tester) async {
    final r = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: payments,
        ledgerEntries: ledger);
    await tester.pumpWidget(host(FinancePeriodHeadTables(report: r)));
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('All receipts'), findsOneWidget);
  });

  testWidgets('cash flow statement renders lines and opens a drill sheet',
      (tester) async {
    await tester.pumpWidget(host(const CashFlowStatementView(
      periodFrom: '2026-04-01',
      periodTo: '2026-04-30',
      payments: payments,
      societyLedgerEntries: ledger,
      expenseCategoryById: {},
      reserveTransfers: [],
    )));
    expect(find.text('Operating Activities'), findsOneWidget);
    expect(find.text('Payment — Electricity'), findsOneWidget);
    await tester.tap(find.text('Payment — Electricity'));
    await tester.pumpAndSettle();
    expect(find.text('Electricity'), findsWidgets);
  });

  testWidgets('cash flow shows the invalid range message', (tester) async {
    await tester.pumpWidget(host(const CashFlowStatementView(
      periodFrom: '2026-05-01',
      periodTo: '2026-04-30',
      payments: [],
      societyLedgerEntries: [],
      expenseCategoryById: {},
      reserveTransfers: [],
    )));
    expect(find.textContaining('End date must be on or after'), findsOneWidget);
  });

  testWidgets('flat report shows empty state in Hindi', (tester) async {
    await tester.pumpWidget(host(
      FlatReportView(
        from: '2026-04-01',
        to: '2026-04-30',
        selectedFlat: 'all',
        onFromChanged: (_) {},
        onToChanged: (_) {},
        onSelectedFlatChanged: (_) {},
        flats: const [ReportFlat(id: 'f1', flatNumber: '101')],
        primaryByFlatId: const {},
        isLoading: false,
        rows: const [],
      ),
      lang: AppLang.hi,
    ));
    expect(find.text('फ्लैट-वार वित्तीय प्रतिवेदन'), findsOneWidget);
  });

  testWidgets('detail sheet filters rows and shows totals', (tester) async {
    await tester.pumpWidget(host(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => ReportDetailSheet.show(
          context,
          const ReportDetailLayer(title: 'Test list', rows: [
            ReportDetailRow(
                id: '1', label: 'Flat 101', amount: 500, dateIso: '2026-04-02'),
            ReportDetailRow(
                id: '2',
                label: 'Flat 102',
                amount: -200,
                dateIso: '2026-05-02'),
          ]),
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Flat 101'), findsOneWidget);
    expect(find.text('04/2026 (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '102');
    await tester.pumpAndSettle();
    expect(find.text('Flat 101'), findsNothing);
    expect(find.text('Flat 102'), findsOneWidget);
  });
}
