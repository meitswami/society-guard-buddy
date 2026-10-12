// Finance → Transactions (web `subTab === 'receipts'`): search, status pills, type / month / mode
// filters, summary + statement export / WhatsApp share, head-wise summaries with drill-down,
// bulk actions, payment & ledger cards, unpaid grid and the Events & food reference lists.

import 'package:flutter/material.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../export/finance_exports.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/finance_ledger_display.dart';
import '../logic/finance_models.dart';
import '../logic/transaction_statement_rows.dart';
import '../logic/transactions_view.dart';
import '../sheets/finance_entry_sheets.dart';
import '../state/finance_actions.dart';
import '../state/finance_controller.dart';
import '../state/finance_forms.dart';
import '../widgets/cash_bank_breakdown.dart';
import '../widgets/fin_kit.dart';
import '../widgets/finance_metric_copy.dart';
import '../widgets/finance_widgets.dart';

class FinanceTransactionsTab extends StatefulWidget {
  const FinanceTransactionsTab({super.key, required this.c, required this.filters, required this.includeVacantFlats});

  final FinanceController c;
  final TransactionsFilterModel filters;
  final bool includeVacantFlats;

  @override
  State<FinanceTransactionsTab> createState() => _FinanceTransactionsTabState();
}

class _FinanceTransactionsTabState extends State<FinanceTransactionsTab> {
  FinanceController get c => widget.c;
  TransactionsFilterModel get f => widget.filters;
  late final FinanceActions actions = FinanceActions(c);

  @override
  void initState() {
    super.initState();
    c.loadEventReference();
  }

  String _typeLabel(String v) => switch (v) {
        'all' => context.tr('--All--', '--सभी--'),
        'all_payments' => context.tr('Society payment records', 'सोसाइटी भुगतान रिकॉर्ड'),
        'all_receipts' => context.tr('All society receipt records', 'सभी सोसाइटी रसीद रिकॉर्ड'),
        'society_pool_pending' => context.tr('In society pool (not yet distributed)', 'सोसाइटी पूल में (अभी बाँटा नहीं)'),
        'monthly_maintenance' => context.tr('Monthly Maintenance Charges', 'मासिक रखरखाव शुल्क'),
        'monthly' => context.tr('Monthly (non-maintenance)', 'मासिक (रखरखाव के अलावा)'),
        'quarterly' => context.tr('Quarterly charges', 'त्रैमासिक शुल्क'),
        'yearly' => context.tr('Yearly charges', 'वार्षिक शुल्क'),
        'one-time' => context.tr('One-time charges', 'एक बार के शुल्क'),
        'other' => context.tr('Other / unknown charges', 'अन्य / अज्ञात शुल्क'),
        'corpus' => context.tr('Corpus / sinking (ledger only)', 'कॉर्पस / सिंकिंग (केवल खाता)'),
        'outsider_mixed' => context.tr('Outsider / mixed (ledger only)', 'बाहरी / मिश्रित (केवल खाता)'),
        _ => v,
      };

  String _modeLabel(String v) => switch (v) {
        'all' => context.tr('All recording modes', 'सभी दर्ज विधियाँ'),
        'society_pool' => context.tr('Society pool (undistributed)', 'सोसाइटी पूल (अवितरित)'),
        'flats_only' => context.tr('Flats only', 'केवल फ्लैट'),
        'flats_plus_outsider' => context.tr('Flats + outsider', 'फ्लैट + बाहरी'),
        'outsider_only' => context.tr('Outsider only', 'केवल बाहरी'),
        _ => v,
      };

  String _hint(String filter) => switch (filter) {
        'all_payments' => context.tr(
            'Society payments recorded via Record payment — vendor bills, utilities, repairs split across flats (not event food or maintenance receipts).',
            'भुगतान दर्ज करें से दर्ज सोसाइटी भुगतान — विक्रेता बिल, बिजली-पानी, मरम्मत, फ्लैटों में बँटे (कार्यक्रम भोजन या रखरखाव रसीदें नहीं)।'),
        'all_receipts' => context.tr(
            'Society collections — flat owners, outsiders, monthly/one-time charges; pooled until you distribute to flats.',
            'सोसाइटी संग्रह — फ्लैट मालिक, बाहरी, मासिक/एक बार शुल्क; फ्लैटों में बाँटने तक पूल में।'),
        'all' => context.tr(
            'Society receipts and society-payment rows. Event contribution and food bills appear below as reference only (not in the society ledger).',
            'सोसाइटी रसीदें और सोसाइटी-भुगतान पंक्तियाँ। कार्यक्रम योगदान व भोजन बिल नीचे केवल संदर्भ हेतु (सोसाइटी खाते में नहीं)।'),
        'society_pool_pending' => context.tr('Receipts recorded in the society pool that are not yet split equally across flats.',
            'सोसाइटी पूल में दर्ज रसीदें जो अभी फ्लैटों में बराबर नहीं बाँटी गईं।'),
        _ => context.tr(
            'Filter by charge type or recording mode. Use society pool when recording, then distribute from the receipt row when needed.',
            'शुल्क प्रकार या दर्ज विधि से छाँटें। दर्ज करते समय सोसाइटी पूल चुनें, फिर ज़रूरत पर रसीद पंक्ति से बाँटें।'),
      };

  String _kindLabel(FinanceLedgerRow e) => switch (c.derived.ledgerEntryKind(e)) {
        'pool' => context.tr('Society pool — not yet distributed', 'सोसाइटी पूल — अभी बाँटा नहीं'),
        'ledgerOnly' => context.tr('Ledger-only (no maintenance payment rows)', 'केवल खाता (रखरखाव भुगतान पंक्तियाँ नहीं)'),
        'food' => context.tr('Event food expense', 'कार्यक्रम भोजन व्यय'),
        _ => context.tr('Society payment (split across flats)', 'सोसाइटी भुगतान (फ्लैटों में बँटा)'),
      };

  String _monthLabelOf(List<({String value, String label})> opts) {
    for (final o in opts) {
      if (o.value == f.paymentMonthFilter) return o.value == 'all' ? context.tr('All months', 'सभी माह') : o.label;
    }
    return context.tr('All months', 'सभी माह');
  }

  // Drill-down detail layer for a head-summary row (web `openHeadSummaryEntryDetail`).
  FinReportLayer? _detailLayer(BuildContext context, FinReportRow row) {
    final p = row.payment;
    if (p != null) {
      final ch = c.derived.chargeById[p.chargeId ?? ''];
      FinReportRow r(String id, String label, {String? sub, double? amount}) => FinReportRow(id: id, label: label, sublabel: sub, amount: amount);
      return FinReportLayer(
        title: context.tr('Receipt detail', 'रसीद विवरण'),
        subtitle: 'Flat ${p.flatNumber}',
        total: p.amount,
        rows: [
          r('d-charge', context.tr('Charge', 'शुल्क'), sub: (ch?.title ?? '').isEmpty ? context.fin('fin.unknownCharge') : ch!.title),
          r('d-flat', context.tr('Flat', 'फ्लैट'), sub: p.flatNumber.isEmpty ? '—' : p.flatNumber),
          r('d-resident', context.tr('Resident', 'निवासी'), sub: (p.residentName ?? '').isEmpty ? '—' : p.residentName),
          r('d-amt', context.tr('Amount', 'राशि'), amount: p.amount),
          r('d-type', context.tr('Type', 'प्रकार'), sub: (ch?.frequency ?? '').isEmpty ? '—' : ch!.frequency),
          r('d-method', context.tr('Payment method', 'भुगतान माध्यम'), sub: p.paymentMethod.isEmpty ? '—' : p.paymentMethod),
          r('d-status', context.tr('Status', 'स्थिति'), sub: p.paymentStatus.isEmpty ? '—' : p.paymentStatus),
          r('d-month', context.tr('Payment month', 'भुगतान माह'), sub: paymentMonthLabel(p)),
          r('d-due', context.fin('fin.billingDate'), sub: (p.dueDate ?? '').isEmpty ? '—' : isoDateToDisplay(p.dueDate)),
          r('d-txn', context.tr('Transaction ID', 'लेन-देन आईडी'), sub: (p.transactionId ?? '').isEmpty ? '—' : p.transactionId),
          r('d-notes', context.tr('Notes', 'टिप्पणी'), sub: (p.notes ?? '').isEmpty ? '—' : p.notes),
        ],
      );
    }
    final e = row.entry;
    if (e == null) return null;
    final cp = e.counterparty;
    final rows = <FinReportRow>[
      FinReportRow(id: 'd-title', label: context.tr('Title', 'शीर्षक'), sublabel: (e.title ?? '').isEmpty ? '—' : e.title),
      FinReportRow(id: 'd-mode', label: context.tr('Record mode', 'दर्ज विधि'), sublabel: formatLedgerFieldLabel(e.recordMode)),
      FinReportRow(id: 'd-dest', label: context.tr('Destination', 'गंतव्य'), sublabel: formatLedgerFieldLabel(e.destination)),
      FinReportRow(id: 'd-amt', label: context.tr('Amount', 'राशि'), amount: e.totalAmount),
      if (cp != null)
        FinReportRow(
          id: 'd-from',
          label: context.tr('From', 'से'),
          sublabel: '${cp.name}${(cp.relationToSociety ?? '').isNotEmpty ? ' · ${cp.relationToSociety}' : ''}',
        ),
      FinReportRow(id: 'd-month', label: context.tr('Entry month', 'प्रविष्टि माह'), sublabel: ledgerMonthDisplay(e)),
      FinReportRow(id: 'd-flats', label: context.tr('Flats in entry', 'प्रविष्टि में फ्लैट'), sublabel: '${e.aggregateFlatCount}'),
      FinReportRow(id: 'd-method', label: context.tr('Payment method', 'भुगतान माध्यम'), sublabel: e.paymentMethod.isEmpty ? '—' : e.paymentMethod),
      FinReportRow(id: 'd-txn', label: context.tr('Transaction ID', 'लेन-देन आईडी'), sublabel: (e.transactionId ?? '').isEmpty ? '—' : e.transactionId),
      FinReportRow(id: 'd-status', label: context.tr('Status', 'स्थिति'), sublabel: e.paymentStatus),
      FinReportRow(id: 'd-notes', label: context.tr('Notes', 'टिप्पणी'), sublabel: (e.notes ?? '').isEmpty ? '—' : e.notes),
      for (final a in e.allocations) FinReportRow(id: 'd-alloc-${a.flatNumber}', label: 'Flat ${a.flatNumber}', amount: a.amount),
    ];
    return FinReportLayer(
      title: context.tr('Entry detail', 'प्रविष्टि विवरण'),
      subtitle: (e.title ?? '').isNotEmpty ? e.title : _kindLabel(e),
      total: e.totalAmount,
      rows: rows,
    );
  }

  Future<void> _export(FinExportFormat format, TransactionsView v, String typeLabel, String monthLabel) async {
    if (f.filterStatus == 'unpaid') {
      AppFeedback.toast(context, context.tr('Switch to a transaction status filter to export entries', 'प्रविष्टियाँ निर्यात करने के लिए लेन-देन स्थिति फ़िल्टर चुनें'),
          tone: BadgeTone.alert);
      return;
    }
    final rows = buildTransactionExportRows(items: v.lineItems, chargeTitleById: c.derived.chargeTitleById);
    if (rows.isEmpty) {
      AppFeedback.toast(context, context.tr('No transactions match the current filters', 'वर्तमान फ़िल्टर से कोई लेन-देन नहीं मिला'), tone: BadgeTone.alert);
      return;
    }
    try {
      final file = await buildTransactionStatement(
        format,
        societyName: c.data.societyName.isEmpty ? 'Society' : c.data.societyName,
        title: 'Transaction statement',
        subtitle: _subtitle(v, typeLabel, monthLabel),
        filenameBase: 'transactions-${monthLabel.replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}',
        rows: rows,
      );
      await shareFinanceFile(file);
      if (mounted) AppFeedback.toast(context, '${format.name.toUpperCase()} ${context.tr('ready', 'तैयार')}', tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, context.tr('Could not export', 'निर्यात नहीं हो सका'), tone: BadgeTone.alert);
    }
  }

  String _subtitle(TransactionsView v, String typeLabel, String monthLabel) =>
      '${v.summaryCount} entries · ${inrLocale(v.summarySum)} total · $typeLabel · $monthLabel';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([c, f]),
      builder: (context, _) {
        final t = context.tokens;
        final derived = c.derived;
        final v = TransactionsView.compute(derived, f.query(includeVacant: widget.includeVacantFlats));
        final typeOptions = paymentTypeOptionValues(derived);
        final monthOptions = monthOptionsForReceipts(derived);
        final typeLabel = _typeLabel(typeOptions.contains(f.paymentTypeFilter) ? f.paymentTypeFilter : 'all');
        final monthLabel = _monthLabelOf(monthOptions);
        final unpaid = f.filterStatus == 'unpaid';
        final m = FinMetrics.of(context);
        final societyName = c.data.societyName.isEmpty ? 'Society' : c.data.societyName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinTintBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              child: Text(
                context.tr(
                  'Maintenance and society-payment receipts below. Event contribution and food bills are listed at the bottom for reference only — they are recorded under Events & food and do not affect the society ledger.',
                  'नीचे रखरखाव और सोसाइटी-भुगतान रसीदें हैं। कार्यक्रम योगदान व भोजन बिल केवल संदर्भ हेतु सबसे नीचे हैं — वे कार्यक्रम व भोजन में दर्ज होते हैं और सोसाइटी खाते को प्रभावित नहीं करते।',
                ),
                style: AppText.tiny(context).copyWith(fontSize: 11, height: 1.35),
              ),
            ),
            TextField(
              controller: f.search,
              onChanged: (_) => f.changed(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
                hintText: context.tr('Search by flat, member name, charge, txn, notes...', 'फ्लैट, सदस्य, शुल्क, लेन-देन, टिप्पणी से खोजें...'),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in [
                    ('all', context.tr('ALL', 'सभी')),
                    ('pending', context.tr('VERIFICATION PENDING', 'सत्यापन लंबित')),
                    ('verified', context.tr('VERIFIED', 'सत्यापित')),
                    ('rejected', context.tr('REJECTED', 'अस्वीकृत')),
                    ('unpaid', context.tr('FLATS UNPAID', 'अदत्त फ्लैट')),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: PillChoice(
                        label: s.$2,
                        selected: f.filterStatus == s.$1,
                        onTap: () => f
                          ..filterStatus = s.$1
                          ..changed(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CardSection(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinMicroLabel(context.tr('Transaction filters', 'लेन-देन फ़िल्टर')),
                  AppDropdown<String>(
                    items: typeOptions,
                    value: typeOptions.contains(f.paymentTypeFilter) ? f.paymentTypeFilter : 'all',
                    labelOf: _typeLabel,
                    onChanged: (val) => f
                      ..paymentTypeFilter = val ?? 'all'
                      ..paymentMonthFilter = 'all'
                      ..changed(),
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String>(
                    items: [for (final o in monthOptions) o.value],
                    value: monthOptions.any((o) => o.value == f.paymentMonthFilter) ? f.paymentMonthFilter : 'all',
                    labelOf: (val) => val == 'all'
                        ? context.tr('All months', 'सभी माह')
                        : monthOptions.firstWhere((o) => o.value == val, orElse: () => (value: val, label: val)).label,
                    onChanged: (val) => f
                      ..paymentMonthFilter = val ?? 'all'
                      ..changed(),
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String>(
                    items: const ['all', 'society_pool', 'flats_only', 'flats_plus_outsider', 'outsider_only'],
                    value: f.receiptModeFilter,
                    labelOf: _modeLabel,
                    onChanged: (val) => f
                      ..receiptModeFilter = val ?? 'all'
                      ..changed(),
                  ),
                  FinHint(_hint(f.paymentTypeFilter)),
                ],
              ),
            ),
            if (unpaid)
              FinSummaryLine(
                label: context.tr(
                  '${v.unpaidRows.length} unpaid flats · Type: $typeLabel · Month: $monthLabel',
                  '${v.unpaidRows.length} अदत्त फ्लैट · प्रकार: $typeLabel · माह: $monthLabel',
                ),
                description: context.tr('Flats that have not paid for the filters you selected (verified payments only).',
                    'चुने फ़िल्टर के लिए जिन फ्लैटों ने भुगतान नहीं किया (केवल सत्यापित भुगतान)।'),
                howCalculated: context.tr('Target flats minus flats with at least one verified payment matching charge/type/month filters.',
                    'लक्षित फ्लैट घटा वे फ्लैट जिनका शुल्क/प्रकार/माह फ़िल्टर से मेल खाता कम से कम एक सत्यापित भुगतान है।'),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FinSummaryLine(
                      label: context.tr(
                        '${v.summaryCount} entries · ${inrLocale(v.summarySum)} total · ${v.summaryFlatCount} flat(s) · Type: $typeLabel · Mode: ${f.receiptModeFilter == 'all' ? 'All' : f.receiptModeFilter.replaceAll('_', ' ')} · Month: $monthLabel',
                        '${v.summaryCount} प्रविष्टियाँ · कुल ${inrLocale(v.summarySum)} · ${v.summaryFlatCount} फ्लैट · प्रकार: $typeLabel · विधि: ${f.receiptModeFilter == 'all' ? 'सभी' : f.receiptModeFilter.replaceAll('_', ' ')} · माह: $monthLabel',
                      ),
                      description: m.transactionListTotal.$2,
                      howCalculated: m.transactionListTotal.$3,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FinExportMenuButton(label: context.fin('fin.exportStatement'), onExport: (fmt) => _export(fmt, v, typeLabel, monthLabel)),
                  if (v.lineItems.isNotEmpty)
                    FinShareButton(
                      label: context.fin('fin.shareWhatsApp'),
                      onShare: () async {
                        final rows = buildTransactionExportRows(items: v.lineItems, chargeTitleById: derived.chargeTitleById);
                        final bytes = await buildTransactionStatementPdf(
                          societyName: societyName,
                          title: 'Transaction statement',
                          subtitle: _subtitle(v, typeLabel, monthLabel),
                          rows: rows,
                        );
                        await ExportKit.sharePdf(bytes, 'transactions-${monthLabel.replaceAll(RegExp(r'\s+'), '-')}.pdf',
                            text: '$societyName — Transaction statement ($monthLabel)');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (!unpaid && v.receiptHeadSummary.isNotEmpty)
              _HeadSummaryCard(
                title: context.tr('Society receipts — head-wise summary', 'सोसाइटी रसीदें — शीर्ष-वार सारांश'),
                hint: context.tr(
                  'Grouped by major head from receipt type. Respects current status, type, month, and mode filters. Tap a row to view entries.',
                  'रसीद प्रकार के मुख्य शीर्ष अनुसार समूहित। वर्तमान स्थिति, प्रकार, माह और विधि फ़िल्टर लागू। प्रविष्टियाँ देखने के लिए पंक्ति टैप करें।',
                ),
                headLabel: context.tr('Head', 'शीर्ष'),
                rows: v.receiptHeadSummary,
                totals: v.receiptChannelTotals,
                footerLabel: context.t('finance.allReceiptHeads'),
                totalCopy: m.transactionReceiptHeadGrandTotal,
                rowCopy: m.rowTotal,
                totalColor: t.success,
                onTap: (row) => showFinReportSheet(
                  context,
                  societyName: societyName,
                  initial: FinReportLayer(
                    title: row.head,
                    subtitle: '$typeLabel · $monthLabel',
                    total: row.total,
                    rows: v.receiptHeadEntryRows(row.head),
                    drillable: true,
                  ),
                  onDrill: _detailLayer,
                ),
              ),
            if (!unpaid && v.paymentHeadSummary.isNotEmpty)
              _HeadSummaryCard(
                title: context.tr('Society payments — head-wise summary', 'सोसाइटी भुगतान — शीर्ष-वार सारांश'),
                hint: context.tr(
                  'Grouped by expense head from Record payment. Respects current status, type, month, and mode filters. Tap a row to view entries.',
                  'भुगतान दर्ज करें के व्यय शीर्ष अनुसार समूहित। वर्तमान स्थिति, प्रकार, माह और विधि फ़िल्टर लागू। प्रविष्टियाँ देखने के लिए पंक्ति टैप करें।',
                ),
                headLabel: context.tr('Expense head', 'व्यय शीर्ष'),
                rows: v.paymentHeadSummary,
                totals: v.paymentChannelTotals,
                footerLabel: context.tr('All payment heads', 'सभी भुगतान शीर्ष'),
                totalCopy: m.transactionPaymentHeadGrandTotal,
                rowCopy: m.periodExpenseHead,
                totalColor: t.warning,
                onTap: (row) => showFinReportSheet(
                  context,
                  societyName: societyName,
                  initial: FinReportLayer(
                    title: row.head,
                    subtitle: 'Society payment · $typeLabel · $monthLabel',
                    total: row.total,
                    rows: v.paymentHeadEntryRows(row.head),
                    drillable: true,
                  ),
                  onDrill: _detailLayer,
                ),
              ),
            if (!unpaid)
              CardSection(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FinMiniButton(
                      label: context.tr('Select visible', 'दिखने वाले चुनें'),
                      onTap: () => f
                        ..selectedKeys.addAll(v.lineItems.map((i) => i.key))
                        ..changed(),
                    ),
                    FinMiniButton(
                      label: context.tr('Clear', 'साफ़ करें'),
                      onTap: () => f
                        ..selectedKeys.clear()
                        ..changed(),
                    ),
                    if (f.selectedKeys.isNotEmpty) ...[
                      Text(context.tr('${f.selectedKeys.length} selected', '${f.selectedKeys.length} चयनित'), style: AppText.tiny(context)),
                      FinMiniButton(
                        label: context.tr('Delete selected', 'चयनित हटाएँ'),
                        color: t.destructive,
                        onTap: () async {
                          final ok = await actions.bulkDelete(context, {...f.selectedKeys});
                          if (ok) {
                            f
                              ..selectedKeys.clear()
                              ..changed();
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (s) async {
                          final ok = await actions.bulkStatus(context, {...f.selectedKeys}, s);
                          if (ok) {
                            f
                              ..selectedKeys.clear()
                              ..changed();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'pending', child: Text(context.tr('Set pending', 'लंबित करें'))),
                          PopupMenuItem(value: 'verified', child: Text(context.tr('Set verified', 'सत्यापित करें'))),
                          PopupMenuItem(value: 'rejected', child: Text(context.tr('Set rejected', 'अस्वीकृत करें'))),
                        ],
                        child: FinMiniButton(
                          label: context.tr('Bulk status (payment rows only)…', 'बल्क स्थिति (केवल भुगतान पंक्तियाँ)…'),
                          icon: Icons.arrow_drop_down,
                          onTap: null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (unpaid)
              UnpaidFlatGridTable(rows: v.unpaidRows, emptyMessage: context.tr('No unpaid flats for selected filters', 'चुने फ़िल्टर में कोई अदत्त फ्लैट नहीं'))
            else if (v.lineItems.isEmpty)
              EmptyView(message: context.tr('No transactions match the current filters', 'वर्तमान फ़िल्टर से कोई लेन-देन नहीं मिला'))
            else
              for (final item in v.lineItems)
                item.payment != null ? _paymentCard(context, item.payment!) : _ledgerCard(context, item.entry!),
            _EventReferenceSection(c: c),
          ],
        );
      },
    );
  }

  Widget _check(String key) => SizedBox(
        width: 28,
        height: 28,
        child: Checkbox(
          value: f.selectedKeys.contains(key),
          onChanged: (v) {
            if (v == true) {
              f.selectedKeys.add(key);
            } else {
              f.selectedKeys.remove(key);
            }
            f.changed();
          },
        ),
      );

  Widget _paymentCard(BuildContext context, FinancePayment p) {
    final t = context.tokens;
    final ch = c.derived.chargeById[p.chargeId ?? ''];
    final fe = (p.financeEntryId ?? '').isNotEmpty ? c.derived.financeEntryById[p.financeEntryId] : null;
    final sub = [if ((p.residentName ?? '').isNotEmpty) p.residentName!, if (p.paymentMethod.isNotEmpty) p.paymentMethod.toUpperCase()].join(' · ');
    final statusColor = switch (p.paymentStatus) {
      'verified' => t.success,
      'rejected' => t.destructive,
      _ => t.warning,
    };
    return CardSection(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _check('mp-${p.id}'),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => showPaymentDetailSheet(context, c, p),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${(ch?.title ?? '').isEmpty ? context.fin('fin.unknownCharge') : ch!.title} · ${paymentMonthLabel(p)}',
                                style: AppText.tiny(context).copyWith(fontSize: 11)),
                            if (fe != null)
                              Text('Mode: ${formatLedgerFieldLabel(fe.recordMode)}', style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                            Text('${context.tr('Flat', 'फ्लैट')} ${p.flatNumber}', style: AppText.sectionTitle(context)),
                            if (sub.isNotEmpty) Text(sub, style: AppText.caption(context)),
                            if ((p.transactionId ?? '').isNotEmpty)
                              Text('TXN: ${p.transactionId}', style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                            if ((p.receiptNumber ?? '').isNotEmpty)
                              Text('${context.tr('Receipt', 'रसीद')}: ${p.receiptNumber}', style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                            if ((p.rejectionReason ?? '').isNotEmpty)
                              Text('${context.tr('Reason', 'कारण')}: ${p.rejectionReason}', style: TextStyle(fontSize: 10, color: t.destructive)),
                            Text(fmtDateLocal(p.createdAt), style: AppText.tiny(context)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inrRaw(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTokens.tint(statusColor, 0.2), borderRadius: BorderRadius.circular(99)),
                            child: Text(context.finStatus(p.paymentStatus), style: TextStyle(fontSize: 10, color: statusColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (p.paymentStatus == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.success,
                      dense: true,
                      icon: Icons.check,
                      label: context.fin('fin.verify'),
                      onPressed: () => actions.verify(context, p),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton.destructive(
                      dense: true,
                      icon: Icons.close,
                      label: context.fin('fin.reject'),
                      onPressed: () => actions.reject(context, p),
                    ),
                  ),
                ],
              ),
            ),
          if ((p.screenshotUrl ?? '').isNotEmpty)
            InkWell(
              onTap: () => ExportKit.openUrl(p.screenshotUrl!),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(context.tr('View Screenshot', 'स्क्रीनशॉट देखें'),
                    style: TextStyle(fontSize: 12, color: t.primary, decoration: TextDecoration.underline)),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FinMiniButton(label: context.fin('fin.edit'), icon: Icons.edit_outlined, onTap: () => showPaymentEditSheet(context, c, p)),
                FinInlineSelect<String>(
                  value: ['pending', 'verified', 'rejected'].contains(p.paymentStatus) ? p.paymentStatus : 'pending',
                  items: const ['pending', 'verified', 'rejected'],
                  labelOf: context.finStatus,
                  onChanged: (s) => actions.changeStatus(context, p, s),
                ),
                FinMiniButton(
                  label: context.fin('fin.delete'),
                  icon: Icons.delete_outline,
                  color: t.destructive,
                  onTap: () async {
                    if (await actions.deletePayment(context, p)) {
                      f
                        ..selectedKeys.remove('mp-${p.id}')
                        ..changed();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerCard(BuildContext context, FinanceLedgerRow e) {
    final t = context.tokens;
    final cp = e.counterparty;
    final pool = isLedgerInSocietyPool(e);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border(left: BorderSide(color: AppTokens.tint(t.primary, 0.4), width: 4)),
      ),
      child: CardSection(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _check('ledger-${e.id}'),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => showLedgerDetailSheet(context, c, e),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${ledgerMonthDisplay(e)} · ${_kindLabel(e)}', style: AppText.tiny(context).copyWith(fontSize: 11)),
                              Text((e.title ?? '').isEmpty ? context.tr('Finance entry', 'वित्त प्रविष्टि') : e.title!,
                                  style: AppText.sectionTitle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${formatLedgerFieldLabel(e.recordMode)} · ${formatLedgerFieldLabel(e.destination)}', style: AppText.tiny(context)),
                              if (cp != null)
                                Text(
                                  '${context.tr('From', 'से')}: ${cp.name}${(cp.relationToSociety ?? '').isNotEmpty ? ' · ${cp.relationToSociety}' : ''}',
                                  style: AppText.caption(context),
                                ),
                              Text(fmtDateTimeFullLocal(e.createdAt), style: AppText.tiny(context)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(inrRaw(e.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppTokens.tint(t.success, 0.2), borderRadius: BorderRadius.circular(99)),
                              child: Text(context.finStatus(e.paymentStatus), style: TextStyle(fontSize: 10, color: t.success)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (pool)
                    FinMiniButton(
                      filled: true,
                      icon: Icons.groups_outlined,
                      label: f.distributingEntryId == e.id ? context.fin('fin.distributing') : context.fin('fin.distribute'),
                      onTap: f.distributingEntryId == e.id
                          ? null
                          : () async {
                              f
                                ..distributingEntryId = e.id
                                ..changed();
                              await actions.distribute(context, e);
                              f
                                ..distributingEntryId = null
                                ..changed();
                            },
                    ),
                  FinMiniButton(label: context.fin('fin.edit'), icon: Icons.edit_outlined, onTap: () => showLedgerEditSheet(context, c, e)),
                  FinInlineSelect<String>(
                    value: e.paymentStatus == 'pending' ? 'pending' : 'verified',
                    items: const ['verified', 'pending'],
                    labelOf: context.finStatus,
                    onChanged: (s) => actions.setLedgerStatus(context, e, s),
                  ),
                  FinMiniButton(
                    label: context.fin('fin.delete'),
                    icon: Icons.delete_outline,
                    color: t.destructive,
                    onTap: () async {
                      if (await actions.deleteLedger(context, e)) {
                        f
                          ..selectedKeys.remove('ledger-${e.id}')
                          ..changed();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadSummaryCard extends StatelessWidget {
  const _HeadSummaryCard({
    required this.title,
    required this.hint,
    required this.headLabel,
    required this.rows,
    required this.totals,
    required this.footerLabel,
    required this.totalCopy,
    required this.rowCopy,
    required this.totalColor,
    required this.onTap,
  });

  final String title;
  final String hint;
  final String headLabel;
  final List<TransactionHeadSummaryRow> rows;
  final ChannelTotals totals;
  final String footerLabel;
  final FinCopy totalCopy;
  final FinCopy rowCopy;
  final Color totalColor;
  final ValueChanged<TransactionHeadSummaryRow> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = FinMetrics.of(context);
    final mono = AppText.mono(context, size: 10);
    Widget money(String title, FinCopy copy, double v, {Color? color, bool bold = false}) => FinInfoValue(
          title: title,
          value: inrLocale(v),
          description: copy.$2,
          howCalculated: copy.$3,
          color: color,
          style: AppText.mono(context, size: 10, weight: bold ? FontWeight.w700 : FontWeight.w400),
        );
    final grand = rows.fold<double>(0, (s, r) => s + r.total);
    return CardSection(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinMicroLabel(title),
          FinHint(hint, padding: const EdgeInsets.only(bottom: 8)),
          FinTable(
            columns: [
              FinCol(headLabel, width: 150),
              FinCol(context.fin('fin.entries'), width: 56, right: true),
              FinCol(context.fin('fin.cash'), width: 84, right: true),
              FinCol(context.fin('fin.bankUpi'), width: 84, right: true),
              FinCol(context.fin('fin.other'), width: 72, right: true),
              FinCol(context.fin('fin.total'), width: 92, right: true),
              const FinCol('', width: 28),
            ],
            onRowTap: (i) => onTap(rows[i]),
            rows: [
              for (final r in rows)
                [
                  finCell(context, r.head, maxLines: 1),
                  Text('${r.entries}', style: mono),
                  money('${r.head} — cash', m.channelCash, r.byChannel.cash),
                  money('${r.head} — bank / UPI', m.channelBank, r.byChannel.bank),
                  money('${r.head} — other', m.channelOther, r.byChannel.other),
                  money('${r.head} — total', rowCopy, r.total, color: totalColor, bold: true),
                  Icon(Icons.chevron_right, size: 14, color: t.mutedForeground),
                ],
            ],
            footer: [
              finCell(context, footerLabel, bold: true, maxLines: 1),
              Text('${rows.fold<int>(0, (s, r) => s + r.entries)}', style: mono.copyWith(fontWeight: FontWeight.w700)),
              money('$footerLabel — cash', m.channelCash, totals.cash, bold: true),
              money('$footerLabel — bank / UPI', m.channelBank, totals.bank, bold: true),
              money('$footerLabel — other', m.channelOther, totals.other, bold: true),
              money(totalCopy.$1, totalCopy, grand, color: totalColor, bold: true),
              const SizedBox(),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Events & food — reference only" (read-only contribution receipts and food bills).
class _EventReferenceSection extends StatelessWidget {
  const _EventReferenceSection({required this.c});

  final FinanceController c;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ref = c.eventRef;
    Widget emptyBox(String msg) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Text(msg, textAlign: TextAlign.center, style: AppText.caption(context)),
        );
    Widget link(String label, String url) => InkWell(
          onTap: () => ExportKit.openUrl(url),
          child: Text(label, style: TextStyle(fontSize: 10, color: t.primary, decoration: TextDecoration.underline)),
        );
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(context.tr('Events & food — reference only', 'कार्यक्रम व भोजन — केवल संदर्भ'), icon: Icons.event_outlined, iconColor: t.accent),
          FinHint(
            context.tr(
              'Read-only view of contribution receipts and food bills. Edit or add these under Events & food — not linked to finance_entries.',
              'योगदान रसीदों और भोजन बिलों का केवल-पठन दृश्य। इन्हें कार्यक्रम व भोजन में जोड़ें/संपादित करें — finance_entries से नहीं जुड़े।',
            ),
            padding: const EdgeInsets.only(bottom: 12),
          ),
          if (c.eventRefLoading && ref == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.tr('Loading event receipts…', 'कार्यक्रम रसीदें लोड हो रही हैं…'),
                  textAlign: TextAlign.center, style: AppText.caption(context)),
            )
          else ...[
            if (ref != null && (ref.contributions.isNotEmpty || ref.foodExpenses.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CashBankBreakdown(
                  receipts: sumByChannel<EventContribRefRow>(ref.contributions, (x) => x.amount, (x) => x.paymentMethod),
                  payments: sumByChannel<EventFoodRefRow>(ref.foodExpenses, (x) => x.totalAmount, (x) => x.paymentMethod),
                  receiptLabel: context.tr('Event contributions', 'कार्यक्रम योगदान'),
                  paymentLabel: context.tr('Food bills', 'भोजन बिल'),
                ),
              ),
            FinMicroLabel(context.tr('Contribution receipts', 'योगदान रसीदें')),
            if (ref == null || ref.contributions.isEmpty)
              emptyBox(context.tr('No event contribution receipts yet', 'अभी कोई कार्यक्रम योगदान रसीद नहीं'))
            else
              for (final x in ref.contributions)
                CardSection(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x.eventTitle, style: AppText.tiny(context)),
                            Text(eventContribRefLabel(x), style: AppText.bodyMedium(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${x.receiptBasis == 'non_flat' ? context.tr('Without flat', 'बिना फ्लैट') : context.tr('Flat-wise', 'फ्लैट-वार')}'
                                  '${(x.splitMode ?? '').isNotEmpty ? ' · ${x.splitMode!.replaceAll('_', ' ')}' : ''}',
                                  style: AppText.tiny(context),
                                ),
                                FinChannelBadge(method: x.paymentMethod),
                                if ((x.verifiedAt ?? '').isNotEmpty) Text('· ${fmtDateLocal(x.verifiedAt)}', style: AppText.tiny(context)),
                              ],
                            ),
                            if ((x.screenshotUrl ?? '').isNotEmpty) link(context.tr('View proof', 'प्रमाण देखें'), x.screenshotUrl!),
                          ],
                        ),
                      ),
                      Text(inrLocale(x.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            const SizedBox(height: 16),
            SectionTitle(context.tr('Food / catering bills', 'भोजन / कैटरिंग बिल'), icon: Icons.restaurant_outlined, iconColor: t.mutedForeground),
            if (ref == null || ref.foodExpenses.isEmpty)
              emptyBox(context.tr('No food expense bills yet', 'अभी कोई भोजन व्यय बिल नहीं'))
            else
              for (final x in ref.foodExpenses)
                CardSection(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((x.eventTitle ?? '').isNotEmpty ? x.eventTitle! : x.groupName, style: AppText.tiny(context)),
                            Text(x.title, style: AppText.bodyMedium(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [Text(isoDateToDisplay(x.expenseDate), style: AppText.tiny(context)), FinChannelBadge(method: x.paymentMethod)],
                            ),
                            if ((x.billScreenshotUrl ?? '').isNotEmpty) link(context.tr('View bill', 'बिल देखें'), x.billScreenshotUrl!),
                          ],
                        ),
                      ),
                      Text(inrLocale(x.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
