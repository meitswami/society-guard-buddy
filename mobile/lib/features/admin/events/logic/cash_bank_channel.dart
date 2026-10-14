import 'js_compat.dart';

/// Port of `src/lib/cashBankChannel.ts` + `normalizePaymentChannel` (`financeAuditDetection.ts`).

enum PaymentChannel { cash, bank, other }

const List<String> _bankKeys = [
  'upi',
  'bank_transfer',
  'razorpay',
  'online',
  'card',
  'neft',
  'rtgs',
  'imps',
  'netbanking',
  'cheque',
  'dd',
];

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

  double get total => cash + bank + other;

  @override
  String toString() => 'ChannelTotals(cash: $cash, bank: $bank, other: $other)';
}

ChannelTotals emptyChannelTotals() => ChannelTotals();

void addToChannel(ChannelTotals totals, Object? method, num amount) {
  final ch = normalizePaymentChannel(method);
  final a = amount.toDouble();
  totals.add(ch, a.isNaN ? 0 : a);
}

ChannelTotals sumByChannel<T>(Iterable<T> items, num Function(T item) getAmount, Object? Function(T item) getMethod) {
  final totals = emptyChannelTotals();
  for (final item in items) {
    addToChannel(totals, getMethod(item), getAmount(item));
  }
  return totals;
}

ChannelTotals netChannels(ChannelTotals receipts, ChannelTotals payments) => ChannelTotals(
      cash: receipts.cash - payments.cash,
      bank: receipts.bank - payments.bank,
      other: receipts.other - payments.other,
    );

double channelTotal(ChannelTotals t) => t.cash + t.bank + t.other;

String channelDisplayLabel(Object? method) {
  final ch = normalizePaymentChannel(method);
  if (ch == PaymentChannel.cash) return 'Cash';
  if (ch == PaymentChannel.bank) return 'Bank / UPI';
  final s = method?.toString() ?? '';
  return s.isEmpty ? 'Other' : s;
}

String formatChannelParts(ChannelTotals t, {String prefix = '₹'}) {
  final parts = <String>[];
  if (t.cash > 0) parts.add('Cash $prefix${jsLocaleIn(t.cash)}');
  if (t.bank > 0) parts.add('Bank $prefix${jsLocaleIn(t.bank)}');
  if (t.other > 0) parts.add('Other $prefix${jsLocaleIn(t.other)}');
  return parts.isEmpty ? '${prefix}0' : parts.join(' · ');
}
