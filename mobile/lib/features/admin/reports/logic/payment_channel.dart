import 'js_compat.dart';

/// Port of `normalizePaymentChannel` (`financeAuditDetection.ts`) and
/// `src/lib/cashBankChannel.ts`.
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

/// `null` → cash (web `String(method ?? 'cash')`); upi / bank transfer / card / cheque … → bank;
/// anything else (including `''` and plain `'bank'`) → other.
PaymentChannel normalizePaymentChannel(Object? method) {
  final x = (method ?? 'cash').toString().toLowerCase().replaceAll(RegExp(r'\s'), '');
  if (x == 'cash') return PaymentChannel.cash;
  if (_bankKeys.any((k) => x == k || x.contains(k))) return PaymentChannel.bank;
  return PaymentChannel.other;
}

/// Mutable `{ cash, bank, other }` totals.
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

  Map<String, double> toJson() => {'cash': cash, 'bank': bank, 'other': other};

  @override
  bool operator ==(Object other) =>
      other is ChannelTotals && other.cash == cash && other.bank == bank && other.other == this.other;

  @override
  int get hashCode => Object.hash(cash, bank, other);

  @override
  String toString() => 'ChannelTotals(cash: $cash, bank: $bank, other: $other)';
}

ChannelTotals emptyChannelTotals() => ChannelTotals();

void addToChannel(ChannelTotals totals, Object? method, num amount) {
  totals.add(normalizePaymentChannel(method), amount.isNaN ? 0 : amount.toDouble());
}

ChannelTotals sumByChannel<T>(Iterable<T> items, double Function(T) getAmount, Object? Function(T) getMethod) {
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
  if (t.cash > 0) parts.add('Cash $prefix${toLocaleIn(t.cash)}');
  if (t.bank > 0) parts.add('Bank $prefix${toLocaleIn(t.bank)}');
  if (t.other > 0) parts.add('Other $prefix${toLocaleIn(t.other)}');
  return parts.isEmpty ? '${prefix}0' : parts.join(' · ');
}
