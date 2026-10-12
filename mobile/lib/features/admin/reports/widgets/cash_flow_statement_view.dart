import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/cash_flow_statement.dart';
import '../logic/finance_period_report.dart';
import '../logic/metric_copy.dart';
import '../logic/report_formatters.dart';
import 'report_detail_sheet.dart';
import 'report_ui.dart';

/// Port of `src/components/CashFlowStatement.tsx`.
class CashFlowStatementView extends StatelessWidget {
  const CashFlowStatementView({
    super.key,
    required this.periodFrom,
    required this.periodTo,
    this.periodLabel,
    this.societyName,
    this.loading = false,
    required this.payments,
    required this.societyLedgerEntries,
    required this.expenseCategoryById,
    required this.reserveTransfers,
    this.openingBalanceAnchors = const [],
  });

  final String periodFrom;
  final String periodTo;
  final String? periodLabel;
  final String? societyName;
  final bool loading;
  final List<FinancePeriodPayment> payments;
  final List<FinancePeriodLedgerEntry> societyLedgerEntries;
  final Map<String, String> expenseCategoryById;
  final List<FinancePeriodReserveTransfer> reserveTransfers;
  final List<FinanceOpeningBalanceAnchor> openingBalanceAnchors;

  String get _displayPeriod => periodLabel ?? '${fmtIsoDateToDisplay(periodFrom)} – ${fmtIsoDateToDisplay(periodTo)}';

  ReportDetailRow _entryRow(StatementEntry e) => ReportDetailRow(
        id: e.id,
        label: e.label,
        sublabel: e.sublabel,
        amount: e.amount,
        date: fmtDate(e.date),
        dateIso: e.date,
        status: e.type.name,
        extra: e.runningBalance != null ? 'Bal: ${rupees(e.runningBalance!)}' : null,
        meta: e,
      );

  ReportDetailLayer? _entryDetail(BuildContext context, ReportDetailRow row) {
    final entry = row.meta;
    if (entry is! StatementEntry) return null;
    String dash(String? s) => (s == null || s.isEmpty) ? '—' : s;
    return ReportDetailLayer(
      title: context.tr('Entry detail', 'प्रविष्टि विवरण'),
      subtitle: entry.label,
      totalAmount: entry.amount,
      rows: [
        ReportDetailRow(id: 'd-source', label: context.tr('Source', 'स्रोत'), sublabel: entry.source?.name ?? '—'),
        ReportDetailRow(id: 'd-dest', label: context.tr('Destination', 'गंतव्य'), sublabel: entry.destination?.replaceAll('_', ' ') ?? '—'),
        ReportDetailRow(id: 'd-amt', label: context.tr('Amount', 'राशि'), amount: entry.amount),
        ReportDetailRow(id: 'd-method', label: context.tr('Payment method', 'भुगतान विधि'), sublabel: entry.paymentMethod ?? '—'),
        ReportDetailRow(id: 'd-txn', label: context.tr('Transaction ID', 'लेनदेन आईडी'), sublabel: dash(entry.transactionId)),
        ReportDetailRow(id: 'd-date', label: context.tr('Date', 'तारीख'), sublabel: fmtDate(entry.date)),
        if (entry.aggregateFlatCount != null)
          ReportDetailRow(
            id: 'd-flats',
            label: context.tr('Flats in entry', 'प्रविष्टि में फ्लैट'),
            sublabel: statementNumber(entry.aggregateFlatCount!),
          ),
        ReportDetailRow(id: 'd-notes', label: context.tr('Notes', 'टिप्पणियाँ'), sublabel: dash(entry.notes)),
      ],
    );
  }

  ReportDetailLayer _list(BuildContext context, String title, String subtitle, List<StatementEntry> entries) => ReportDetailLayer(
        title: title,
        subtitle: subtitle,
        totalAmount: entries.fold<double>(0, (s, e) => s + e.amount),
        rows: entries.map(_entryRow).toList(),
        onRowTap: (row) => _entryDetail(context, row),
      );

  void _openStatement(BuildContext context, CashFlowResult cfs, PaymentChannel ch) {
    final entries = filterStatementByChannel(cfs.statementEntries, ch);
    final withBal = addRunningBalance(entries, ch == PaymentChannel.cash ? cfs.opening.cash : cfs.opening.bank);
    final layer = ReportDetailLayer(
      title: ch == PaymentChannel.cash ? context.tr('Cash Statement', 'नकद विवरण') : context.tr('Bank Statement', 'बैंक विवरण'),
      subtitle: ch == PaymentChannel.cash
          ? '${context.tr('Chronological cash transactions', 'क्रमवार नकद लेनदेन')} — $_displayPeriod'
          : '${context.tr('Chronological bank / UPI transactions', 'क्रमवार बैंक / यूपीआई लेनदेन')} — $_displayPeriod',
      totalAmount: entries.fold<double>(0, (s, e) => s + e.amount),
      rows: withBal.map(_entryRow).toList(),
      onRowTap: (row) => _entryDetail(context, row),
    );
    ReportDetailSheet.show(context, layer, societyName: societyName);
  }

  void _drill(BuildContext context, CashFlowResult cfs, CashFlowLine line) {
    if (!line.drillable || line.drillKind == null) return;
    switch (line.drillKind!) {
      case CashFlowDrillKind.cashStatement:
        _openStatement(context, cfs, PaymentChannel.cash);
        return;
      case CashFlowDrillKind.bankStatement:
        _openStatement(context, cfs, PaymentChannel.bank);
        return;
      case CashFlowDrillKind.reserve:
        final out = line.drillKey == 'out';
        final filtered = cfs.statementEntries
            .where((e) => e.type == StatementEntryType.reserve && (out ? e.amount < 0 : e.amount >= 0))
            .toList();
        ReportDetailSheet.show(
          context,
          _list(
            context,
            out ? context.tr('Reserve transfers (out)', 'रिज़र्व हस्तांतरण (बाहर)') : context.tr('Reserve draw (in)', 'रिज़र्व निकासी (अंदर)'),
            _displayPeriod,
            filtered,
          ),
          societyName: societyName,
        );
        return;
      default:
        final filtered = filterStatementEntriesForDrill(cfs.statementEntries, line.drillKind!, line.drillKey);
        final title = line.drillKind == CashFlowDrillKind.corpus
            ? context.tr('Corpus receipts', 'कोष रसीदें')
            : line.drillKind == CashFlowDrillKind.expenseHead
                ? '${context.tr('Payments', 'भुगतान')} — ${line.drillKey}'
                : context.tr('Collections — Detail', 'संग्रह — विवरण');
        ReportDetailSheet.show(context, _list(context, title, _displayPeriod, filtered), societyName: societyName);
    }
  }

  String _lineLabel(BuildContext context, CashFlowLine line) {
    if (!isHindi(context)) return line.label;
    const hi = {
      'sec-op': 'परिचालन गतिविधियाँ',
      'op-receipts': 'सदस्यों से संग्रह (सत्यापित रसीदें)',
      'op-ledger-extra': 'केवल खाता-बही आवक (रसीदों से न जुड़ी)',
      'op-corpus': 'कोष निधि रसीदें',
      'op-net': 'परिचालन गतिविधियों से शुद्ध नकद',
      'sec-inv': 'निवेश गतिविधियाँ',
      'inv-reserve': 'रिज़र्व निधि हस्तांतरण (बाहर)',
      'inv-net': 'निवेश गतिविधियों से शुद्ध नकद',
      'sec-fin': 'वित्तपोषण गतिविधियाँ',
      'fin-reserve': 'परिचालन हेतु रिज़र्व निकासी',
      'fin-net': 'वित्तपोषण गतिविधियों से शुद्ध नकद',
      'net-change': 'नकद व बैंक में शुद्ध वृद्धि / (कमी)',
      'open-cash': 'प्रारंभिक — हाथ में नकद',
      'open-bank': 'प्रारंभिक — बैंक में शेष',
      'close-cash': 'समापन — हाथ में नकद',
      'close-bank': 'समापन — बैंक में शेष',
    };
    if (line.id.startsWith('op-exp-')) return 'भुगतान — ${line.drillKey}';
    return hi[line.id] ?? line.label;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final invalid = periodFrom.compareTo(periodTo) > 0;
    final cfs = invalid
        ? null
        : computeCashFlowStatement(
            periodFrom: periodFrom,
            periodTo: periodTo,
            payments: payments,
            ledgerEntries: societyLedgerEntries,
            reserveTransfers: reserveTransfers,
            expenseCategoryById: expenseCategoryById,
            openingBalanceAnchors: openingBalanceAnchors,
          );

    Widget stmtButton(String label, IconData icon, Color color, PaymentChannel ch) => Material(
          color: AppTokens.tint(color, 0.15),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: cfs == null ? null : () => _openStatement(context, cfs, ch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        );

    Color amountColor(double v) => v < 0 ? t.destructive : (v > 0 ? t.foreground : t.mutedForeground);

    IconData? sectionIcon(CashFlowSection s) => switch (s) {
          CashFlowSection.operating => Icons.trending_up,
          CashFlowSection.investing => Icons.apartment_outlined,
          CashFlowSection.financing => Icons.south_west,
          CashFlowSection.summary => null,
        };
    Color sectionColor(CashFlowSection s) => switch (s) {
          CashFlowSection.operating => t.success,
          CashFlowSection.investing => t.primary,
          CashFlowSection.financing => t.accent,
          CashFlowSection.summary => t.mutedForeground,
        };

    Widget lineRow(CashFlowLine line) {
      if (line.isSeparator) return const SizedBox(height: 8);
      final label = Row(
        children: [
          if (line.indent) const SizedBox(width: 16),
          if (line.isSectionHeader && sectionIcon(line.section) != null) ...[
            Icon(sectionIcon(line.section), size: 14, color: sectionColor(line.section)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              _lineLabel(context, line),
              style: AppText.body(context).copyWith(fontSize: 12, fontWeight: line.bold ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          if (line.drillable) Icon(Icons.chevron_right, size: 14, color: t.mutedForeground),
        ],
      );
      final row = Container(
        decoration: BoxDecoration(
          color: line.bold && !line.drillable ? AppTokens.tint(t.muted, 0.3) : null,
          border: Border(bottom: BorderSide(color: AppTokens.tint(t.border, 0.4))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 8),
            Text(
              fmtCashFlowAmount(line.amount),
              style: AppText.mono(context, size: 12, weight: line.bold ? FontWeight.w600 : FontWeight.w400, color: amountColor(line.amount)),
            ),
          ],
        ),
      );
      if (!line.drillable) return row;
      return InkWell(onTap: () => _drill(context, cfs!, line), child: row);
    }

    return CardSection(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppTokens.tint(t.muted, 0.3),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Cash Flow Statement', 'नकदी प्रवाह विवरण'), style: AppText.sectionTitle(context)),
                      Text('$_displayPeriod · ${context.tr('Synced with Reports → Financial', 'प्रतिवेदन → वित्तीय से समन्वित')}',
                          style: AppText.tiny(context)),
                    ],
                  ),
                ),
                stmtButton(context.tr('Cash Stmt', 'नकद विवरण'), Icons.payments_outlined, t.success, PaymentChannel.cash),
                const SizedBox(width: 6),
                stmtButton(context.tr('Bank Stmt', 'बैंक विवरण'), Icons.account_balance_outlined, t.primary, PaymentChannel.bank),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          if (invalid)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr('End date must be on or after start date.', 'अंतिम तारीख प्रारंभ तारीख के बराबर या बाद की होनी चाहिए।'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.destructive),
              ),
            )
          else if (loading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('Loading cash flow data…', 'नकदी प्रवाह डेटा लोड हो रहा है…'),
                  textAlign: TextAlign.center, style: AppText.caption(context)),
            )
          else if (cfs != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(children: [
                Expanded(child: Text(context.tr('Particulars', 'विवरण'), style: AppText.caption(context))),
                Text(context.tr('Amount (₹)', 'राशि (₹)'), style: AppText.caption(context)),
              ]),
            ),
            for (final line in cfs.lines) lineRow(line),
            Container(
              color: AppTokens.tint(t.primary, 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text(context.tr('Closing cash + bank', 'समापन नकद + बैंक'),
                      style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                InfoValue(
                  value: rupees(cfs.closing.cash + cfs.closing.bank),
                  metric: ReportMetrics.closingBalance,
                  style: AppText.mono(context, size: 12, weight: FontWeight.w700, color: t.primary),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: StatGrid(
                spacing: 8,
                children: [
                  _miniTile(context, Icons.north_east, t.success, context.tr('Closing cash', 'समापन नकद'),
                      rupees(cfs.closing.cash), onTap: () => _openStatement(context, cfs, PaymentChannel.cash)),
                  _miniTile(context, Icons.account_balance_outlined, t.primary, context.tr('Closing bank', 'समापन बैंक'),
                      rupees(cfs.closing.bank), onTap: () => _openStatement(context, cfs, PaymentChannel.bank)),
                  _miniInfo(context, context.tr('Period net (cash)', 'अवधि नेट (नकद)'), rupees(cfs.periodReport.cashInHand),
                      ReportMetrics.cashInHand),
                  _miniInfo(context, context.tr('Period net (bank)', 'अवधि नेट (बैंक)'), rupees(cfs.periodReport.cashInBank),
                      ReportMetrics.cashInBank),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniTile(BuildContext context, IconData icon, Color color, String label, String value, {required VoidCallback onTap}) {
    return Material(
      color: AppTokens.tint(color, 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        side: BorderSide(color: AppTokens.tint(color, 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: AppText.tiny(context))),
            ]),
            Text(value, style: AppText.mono(context, size: 12, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _miniInfo(BuildContext context, String label, String value, MetricCopy metric) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.background, 0.6),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: t.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.tiny(context)),
        InfoValue(value: value, metric: metric, style: AppText.mono(context, size: 12, weight: FontWeight.w600)),
      ]),
    );
  }
}
