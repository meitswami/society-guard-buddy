/// Port of `src/lib/eventFoodFundAdjustments.ts`.
library;

/// `event_food_fund_adjustments.adjustment_kind` values.
abstract final class EventFoodAdjustKind {
  static const shortfallCover = 'shortfall_cover';
  static const surplusToPool = 'surplus_to_pool';

  static const all = [shortfallCover, surplusToPool];
}

/// `event_food_fund_adjustments.source_type` values (order = web `Object.keys` order).
abstract final class EventFoodAdjustSource {
  static const memberAdvance = 'member_advance';
  static const maintenancePool = 'maintenance_pool';
  static const corpus = 'corpus';
  static const societyPool = 'society_pool';

  static const all = [memberAdvance, maintenancePool, corpus, societyPool];
}

/// English labels (web `EVENT_FOOD_ADJUST_KIND_LABELS`); the UI translates via `efr.kind.*` keys.
const Map<String, String> kEventFoodAdjustKindLabels = {
  EventFoodAdjustKind.shortfallCover: 'Cover shortfall',
  EventFoodAdjustKind.surplusToPool: 'Transfer surplus to society pool',
};

/// English labels (web `EVENT_FOOD_SHORTFALL_SOURCE_LABELS`); the UI translates via `efr.source.*` keys.
const Map<String, String> kEventFoodShortfallSourceLabels = {
  EventFoodAdjustSource.memberAdvance: 'Member advance / flat top-up',
  EventFoodAdjustSource.maintenancePool: 'Society maintenance collections (pool)',
  EventFoodAdjustSource.corpus: 'Corpus fund',
  EventFoodAdjustSource.societyPool: 'Society pool account',
};

class EventFoodBalance {
  const EventFoodBalance({
    required this.rawNet,
    required this.remainingShortfall,
    required this.remainingSurplus,
    required this.adjustedNet,
    required this.shortfallCovers,
    required this.surplusTransfers,
  });

  final double rawNet;
  final double remainingShortfall;
  final double remainingSurplus;
  final double adjustedNet;
  final double shortfallCovers;
  final double surplusTransfers;
}

double _max0(double v) => v > 0 ? v : 0;

EventFoodBalance eventFoodBalance({
  required double contribIn,
  required double foodOut,
  required double shortfallCovers,
  required double surplusTransfers,
}) {
  final rawNet = contribIn - foodOut;
  final remainingShortfall = _max0(foodOut - contribIn - shortfallCovers);
  final remainingSurplus = _max0(contribIn - foodOut - surplusTransfers);
  final adjustedNet = contribIn + shortfallCovers - foodOut - surplusTransfers;
  return EventFoodBalance(
    rawNet: rawNet,
    remainingShortfall: remainingShortfall,
    remainingSurplus: remainingSurplus,
    adjustedNet: adjustedNet,
    shortfallCovers: shortfallCovers,
    surplusTransfers: surplusTransfers,
  );
}
