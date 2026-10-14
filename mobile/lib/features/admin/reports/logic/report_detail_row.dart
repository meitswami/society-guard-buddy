/// One row in the report drill-down sheet (web `ReportDetailRow`).
class ReportDetailRow {
  const ReportDetailRow({
    required this.id,
    required this.label,
    this.sublabel,
    this.amount,
    this.date,
    this.dateIso,
    this.status,
    this.extra,
    this.meta,
  });

  final String id;
  final String label;
  final String? sublabel;
  final double? amount;
  final String? date;

  /// `yyyy-MM-dd` or ISO timestamp — used for monthly subtotals.
  final String? dateIso;
  final String? status;
  final String? extra;

  /// When set, the row can be drilled into (e.g. a cash-flow statement entry).
  final Object? meta;
}
