import 'finance_period_report.dart';

/// Port of the pure parts of `src/lib/reportAggregations.ts`
/// (the Supabase fetch lives in `data/reports_repository.dart`).

class StatusBucket {
  const StatusBucket({required this.status, required this.count, required this.total});

  /// Web sets both `payment_status` and `status` to the bucket key.
  final String status;
  final int count;
  final double total;

  String get paymentStatus => status;

  @override
  bool operator ==(Object other) =>
      other is StatusBucket && other.status == status && other.count == count && other.total == total;

  @override
  int get hashCode => Object.hash(status, count, total);

  @override
  String toString() => 'StatusBucket($status, $count, $total)';
}

class MaintenanceLinkSummary {
  const MaintenanceLinkSummary({
    required this.linkedCount,
    required this.linkedTotal,
    required this.unlinkedCount,
    required this.unlinkedTotal,
  });

  final int linkedCount;
  final double linkedTotal;
  final int unlinkedCount;
  final double unlinkedTotal;
}

class ReportModuleAggregations {
  const ReportModuleAggregations({
    this.maintenanceStatuses = const [],
    this.maintenanceLinkSummary,
    this.donationStatuses = const [],
    this.splitStatuses = const [],
  });

  static const empty = ReportModuleAggregations();

  final List<StatusBucket> maintenanceStatuses;
  final MaintenanceLinkSummary? maintenanceLinkSummary;
  final List<StatusBucket> donationStatuses;
  final List<StatusBucket> splitStatuses;
}

/// Count + sum per key, in first-seen order (JS `Map` iteration order).
List<StatusBucket> bucketByKey<T>(Iterable<T> rows, String Function(T) keyFn, double Function(T) amountFn) {
  final counts = <String, int>{};
  final totals = <String, double>{};
  for (final row in rows) {
    final key = keyFn(row);
    counts[key] = (counts[key] ?? 0) + 1;
    totals[key] = (totals[key] ?? 0) + amountFn(row);
  }
  return [for (final k in counts.keys) StatusBucket(status: k, count: counts[k]!, total: totals[k]!)];
}

/// Ledger payment-status buckets for a filtered entry set.
List<StatusBucket> computeLedgerStatusBuckets(Iterable<FinancePeriodLedgerEntry> entries) =>
    bucketByKey(entries, (e) => e.effectiveStatus, (e) => e.totalAmount);

class LedgerInflowGroup {
  const LedgerInflowGroup({
    required this.recordMode,
    required this.destination,
    required this.total,
    required this.flatUnits,
    required this.count,
  });

  final String recordMode;
  final String destination;
  final double total;
  final double flatUnits;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is LedgerInflowGroup &&
      other.recordMode == recordMode &&
      other.destination == destination &&
      other.total == total &&
      other.flatUnits == flatUnits &&
      other.count == count;

  @override
  int get hashCode => Object.hash(recordMode, destination, total, flatUnits, count);
}

/// Group ledger inflows by `record_mode` + `destination` (Report page and Finance totals).
List<LedgerInflowGroup> computeLedgerInflowGroups(
  Iterable<FinancePeriodLedgerEntry> entries, {
  bool excludeSeparateEntry = false,
}) {
  final order = <String>[];
  final totals = <String, double>{};
  final units = <String, double>{};
  final counts = <String, int>{};
  final modes = <String, String>{};
  final dests = <String, String>{};
  for (final e in entries) {
    if (excludeSeparateEntry && e.destination == 'separate_entry') continue;
    final key = '${e.recordMode ?? ''}||${e.destination}';
    if (!counts.containsKey(key)) {
      order.add(key);
      modes[key] = e.recordMode ?? '';
      dests[key] = e.destination;
    }
    totals[key] = (totals[key] ?? 0) + e.totalAmount;
    units[key] = (units[key] ?? 0) + e.aggregateFlatCount;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return [
    for (final k in order)
      LedgerInflowGroup(
        recordMode: modes[k]!,
        destination: dests[k]!,
        total: totals[k]!,
        flatUnits: units[k]!,
        count: counts[k]!,
      ),
  ];
}

/// Filter ledger entries to an inclusive transaction-date range (string compare, like the web).
List<FinancePeriodLedgerEntry> filterLedgerByTransactionDateRange(
  Iterable<FinancePeriodLedgerEntry> entries,
  String from,
  String to,
) =>
    entries.where((e) {
      final d = e.ledgerDate;
      return d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
    }).toList();
