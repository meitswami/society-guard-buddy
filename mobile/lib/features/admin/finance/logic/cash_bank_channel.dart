// Port of `src/lib/cashBankChannel.ts` (+ `normalizePaymentChannel` from financeAuditDetection.ts).

import 'finance_format.dart';

enum PaymentChannel { cash, bank, other }

const _bankKeys = ['upi', 'bank_transfer', 'razorpay', 'online', 'card', 'neft', 'rtgs', 'imps', 'netbanking', 'cheque', 'dd'];

/// Web `normalizePaymentChannel`: null → cash; UPI / bank / online / cheque → bank; rest → other.
PaymentChannel normalizePaymentChannel(Object? method) {
  final x = (method ?? 'cash').toString().toLowerCase().replaceAll(RegExp(r'\s'), '');
  if (x == 'cash') return PaymentChannel.cash;
  if (_bankKeys.any((k) => x == k || x.contains(k))) return PaymentChannel.bank;
  return PaymentChannel.other;
}

/// Mutable cash / bank / other totals (web `ChannelTotals`).
class ChannelTotals {
  ChannelTotals({this.cash = 0, this.bank = 0, this.other = 0});

  double cash;
  double bank;
  double other;

  double get total => cash + bank + other;

  double operator [](PaymentChannel ch) => switch (ch) {
        PaymentChannel.cash => cash,
        PaymentChannel.bank => bank,
        PaymentChannel.other => other,
      };

  void add(PaymentChannel ch, double amount) {
    switch (ch) {
      case PaymentChannel.cash:
        cash += amount;
      case PaymentChannel.bank:
        bank += amount;
      case PaymentChannel.other:
        other += amount;
    }
  }

  ChannelTotals copy() => ChannelTotals(cash: cash, bank: bank, other: other);

  @override
  bool operator ==(Object other) =>
      other is ChannelTotals && other.cash == cash && other.bank == bank && other.other == this.other;

  @override
  int get hashCode => Object.hash(cash, bank, other);

  @override
  String toString() => 'ChannelTotals(cash: $cash, bank: $bank, other: $other)';
}

ChannelTotals emptyChannelTotals() => ChannelTotals();

/// Web `addToChannel`.
void addToChannel(ChannelTotals totals, Object? method, double amount) {
  totals.add(normalizePaymentChannel(method), amount.isNaN ? 0 : amount);
}

/// Web `sumByChannel`.
ChannelTotals sumByChannel<T>(Iterable<T> items, double Function(T) getAmount, Object? Function(T) getMethod) {
  final totals = emptyChannelTotals();
  for (final item in items) {
    addToChannel(totals, getMethod(item), getAmount(item));
  }
  return totals;
}

/// Web `netChannels` (receipts − payments per channel).
ChannelTotals netChannels(ChannelTotals receipts, ChannelTotals payments) => ChannelTotals(
      cash: receipts.cash - payments.cash,
      bank: receipts.bank - payments.bank,
      other: receipts.other - payments.other,
    );

double channelTotal(ChannelTotals t) => t.cash + t.bank + t.other;

/// Web `channelDisplayLabel`.
String channelDisplayLabel(Object? method) {
  final ch = normalizePaymentChannel(method);
  if (ch == PaymentChannel.cash) return 'Cash';
  if (ch == PaymentChannel.bank) return 'Bank / UPI';
  final s = method?.toString() ?? '';
  return s.isEmpty ? 'Other' : s;
}

/// Web `formatChannelParts`.
String formatChannelParts(ChannelTotals t, {String prefix = '₹'}) {
  final parts = <String>[];
  if (t.cash > 0) parts.add('Cash $prefix${localeNumber(t.cash)}');
  if (t.bank > 0) parts.add('Bank $prefix${localeNumber(t.bank)}');
  if (t.other > 0) parts.add('Other $prefix${localeNumber(t.other)}');
  return parts.isEmpty ? '${prefix}0' : parts.join(' · ');
}

/// Sum several channel rows (web `sumChannels`).
ChannelTotals sumChannelRows(Iterable<ChannelTotals> rows) {
  final acc = emptyChannelTotals();
  for (final r in rows) {
    acc.cash += r.cash;
    acc.bank += r.bank;
    acc.other += r.other;
  }
  return acc;
}
