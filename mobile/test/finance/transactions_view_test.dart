// Finance → Transactions filters / totals (web FinanceManager memo chain).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_derived.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_totals_breakdown.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/transaction_statement_rows.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/transactions_view.dart';

void main() {
  const data = FinanceCoreData(
    flats: [
      SocietyFlatRow(id: 'f1', flatNumber: '101', ownerName: 'A', isOccupied: true),
      SocietyFlatRow(id: 'f2', flatNumber: '102', ownerName: 'B', isOccupied: true),
      SocietyFlatRow(id: 'f3', flatNumber: '103', ownerName: 'C', isOccupied: false),
      SocietyFlatRow(id: 'f4', flatNumber: '11', ownerName: 'D', isOccupied: true),
    ],
    charges: [
      FinanceCharge(id: 'm', title: 'July Monthly Maintenance', amount: 2500, frequency: 'monthly'),
      FinanceCharge(id: 'y', title: 'Lift AMC', amount: 1200, frequency: 'yearly'),
    ],
    payments: [
      FinancePayment(
        id: 'p1',
        chargeId: 'm',
        flatNumber: '101',
        amount: 2500,
        paymentMethod: 'cash',
        paymentStatus: 'verified',
        dueDate: '2026-07-05',
        createdAt: '2026-07-05T08:00:00Z',
        financeEntryId: 'fe-1',
      ),
      FinancePayment(
        id: 'p2',
        chargeId: 'm',
        flatNumber: '102',
        amount: 2500,
        paymentMethod: 'upi',
        paymentStatus: 'pending',
        dueDate: '2026-07-06',
        createdAt: '2026-07-06T08:00:00Z',
      ),
      FinancePayment(
        id: 'p3',
        chargeId: 'y',
        flatNumber: '11',
        amount: 1200,
        paymentMethod: 'bank_transfer',
        paymentStatus: 'verified',
        dueDate: '2026-06-10',
        createdAt: '2026-06-10T08:00:00Z',
        transactionId: 'UTR123',
      ),
    ],
    ledgerEntries: [
      FinanceLedgerRow(
        id: 'fe-1',
        recordMode: 'flats_only',
        destination: 'current_month_maintenance',
        chargeId: 'm',
        totalAmount: 2500,
        transactionDate: '2026-07-05',
        createdAt: '2026-07-05T08:00:00Z',
        allocations: [FinanceAllocation(flatNumber: '101', amount: 2500)],
      ),
      FinanceLedgerRow(
        id: 'pool',
        recordMode: 'society_pool',
        destination: 'corpus',
        totalAmount: 9000,
        transactionDate: '2026-07-10',
        createdAt: '2026-07-10T08:00:00Z',
        title: 'Bank interest',
        counterparties: [FinanceCounterparty(name: 'SBI')],
      ),
      FinanceLedgerRow(
        id: 'exp',
        recordMode: 'outsider_only',
        destination: 'separate_entry',
        expenseId: 'e1',
        totalAmount: 4000,
        paymentMethod: 'upi',
        transactionDate: '2026-07-12',
        createdAt: '2026-07-12T08:00:00Z',
        title: 'Electricity',
      ),
      FinanceLedgerRow(
        id: 'food',
        recordMode: 'outsider_only',
        destination: 'separate_entry',
        expenseId: 'e2',
        totalAmount: 700,
        transactionDate: '2026-07-12',
        createdAt: '2026-07-12T09:00:00Z',
        title: 'Event food — Diwali',
      ),
    ],
    expenseCategoryById: {'e1': 'payment', 'e2': 'food'},
  );
  final d = FinanceDerived(data);

  test('society ledger excludes event food and linked entries are hidden', () {
    expect(d.societyLedgerEntries.map((e) => e.id), isNot(contains('food')));
    final v = TransactionsView.compute(d, const TransactionsQuery());
    expect(v.lineItems.map((i) => i.key).toList(), ['mp-p3', 'mp-p1', 'mp-p2', 'ledger-pool', 'ledger-exp']);
    expect(v.summaryCount, 5);
    expect(v.summarySum, 2500 + 2500 + 1200 + 9000 + 4000);
    expect(v.summaryFlatCount, 3);
  });

  test('status, type and month filters', () {
    expect(
      TransactionsView.compute(d, const TransactionsQuery(filterStatus: 'pending')).lineItems.map((i) => i.key).toList(),
      ['mp-p2'],
    );
    final monthly = TransactionsView.compute(d, const TransactionsQuery(paymentTypeFilter: 'monthly_maintenance'));
    expect(monthly.filteredPayments.map((p) => p.id).toList(), ['p1', 'p2']);
    expect(monthly.scopedLedgerOnly, isEmpty);
    final payments = TransactionsView.compute(d, const TransactionsQuery(paymentTypeFilter: 'all_payments'));
    expect(payments.filteredPayments, isEmpty);
    expect(payments.scopedLedgerOnly.map((e) => e.id).toList(), ['exp']);
    final june = TransactionsView.compute(d, const TransactionsQuery(paymentMonthFilter: '2026-06'));
    expect(june.lineItems.map((i) => i.key).toList(), ['mp-p3']);
  });

  test('search matches txn ids, notes and counterparties', () {
    expect(
      TransactionsView.compute(d, const TransactionsQuery(search: 'utr123')).lineItems.map((i) => i.key).toList(),
      ['mp-p3'],
    );
    expect(
      TransactionsView.compute(d, const TransactionsQuery(search: 'sbi')).lineItems.map((i) => i.key).toList(),
      ['ledger-pool'],
    );
  });

  test('head-wise summaries split receipts and society payments', () {
    final v = TransactionsView.compute(d, const TransactionsQuery());
    expect(v.receiptHeadSummary.map((r) => r.head).toList(), ['SOCIETY CORPUS FUND', 'OPERATION & MAINTENANCE']);
    expect(v.receiptHeadSummary[1].total, 6200);
    expect(v.paymentHeadSummary.single.head, 'Electricity');
    expect(v.paymentHeadSummary.single.byChannel.bank, 4000);
    expect(v.receiptHeadEntryRows('OPERATION & MAINTENANCE').map((r) => r.id).toList(), ['mp-p3', 'mp-p1', 'mp-p2']);
    expect(v.paymentHeadEntryRows('Electricity').single.id, 'ledger-exp');
  });

  test('unpaid grid lists occupied flats without verified payments', () {
    final v = TransactionsView.compute(d, const TransactionsQuery(filterStatus: 'unpaid'));
    expect(v.unpaidRows.map((r) => r.flatNumber).toList(), ['102']);
    expect(v.unpaidRows.single.pendingPayment, 'pending');
    expect(v.summaryCount, 1);
    final withVacant = TransactionsView.compute(d, const TransactionsQuery(filterStatus: 'unpaid', includeVacantFlats: true));
    expect(withVacant.unpaidRows.map((r) => r.flatNumber).toList(), ['102', '103']);
  });

  test('reminder rows use any verified payment and the current maintenance charge', () {
    final rows = d.unpaidReminderRows(includeVacant: false);
    expect(rows.map((r) => r.flatNumber).toList(), ['102']);
    expect(rows.single.dueAmount, 2500);
  });

  test('payment type options follow the data', () {
    expect(paymentTypeOptionValues(d), [
      'all',
      'all_payments',
      'all_receipts',
      'society_pool_pending',
      'monthly_maintenance',
      'yearly',
      'corpus',
      'outsider_mixed',
    ]);
    expect(monthOptionsForReceipts(d).map((o) => o.value).toList(), ['all', '2026-07', '2026-06']);
    expect(monthOptionsForReceipts(d)[1].label, '07/2026');
  });

  test('statement rows', () {
    final v = TransactionsView.compute(d, const TransactionsQuery());
    final rows = buildTransactionExportRows(items: v.lineItems, chargeTitleById: d.chargeTitleById);
    expect(rows.first.type, 'Maintenance receipt');
    expect(rows.first.description, 'Lift AMC');
    expect(rows.first.method, 'BANK_TRANSFER');
    final pool = rows.firstWhere((r) => r.description == 'Bank interest');
    expect(pool.type, 'corpus');
    expect(pool.flat, '—');
    expect(pool.counterparty, 'SBI');
  });

  test('totals breakdown for a month', () {
    final t = FinanceTotalsBreakdown.compute(
      ledgerEntries: data.ledgerEntries,
      societyLedgerEntries: d.societyLedgerEntries,
      totalsMonth: '2026-07',
      expenseCategoryById: data.expenseCategoryById,
    );
    expect(t.totalsBreakdown.map((r) => '${r.mode}/${r.destination}').toList(), [
      'flats_only/current_month_maintenance',
      'society_pool/corpus',
    ]);
    expect(t.totalsMonthNet, 11500);
    expect(t.totalsOutflowBreakdown.single.head, 'Electricity');
    expect(t.totalsMonthOutflow, 4000);
    expect(t.totalsMonthPaymentChannels.bank, 4000);
  });
}
