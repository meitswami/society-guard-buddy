import '../data/events_models.dart';
import 'cash_bank_channel.dart';
import 'event_food_fund.dart';
import 'expense_balances.dart';
import 'js_compat.dart';

/// Port of the `EventFoodReconciliation` totals / per-event rows.

const String kUnlinkedEventKey = '__unlinked__';

class ReconEvent {
  const ReconEvent({required this.id, required this.title, required this.eventDate, this.contributionAmount = 0});

  final String id;
  final String title;
  final String eventDate;
  final double contributionAmount;

  bool get isUnlinked => id == kUnlinkedEventKey;
}

class ReconRow {
  ReconRow(this.event);

  final ReconEvent event;
  double contribIn = 0;
  double foodOut = 0;
  final List<EventContribution> contribs = [];
  final List<FoodExpenseRow> expenses = [];
  final ChannelTotals receiptChannels = ChannelTotals();
  final ChannelTotals paymentChannels = ChannelTotals();
  List<EventFoodAdjustment> eventAdjustments = const [];
  double shortfallCovers = 0;
  double surplusTransfers = 0;
  double remainingShortfall = 0;
  double remainingSurplus = 0;
  double adjustedNet = 0;

  double get rawNet => contribIn - foodOut;
}

class ReconTotals {
  const ReconTotals({
    required this.contribIn,
    required this.foodOut,
    required this.balance,
    required this.receiptChannels,
    required this.paymentChannels,
    required this.netChannels,
  });

  final double contribIn;
  final double foodOut;
  final EventFoodBalance balance;
  final ChannelTotals receiptChannels;
  final ChannelTotals paymentChannels;
  final ChannelTotals netChannels;

  double get net => balance.rawNet;
}

double _sumKind(Iterable<EventFoodAdjustment> adj, String kind) =>
    adj.where((a) => a.adjustmentKind == kind).fold<double>(0, (s, a) => s + a.amount);

ReconTotals reconciliationTotals({
  required List<EventContribution> contributions,
  required List<FoodExpenseRow> foodExpenses,
  required List<EventFoodAdjustment> adjustments,
}) {
  final contribIn = contributions.fold<double>(0, (s, c) => s + c.amount);
  final foodOut = foodExpenses.fold<double>(0, (s, e) => s + e.totalAmount);
  final shortfallCovers = _sumKind(adjustments, EventFoodAdjustKind.shortfallCover);
  final surplusTransfers = _sumKind(adjustments, EventFoodAdjustKind.surplusToPool);
  final receiptChannels = sumByChannel<EventContribution>(contributions, (c) => c.amount, (c) => c.paymentMethod);
  final paymentChannels = sumByChannel<FoodExpenseRow>(foodExpenses, (e) => e.totalAmount, (e) => e.paymentMethod);
  final balance = eventFoodBalance(
    contribIn: contribIn,
    foodOut: foodOut,
    shortfallCovers: shortfallCovers,
    surplusTransfers: surplusTransfers,
  );
  return ReconTotals(
    contribIn: contribIn,
    foodOut: foodOut,
    balance: balance,
    receiptChannels: receiptChannels,
    paymentChannels: paymentChannels,
    netChannels: netChannels(receiptChannels, paymentChannels),
  );
}

/// Per-event rows: events with any activity, plus "Food not linked to an event", newest first.
List<ReconRow> reconciliationRows({
  required List<ReconEvent> events,
  required List<EventContribution> contributions,
  required List<FoodExpenseRow> foodExpenses,
  required List<EventFoodAdjustment> adjustments,
  String unlinkedTitle = 'Food not linked to an event',
}) {
  final byEvent = <String, ReconRow>{};
  for (final ev in events) {
    byEvent[ev.id] = ReconRow(ev);
  }
  final unlinked = ReconRow(ReconEvent(id: kUnlinkedEventKey, title: unlinkedTitle, eventDate: ''));

  for (final c in contributions) {
    final row = byEvent[c.eventId];
    if (row == null) continue;
    row.contribIn += c.amount;
    row.contribs.add(c);
    addToChannel(row.receiptChannels, c.paymentMethod, c.amount);
  }

  for (final ex in foodExpenses) {
    final linked = ex.eventId != null ? byEvent[ex.eventId] : null;
    final row = linked ?? unlinked;
    row.foodOut += ex.totalAmount;
    row.expenses.add(ex);
    addToChannel(row.paymentChannels, ex.paymentMethod, ex.totalAmount);
  }

  for (final row in [...byEvent.values, unlinked]) {
    final eventId = row.event.isUnlinked ? null : row.event.id;
    final eventAdjustments = [
      for (final a in adjustments)
        if (a.eventId == eventId) a,
    ];
    final covers = _sumKind(eventAdjustments, EventFoodAdjustKind.shortfallCover);
    final transfers = _sumKind(eventAdjustments, EventFoodAdjustKind.surplusToPool);
    final bal = eventFoodBalance(
      contribIn: row.contribIn,
      foodOut: row.foodOut,
      shortfallCovers: covers,
      surplusTransfers: transfers,
    );
    row.eventAdjustments = eventAdjustments;
    row.shortfallCovers = covers;
    row.surplusTransfers = transfers;
    row.remainingShortfall = bal.remainingShortfall;
    row.remainingSurplus = bal.remainingSurplus;
    row.adjustedNet = bal.adjustedNet;
  }

  final rows = [
    for (final r in byEvent.values)
      if (r.contribIn > 0 ||
          r.foodOut > 0 ||
          r.contribs.isNotEmpty ||
          r.expenses.isNotEmpty ||
          r.eventAdjustments.isNotEmpty)
        r,
  ];
  if (unlinked.foodOut > 0 || unlinked.expenses.isNotEmpty) rows.add(unlinked);
  return stableSorted(rows, (a, b) => b.event.eventDate.compareTo(a.event.eventDate));
}

class ReceiptLink {
  const ReceiptLink(this.label, this.url, {this.isBill = false});

  final String label;
  final String url;

  /// True for the `bill_screenshot_url` entry (label "Bill / receipt").
  final bool isBill;
}

/// `EventFoodReconciliation.receiptLinks`.
List<ReceiptLink> foodReceiptLinks(FoodExpenseRow ex) {
  final urls = <ReceiptLink>[];
  final bill = ex.billScreenshotUrl;
  if (bill != null && bill.isNotEmpty) urls.add(ReceiptLink('Bill / receipt', bill, isBill: true));
  for (final u in ex.attachmentUrls ?? const <String>[]) {
    if (u.isNotEmpty && !urls.any((x) => x.url == u)) {
      urls.add(ReceiptLink(attachmentFileName(u), u));
    }
  }
  return urls;
}
