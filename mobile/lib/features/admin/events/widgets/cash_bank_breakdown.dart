import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/js_compat.dart';
import 'ev_i18n.dart';
import 'ev_ui.dart';

/// Private port of `src/components/CashBankBreakdown.tsx` (+ `ChannelBadge`).
enum CashBankVariant { inline, table, compact }

String _fmt(double n) => rupeeLoc(n);

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
    final rLabel = receiptLabel ?? context.ev('cbb.receiptsIn');
    final pLabel = paymentLabel ?? context.ev('cbb.paymentsOut');

    if (variant == CashBankVariant.inline) {
      String parts(ChannelTotals c) {
        final p = <String>[
          if (c.cash > 0) '${context.ev('cbb.cashLower')} ${_fmt(c.cash)}',
          if (c.bank > 0) '${context.ev('cbb.bankLower')} ${_fmt(c.bank)}',
          if (c.other > 0) '${context.ev('cbb.otherLower')} ${_fmt(c.other)}',
        ];
        return p.isEmpty ? _fmt(0) : p.join(' · ');
      }

      final netTotal = channelTotal(net);
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: [
          Text('$rLabel: ${parts(receipts)} ·', style: TextStyle(fontSize: 10, color: t.success)),
          _metric(context, 'receipt', '${context.ev('cbb.total')} ${_fmt(channelTotal(receipts))}', t.success),
          Text('· $pLabel: ${parts(payments)} ·', style: TextStyle(fontSize: 10, color: t.warning)),
          _metric(context, 'payment', '${context.ev('cbb.total')} ${_fmt(channelTotal(payments))}', t.warning),
          Text('·', style: TextStyle(fontSize: 10, color: t.mutedForeground)),
          _metric(context, 'net', '${context.ev('cbb.net')} ${_fmt(netTotal)}', netTotal >= 0 ? t.foreground : t.destructive),
        ],
      );
    }

    if (variant == CashBankVariant.compact) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.muted, 0.15),
          border: Border.all(color: AppTokens.tint(t.border, 0.6)),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (final ch in PaymentChannel.values) ...[
                  if (ch != PaymentChannel.cash) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.5), borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        children: [
                          Text(_channelName(context, ch), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.mutedForeground)),
                          Text('+${_fmt(receipts[ch])}', style: TextStyle(fontSize: 10, color: t.success)),
                          Text('−${_fmt(payments[ch])}', style: TextStyle(fontSize: 10, color: t.warning)),
                          Text(
                            _fmt(net[ch]),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: net[ch] >= 0 ? t.foreground : t.destructive),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            _TotalsStrip(receipts: receipts, payments: payments, net: net),
          ],
        ),
      );
    }

    final rows = <(String, ChannelTotals, bool)>[
      (rLabel, receipts, false),
      (pLabel, payments, false),
      (context.ev('cbb.netRow'), net, true),
    ];
    Widget head(String s) => Padding(
          padding: const EdgeInsets.all(5),
          child: Text(s, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.foreground)),
        );
    Widget val(String label, String chKey, double v, bool bold) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: EvValueButton(
              value: _fmt(v),
              title: '$label — ${context.ev('cbb.ch.$chKey')}',
              description: context.ev('sum.$chKey.desc'),
              howCalculated: context.ev('sum.$chKey.how'),
              mono: true,
              bold: bold,
              fontSize: 10,
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.muted, 0.15),
        border: Border.all(color: AppTokens.tint(t.border, 0.6)),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 440),
              child: Table(
                border: TableBorder.all(color: t.border, borderRadius: BorderRadius.circular(6)),
                columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth(), 4: FlexColumnWidth()},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.6)),
                    children: [
                      const SizedBox(),
                      head(context.ev('cbb.cash')),
                      head(context.ev('cbb.bankUpi')),
                      head(context.ev('cbb.other')),
                      head(context.ev('cbb.total')),
                    ],
                  ),
                  for (final (label, r, bold) in rows)
                    TableRow(
                      decoration: bold ? BoxDecoration(color: AppTokens.tint(t.muted, 0.3)) : null,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: t.foreground)),
                        ),
                        val(label, 'cash', r.cash, bold),
                        val(label, 'bank', r.bank, bold),
                        val(label, 'other', r.other, bold),
                        val(label, 'row', channelTotal(r), bold),
                      ],
                    ),
                ],
              ),
            ),
          ),
          _TotalsStrip(receipts: receipts, payments: payments, net: net, top: false),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String key, String value, Color color) => EvValueButton(
        value: value,
        title: context.ev('sum.$key.title'),
        description: context.ev('sum.$key.desc'),
        howCalculated: context.ev('sum.$key.how'),
        color: color,
      );
}

String _channelName(BuildContext context, PaymentChannel ch) => switch (ch) {
      PaymentChannel.cash => context.ev('cbb.cash'),
      PaymentChannel.bank => context.ev('cbb.bank'),
      PaymentChannel.other => context.ev('cbb.other'),
    };

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.receipts, required this.payments, required this.net, this.top = true});

  final ChannelTotals receipts;
  final ChannelTotals payments;
  final ChannelTotals net;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    String breakdown(ChannelTotals c, {bool otherNonZero = false}) {
      final showOther = otherNonZero ? c.other != 0 : c.other > 0;
      return '(${context.ev('cbb.cash')} ${_fmt(c.cash)} · ${context.ev('cbb.bank')} ${_fmt(c.bank)}'
          '${showOther ? ' · ${context.ev('cbb.other')} ${_fmt(c.other)}' : ''})';
    }

    final netTotal = channelTotal(net);
    Widget part(String key, String label, double total, Color color, String detail) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$label ', style: TextStyle(fontSize: 10, color: color)),
            EvValueButton(
              value: _fmt(total),
              title: context.ev('sum.$key.title'),
              description: context.ev('sum.$key.desc'),
              howCalculated: context.ev('sum.$key.how'),
              color: color,
              fontSize: 10,
            ),
            Text(' $detail', style: TextStyle(fontSize: 10, color: t.mutedForeground)),
          ],
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 6),
      decoration: top ? BoxDecoration(border: Border(top: BorderSide(color: AppTokens.tint(t.border, 0.6)))) : null,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          part('receipt', context.ev('cbb.receiptsTotal'), channelTotal(receipts), t.success, breakdown(receipts)),
          part('payment', context.ev('cbb.paymentsTotal'), channelTotal(payments), t.warning, breakdown(payments)),
          part('net', context.ev('cbb.netTotal'), netTotal, netTotal >= 0 ? t.foreground : t.destructive, breakdown(net, otherNonZero: true)),
        ],
      ),
    );
  }
}

/// Badge for a single row's payment method.
class ChannelBadge extends StatelessWidget {
  const ChannelBadge({super.key, required this.method});

  final Object? method;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ch = normalizePaymentChannel(method);
    final color = switch (ch) {
      PaymentChannel.cash => t.warning,
      PaymentChannel.bank => t.accent,
      PaymentChannel.other => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color == null ? t.muted : AppTokens.tint(color, 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        _channelName(context, ch).toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color ?? t.mutedForeground),
      ),
    );
  }
}
