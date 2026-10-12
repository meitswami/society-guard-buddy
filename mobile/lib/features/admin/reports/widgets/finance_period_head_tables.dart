import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/finance_period_report.dart';
import '../logic/metric_copy.dart';
import '../logic/report_formatters.dart';
import 'report_ui.dart';

enum FinancePeriodHeadSection { receipts, expenses, all }

/// Port of `FinancePeriodHeadTables` — head-wise receipts / expenses with
/// cash, bank / UPI / online, other and total columns (tap a value to read how it is calculated).
class FinancePeriodHeadTables extends StatelessWidget {
  const FinancePeriodHeadTables({super.key, required this.report, this.section = FinancePeriodHeadSection.all});

  final FinancePeriodReportResult report;
  final FinancePeriodHeadSection section;

  @override
  Widget build(BuildContext context) {
    final showReceipts = section != FinancePeriodHeadSection.expenses;
    final showExpenses = section != FinancePeriodHeadSection.receipts;
    final hi = isHindi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showReceipts)
          ReportPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('COLLECTION RECEIPTS (HEAD-WISE)', 'संग्रह रसीदें (मद-वार)'), style: AppText.fieldLabel(context)),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.tr(
                        '${report.verifiedPaymentCount} maintenance receipt row(s) in range; ledger-only inflows added:',
                        'अवधि में ${report.verifiedPaymentCount} रखरखाव रसीद पंक्ति(याँ); केवल खाता-बही आवक जोड़ी गई:',
                      ),
                      style: AppText.caption(context).copyWith(fontSize: 11),
                    ),
                    InfoValue(value: rupees(report.extraLedgerReceipt), metric: ReportMetrics.extraLedgerReceipt),
                  ],
                ),
                const SizedBox(height: 10),
                _HeadTable(
                  headLabel: context.tr('Receipt head', 'रसीद मद'),
                  rows: report.receiptByHead,
                  emptyText: context.tr('No verified collections in this period.', 'इस अवधि में कोई सत्यापित संग्रह नहीं।'),
                  rowMetric: ReportMetrics.periodReceiptHead,
                  footerLabel: context.tr('All receipts', 'सभी रसीदें'),
                  footer: report.receiptByMethod,
                  footerTotal: report.totalReceipts,
                  footerMetric: ReportMetrics.periodVerifiedReceipts,
                  hi: hi,
                ),
              ],
            ),
          ),
        if (showReceipts && showExpenses) const SizedBox(height: 16),
        if (showExpenses)
          ReportPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('EXPENSES (HEAD-WISE)', 'खर्च (मद-वार)'), style: AppText.fieldLabel(context)),
                const SizedBox(height: 10),
                _HeadTable(
                  headLabel: context.tr('Expense head', 'खर्च मद'),
                  rows: report.expenseByHead,
                  emptyText: context.tr('No separate-entry expenses in this period.', 'इस अवधि में कोई अलग-प्रविष्टि खर्च नहीं।'),
                  rowMetric: ReportMetrics.periodExpenseHead,
                  footerLabel: context.tr('All expenses', 'सभी खर्च'),
                  footer: report.expenseByMethod,
                  footerTotal: report.totalExpenses,
                  footerMetric: ReportMetrics.periodAllExpenses,
                  hi: hi,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeadTable extends StatelessWidget {
  const _HeadTable({
    required this.headLabel,
    required this.rows,
    required this.emptyText,
    required this.rowMetric,
    required this.footerLabel,
    required this.footer,
    required this.footerTotal,
    required this.footerMetric,
    required this.hi,
  });

  final String headLabel;
  final List<HeadAmount> rows;
  final String emptyText;
  final MetricCopy rowMetric;
  final String footerLabel;
  final ChannelTotals footer;
  final double footerTotal;
  final MetricCopy footerMetric;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final headerStyle = AppText.caption(context).copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: t.foreground);
    TableRow header() => TableRow(
          decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.8)),
          children: [
            _cell(Text(headLabel, style: headerStyle)),
            _cell(Text(context.tr('Cash', 'नकद'), style: headerStyle, textAlign: TextAlign.right)),
            _cell(Text(context.tr('Bank / UPI / online', 'बैंक / यूपीआई / ऑनलाइन'), style: headerStyle, textAlign: TextAlign.right)),
            _cell(Text(context.tr('Other', 'अन्य'), style: headerStyle, textAlign: TextAlign.right)),
            _cell(Text(context.tr('Total', 'कुल'), style: headerStyle, textAlign: TextAlign.right)),
          ],
        );
    Widget money(double v, MetricCopy m, String title, {bool bold = false, String? extra}) => Align(
          alignment: Alignment.centerRight,
          child: InfoValue(
            value: rupees(v),
            metric: m,
            title: title,
            extraDescription: extra,
            alignEnd: true,
            style: AppText.mono(context, size: 12, weight: bold ? FontWeight.w700 : FontWeight.w400),
          ),
        );
    final cashT = ReportMetrics.channelCash, bankT = ReportMetrics.channelBank, otherT = ReportMetrics.channelOther;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 460),
        child: Table(
          border: TableBorder.all(color: t.border, borderRadius: BorderRadius.circular(6)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FixedColumnWidth(140),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: IntrinsicColumnWidth(),
            4: IntrinsicColumnWidth(),
          },
          children: [
            header(),
            if (rows.isEmpty)
              TableRow(children: [
                _cell(Text(emptyText, style: AppText.caption(context))),
                const SizedBox(),
                const SizedBox(),
                const SizedBox(),
                const SizedBox(),
              ])
            else
              for (final h in rows)
                TableRow(children: [
                  _cell(Text(h.head, style: AppText.body(context).copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  _cell(money(h.row.cash, cashT, '${h.head} — ${hi ? 'नकद' : 'cash'}')),
                  _cell(money(h.row.bank, bankT, '${h.head} — ${hi ? 'बैंक / यूपीआई' : 'bank / UPI'}')),
                  _cell(money(h.row.other, otherT, '${h.head} — ${hi ? 'अन्य' : 'other'}')),
                  _cell(money(h.row.total, rowMetric, h.head, bold: true, extra: '${hi ? 'मद' : 'Head'}: ${h.head}.')),
                ]),
            TableRow(
              decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.5)),
              children: [
                _cell(Text(footerLabel, style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w700))),
                _cell(money(footer.cash, cashT, '$footerLabel — ${hi ? 'नकद' : 'cash'}', bold: true)),
                _cell(money(footer.bank, bankT, '$footerLabel — ${hi ? 'बैंक / यूपीआई' : 'bank / UPI'}', bold: true)),
                _cell(money(footer.other, otherT, '$footerLabel — ${hi ? 'अन्य' : 'other'}', bold: true)),
                _cell(money(footerTotal, footerMetric, footerMetric.title(hi), bold: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _cell(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: child);
}
