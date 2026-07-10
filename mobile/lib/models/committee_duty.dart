class CommitteeDutyRow {
  const CommitteeDutyRow({
    required this.id,
    required this.dutyLabel,
    required this.supervisorNames,
    this.sortOrder = 0,
  });

  final String id;
  final String dutyLabel;
  final List<String> supervisorNames;
  final int sortOrder;

  factory CommitteeDutyRow.fromRow(Map<String, dynamic> row) => CommitteeDutyRow(
        id: row['id'] as String,
        dutyLabel: row['duty_label'] as String,
        supervisorNames: (row['supervisor_names'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        sortOrder: row['sort_order'] as int? ?? 0,
      );
}

class CommitteeDutiesChart {
  const CommitteeDutiesChart({
    required this.id,
    required this.periodFrom,
    this.periodTo,
    required this.rows,
  });

  final String id;
  final String periodFrom;
  final String? periodTo;
  final List<CommitteeDutyRow> rows;

  factory CommitteeDutiesChart.fromChartAndRows(
    Map<String, dynamic> chart,
    List<Map<String, dynamic>> rows,
  ) =>
      CommitteeDutiesChart(
        id: chart['id'] as String,
        periodFrom: chart['period_from'] as String,
        periodTo: chart['period_to'] as String?,
        rows: rows.map(CommitteeDutyRow.fromRow).toList(),
      );
}
