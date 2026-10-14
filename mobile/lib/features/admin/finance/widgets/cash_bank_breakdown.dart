// Port of `src/components/CashBankBreakdown.tsx` (table / compact / inline variants).

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/finance_format.dart';
import 'fin_kit.dart';
import 'finance_metric_copy.dart';

enum CashBankVariant { table, compact, inline }

class CashBankBreakdown extends StatelessWidget {
  const CashBankBreakdown({
    super.key,
    required this.receipts,
    required this.payments,
    this.variant = CashBankVariant.table,
    this.receiptLabel,
    this.paymentLabel,
  });

  final ChannelTotals receipts;
  final ChannelTotals payments;
  final CashBankVariant variant;
  final String? receiptLabel;
  final String? paymentLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final net = netChannels(receipts, payments);
    final rLabel = receiptLabel ?? context.tr('Receipts (in)', 'रसीदें (आय)');
    final pLabel =
        paymentLabel ?? context.tr('Payments (out)', 'भुगतान (व्यय)');
    final m = FinMetrics.of(context);

    if (variant == CashBankVariant.inline) {
      String parts(ChannelTotals c) {
        final p = [
          if (c.cash > 0) '${context.tr('cash', 'नकद')} ${inrLocale(c.cash)}',
          if (c.bank > 0) '${context.tr('bank', 'बैंक')} ${inrLocale(c.bank)}',
          if (c.other > 0)
            '${context.tr('other', 'अन्य')} ${inrLocale(c.other)}',
        ];
        return p.isEmpty ? inrLocale(0) : p.join(' · ');
      }

      return Text(
        '$rLabel: ${parts(receipts)} · ${context.fin('fin.total')} ${inrLocale(receipts.total)} · '
        '$pLabel: ${parts(payments)} · ${context.fin('fin.total')} ${inrLocale(payments.total)} · '
        '${context.tr('Net', 'शुद्ध')} ${inrLocale(net.total)}',
        style: AppText.tiny(context).copyWith(fontSize: 11),
      );
    }

    final strip =
        _TotalsStrip(receipts: receipts, payments: payments, net: net);

    if (variant == CashBankVariant.compact) {
      Widget cell(String label, double rin, double rout, double n) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTokens.tint(t.muted, 0.6),
                  borderRadius: BorderRadius.circular(4)),
              child: Column(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: t.mutedForeground)),
                  Text('+${inrLocale(rin)}',
                      style: TextStyle(fontSize: 10, color: t.success)),
                  Text('−${inrLocale(rout)}',
                      style: TextStyle(fontSize: 10, color: t.warning)),
                  Text(inrLocale(n),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: n >= 0 ? t.foreground : t.destructive)),
                ],
              ),
            ),
          );
      return FinTintBox(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(children: [
              cell(context.fin('fin.cash'), receipts.cash, payments.cash,
                  net.cash),
              cell(context.tr('Bank', 'बैंक'), receipts.bank, payments.bank,
                  net.bank),
              cell(context.fin('fin.other'), receipts.other, payments.other,
                  net.other),
            ]),
            strip,
          ],
        ),
      );
    }

    final rows = [
      (rLabel, receipts, false),
      (pLabel, payments, false),
      (
        context.tr('Net (receipts − payments)', 'शुद्ध (रसीद − भुगतान)'),
        net,
        true
      )
    ];
    return FinTintBox(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinTable(
            columns: [
              const FinCol('', width: 130),
              FinCol(context.fin('fin.cash'), width: 78, right: true),
              FinCol(context.fin('fin.bankUpi'), width: 84, right: true),
              FinCol(context.fin('fin.other'), width: 70, right: true),
              FinCol(context.fin('fin.total'), width: 86, right: true),
            ],
            rows: [
              for (final (label, r, bold) in rows)
                [
                  finCell(context, label, bold: bold),
                  FinInfoValue(
                      title: '$label — ${context.fin('fin.cash')}',
                      value: inrLocale(r.cash),
                      description: m.channelCash.$2,
                      howCalculated: m.channelCash.$3,
                      style: AppText.mono(context, size: 10)),
                  FinInfoValue(
                      title: '$label — ${context.fin('fin.bankUpi')}',
                      value: inrLocale(r.bank),
                      description: m.channelBank.$2,
                      howCalculated: m.channelBank.$3,
                      style: AppText.mono(context, size: 10)),
                  FinInfoValue(
                      title: '$label — ${context.fin('fin.other')}',
                      value: inrLocale(r.other),
                      description: m.channelOther.$2,
                      howCalculated: m.channelOther.$3,
                      style: AppText.mono(context, size: 10)),
                  FinInfoValue(
                    title: '$label — ${context.fin('fin.total')}',
                    value: inrLocale(channelTotal(r)),
                    description: m.rowTotal.$2,
                    howCalculated: m.rowTotal.$3,
                    style: AppText.mono(context,
                        size: 10,
                        weight: bold ? FontWeight.w700 : FontWeight.w400),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 8),
          strip,
        ],
      ),
    );
  }
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip(
      {required this.receipts, required this.payments, required this.net});

  final ChannelTotals receipts;
  final ChannelTotals payments;
  final ChannelTotals net;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = FinMetrics.of(context);
    String detail(ChannelTotals c, {bool showOtherIfNonZero = false}) {
      final other = showOtherIfNonZero ? c.other != 0 : c.other > 0;
      return '(${context.fin('fin.cash')} ${inrLocale(c.cash)} · ${context.tr('Bank', 'बैंक')} ${inrLocale(c.bank)}'
          '${other ? ' · ${context.fin('fin.other')} ${inrLocale(c.other)}' : ''})';
    }

    Widget item(String label, (String, String, String) copy, double total,
            ChannelTotals c, Color color,
            {bool netRow = false}) =>
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$label ',
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: netRow ? FontWeight.w500 : FontWeight.w400)),
            FinInfoValue(
              title: copy.$1,
              value: inrLocale(total),
              description: copy.$2,
              howCalculated: copy.$3,
              color: color,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            Text(' ${detail(c, showOtherIfNonZero: netRow)}',
                style: TextStyle(fontSize: 10, color: t.mutedForeground)),
          ],
        );

    final netTotal = channelTotal(net);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: AppTokens.tint(t.border, 0.6)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(
              context.tr('Receipts total', 'कुल रसीदें'),
              m.cashBankReceiptTotal,
              channelTotal(receipts),
              receipts,
              t.success),
          item(
              context.tr('Payments total', 'कुल भुगतान'),
              m.cashBankPaymentTotal,
              channelTotal(payments),
              payments,
              t.warning),
          item(context.tr('Net total', 'कुल शुद्ध'), m.cashBankNetTotal,
              netTotal, net, netTotal >= 0 ? t.foreground : t.destructive,
              netRow: true),
        ],
      ),
    );
  }
}
