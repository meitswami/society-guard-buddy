// Smoke test: every Finance sub-tab renders at phone width with a fake repository
// (web FinanceManager.render.test.tsx equivalents included).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/core/i18n/i18n.dart';
import 'package:kutumbika_mobile/core/prefs/app_prefs.dart';
import 'package:kutumbika_mobile/core/theme/kutumbika_theme.dart';
import 'package:kutumbika_mobile/features/admin/core/admin_module.dart';
import 'package:kutumbika_mobile/features/admin/finance/admin_finance_module.dart';
import 'package:kutumbika_mobile/features/admin/finance/data/finance_repository.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/record_receipt_plan.dart';
import 'package:kutumbika_mobile/models/admin_user.dart';
import 'package:kutumbika_mobile/models/session_models.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements FinanceRepository {
  final calls = <String>[];

  static final _core = FinanceCoreData(
    societyName: 'Test Society',
    flats: const [
      SocietyFlatRow(id: 'f1', flatNumber: '101', ownerName: 'Owner', isOccupied: true),
      SocietyFlatRow(id: 'f2', flatNumber: '102', ownerName: 'Owner 2', isOccupied: true),
    ],
    charges: const [
      FinanceCharge(id: 'ch-1', title: 'July 2026 Maintenance', amount: 500, frequency: 'monthly'),
      FinanceCharge(id: 'ch-2', title: 'Lift AMC', amount: 1200, frequency: 'yearly', expenseGroupId: 'g1'),
    ],
    paymentExpenseGroups: const [PaymentExpenseGroup(id: 'g1', name: 'Lift AMC', majorHead: 'OPERATION & MAINTENANCE')],
    payments: const [
      FinancePayment(
        id: 'p1',
        chargeId: 'ch-1',
        flatNumber: '101',
        amount: 500,
        paymentStatus: 'pending',
        dueDate: '2026-07-04',
        createdAt: '2026-07-04T10:00:00Z',
      ),
      FinancePayment(
        id: 'p2',
        chargeId: 'ch-1',
        flatNumber: '102',
        amount: 500,
        paymentStatus: 'verified',
        receiptNumber: 'MR-000001',
        dueDate: '2026-07-05',
        createdAt: '2026-07-05T10:00:00Z',
      ),
    ],
    ledgerEntries: const [
      // Web render test: ledger row missing record_mode / destination.
      FinanceLedgerRow(
        id: 'fe-1',
        entryMonth: '2026-07',
        transactionDate: '2026-07-01',
        totalAmount: 1000,
        title: 'Pool receipt',
        createdAt: '2026-07-01T10:00:00Z',
      ),
      FinanceLedgerRow(
        id: 'fe-2',
        recordMode: 'outsider_only',
        destination: 'separate_entry',
        expenseId: 'e1',
        totalAmount: 400,
        transactionDate: '2026-07-02',
        title: 'Electricity',
        createdAt: '2026-07-02T10:00:00Z',
      ),
    ],
    expenseCategoryById: const {'e1': 'payment'},
  );

  @override
  Future<FinanceCoreData> fetchCore(String societyId, String adminName) async => _core;
  @override
  Future<FinanceEventReference> fetchEventReference(String societyId) async => const FinanceEventReference(
        contributions: [EventContribRefRow(id: 'c1', flatNumber: '101', amount: 300, eventTitle: 'Diwali')],
        foodExpenses: [EventFoodRefRow(id: 'x1', title: 'Snacks', totalAmount: 900, expenseDate: '2026-07-03')],
      );
  @override
  Future<FinanceFlatReportData> fetchFlatReport(String societyId) async => const FinanceFlatReportData();
  @override
  Future<List<OpeningBalanceAnchor>> fetchOpeningAnchors(String societyId) async => const [];
  @override
  Future<void> saveOpeningAnchor(String societyId, OpeningBalanceAnchor anchor) async {}
  @override
  Future<void> deleteOpeningAnchor(String id) async {}
  @override
  Future<List<ReserveTransfer>> fetchReserveTransfers(String societyId) async => const [];
  @override
  Future<void> insertReserveTransfer({
    required String societyId,
    required String entryMonth,
    required double amount,
    required String direction,
    required String? notes,
    required String adminName,
  }) async {}
  @override
  Future<HeadFundData> fetchHeadFundData(String societyId) async => const HeadFundData(
        groups: [HeadFundGroup(id: 'g1', name: 'Lift AMC')],
        charges: [HeadFundCharge(id: 'ch-2', title: 'Lift AMC', expenseGroupId: 'g1')],
        expenses: [
          HeadFundExpense(
            id: 'e1',
            groupId: 'g1',
            title: 'Lift repair',
            totalAmount: 900,
            expenseDate: '2026-07-01',
            paymentMethod: 'cash',
            groupName: 'Lift AMC',
          ),
        ],
      );
  @override
  Future<void> insertHeadAdjustment({
    required String societyId,
    required String groupId,
    required double amount,
    required String sourceType,
    required String flatNumber,
    required String notes,
    required String adminName,
  }) async {}
  @override
  Future<String> createExpenseGroup({
    required String societyId,
    required String name,
    required String majorHead,
    String? description,
    required String createdBy,
  }) async =>
      'g-new';
  @override
  Future<void> updateExpenseGroup({
    required String societyId,
    required String groupId,
    required String name,
    required String? description,
    required String majorHead,
  }) async {}
  @override
  Future<void> deleteExpenseGroup(String societyId, String groupId) async {}
  @override
  Future<void> insertCharge(String societyId, String adminName, ChargeInput input) async => calls.add('insertCharge:${input.title}');
  @override
  Future<void> updateCharge(String societyId, String chargeId, ChargeInput input) async {}
  @override
  Future<void> deleteCharge(String societyId, String chargeId) async {}
  @override
  Future<void> distributePool({
    required String entryId,
    required List<AllocationInsert> allocationRows,
    required List<Map<String, dynamic>> maintenancePaymentRows,
    required int aggregateFlatCount,
    required String title,
  }) async {}
  @override
  Future<String> persistFinanceRecord(RecordReceiptPlan plan) async => 'fe-new';
  @override
  Future<void> updatePaymentStatus(String paymentId, String status, String adminName, [String? reason]) async {}
  @override
  Future<void> updatePayment(String paymentId, Map<String, dynamic> payload) async {}
  @override
  Future<void> deletePaymentRow({required String id, required String flatNumber, String? financeEntryId}) async {}
  @override
  Future<void> updateLedgerStatus(String entryId, String status) async {}
  @override
  Future<void> updateLedger(String entryId, Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteLedger(String entryId) async {}
  @override
  Future<void> sendMaintenanceReminders(String societyId, String adminName, List<String> flatNumbers) async {}
  @override
  Future<void> upsertReminderSettings(String societyId, FinanceReminderSettings s) async {}
  @override
  Future<int> invokeReminderTest(String societyId) async => 0;
  @override
  Future<MonthlyBillIssueResult> invokeIssueMonthlyBill(String societyId) async => const MonthlyBillIssueResult(issued: 0);
  @override
  Future<void> notifyPaymentDecision({
    required String societyId,
    required String adminName,
    required String flatNumber,
    required String title,
    required String message,
  }) async {}
  @override
  Future<bool> notifyResidentsOfRecord({
    required String societyId,
    required String adminName,
    required String audience,
    required List<String> selectedFlatNumbers,
    required String title,
    required String message,
    required String notificationType,
    required String? billUrl,
  }) async =>
      true;
  @override
  Future<List<FinancePayment>> queryReceiptHeadConflicts({
    required String chargeId,
    String? paymentMethod,
    required List<({String flatNumber, String dueDate})> targets,
    List<String> monthlyMaintenanceChargeIds = const [],
  }) async =>
      const [];
  @override
  Future<String?> uploadMaintenanceReceipt(Uint8List bytes, String fileName, {String? contentType}) async => null;
}

AdminModuleContext _ctx({String? subTab, String? query}) => AdminModuleContext(
      session: const SessionAdmin(
        societyId: 's1',
        societyName: 'Test Society',
        admin: AdminUser(id: 'a1', name: 'Admin', adminId: 'A1', societyId: 's1', permissions: AdminPanelPermissions.full),
      ),
      goTo: (tab, {query, subTab}) {},
      subTab: subTab,
      initialQuery: query,
    );

Future<void> _pump(WidgetTester tester, AdminModuleContext ctx, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: KutumbikaTheme.light(),
      builder: (context, child) => I18nScope(translator: const Translator(AppLang.en), child: child!),
      home: Scaffold(body: FinanceManagerView(ctx: ctx, repository: repo)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app-lang': 'en'});
    await AppPrefs.init();
  });

  testWidgets('renders receipt types by default', (tester) async {
    await _pump(tester, _ctx(), _FakeRepo());
    expect(find.text('Lift AMC'), findsWidgets);
    expect(find.textContaining('2 receipt types'), findsOneWidget);
  });

  testWidgets('renders Record receipt panel when opened via sub-tab', (tester) async {
    await _pump(tester, _ctx(subTab: 'payments'), _FakeRepo());
    expect(find.text('RECORDING STYLE'), findsOneWidget);
  });

  testWidgets('renders Transactions with ledger rows missing record_mode', (tester) async {
    await _pump(tester, _ctx(subTab: 'receipts'), _FakeRepo());
    expect(find.text('Pool receipt'), findsOneWidget);
    expect(find.text('Flat 101'), findsWidgets);
  });

  testWidgets('initial search query opens Transactions filtered', (tester) async {
    await _pump(tester, _ctx(query: '102'), _FakeRepo());
    expect(find.text('Flat 102'), findsWidgets);
    expect(find.text('Pool receipt'), findsNothing);
  });

  testWidgets('renders payment types, record payment and totals', (tester) async {
    for (final sub in ['create_payment', 'record_payment', 'totals']) {
      await _pump(tester, _ctx(subTab: sub), _FakeRepo());
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('Monthly operating fund'), findsWidgets);
  });

  testWidgets('reminders panel toggles open', (tester) async {
    await _pump(tester, _ctx(), _FakeRepo());
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Due reminders'), findsOneWidget);
  });
}
