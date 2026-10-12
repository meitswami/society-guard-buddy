/// Metadata-driven reporting engine types — port of `src/services/reporting/types.ts`.
library;

/// Tables the engine is allowed to query. Keep this list explicit for security.
const List<String> kReportableTables = [
  'visitors',
  'finance_entries',
  'maintenance_payments',
  'guard_shifts',
  'fixed_assets',
  'expenses',
  'donation_payments',
];

enum ReportColumnType { string, number, date, datetime, boolean }

enum ReportFilterType { text, number, date, dateRange, select, boolean }

enum ReportFilterOperator { eq, neq, gt, gte, lt, lte, ilike, inList }

enum ReportAggregate { sum, count, avg, min, max }

enum ReportColumnFormat { money, date, datetime }

class ReportColumnDef {
  const ReportColumnDef({
    required this.key,
    required this.label,
    required this.type,
    required this.field,
    this.sortable,
    this.searchable,
    this.aggregate,
    this.format,
    this.defaultVisible,
  });

  final String key;
  final String label;
  final ReportColumnType type;

  /// DB field or dotted path into a joined relation, e.g. `maintenance_charges.title`.
  final String field;
  final bool? sortable;
  final bool? searchable;
  final ReportAggregate? aggregate;
  final ReportColumnFormat? format;
  final bool? defaultVisible;

  bool get isNumeric => type == ReportColumnType.number || format == ReportColumnFormat.money;
}

class ReportFilterOption {
  const ReportFilterOption(this.value, this.label);

  final String value;
  final String label;
}

class ReportFilterDef {
  const ReportFilterDef({
    required this.key,
    required this.label,
    required this.type,
    required this.field,
    this.operator,
    this.options,
    this.defaultValue,
  });

  final String key;
  final String label;
  final ReportFilterType type;
  final String field;
  final ReportFilterOperator? operator;
  final List<ReportFilterOption>? options;
  final Object? defaultValue;
}

class ReportJoinDef {
  const ReportJoinDef({required this.relation, this.columns});

  /// PostgREST relation name (FK embedding). Use `!inner` suffix for required joins.
  final String relation;
  final List<String>? columns;
}

class ReportSortDef {
  const ReportSortDef({required this.field, required this.ascending});

  final String field;
  final bool ascending;

  String get direction => ascending ? 'asc' : 'desc';

  Map<String, Object?> toJson() => {'field': field, 'direction': direction};

  static ReportSortDef? fromJson(Object? j) {
    if (j is! Map) return null;
    final f = j['field']?.toString();
    if (f == null || f.isEmpty) return null;
    return ReportSortDef(field: f, ascending: j['direction'] == 'asc');
  }

  @override
  bool operator ==(Object other) => other is ReportSortDef && other.field == field && other.ascending == ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}

/// Always-applied equality / null checks (no UI control).
class ReportFixedFilter {
  const ReportFixedFilter.eq(this.field, this.value) : op = 'eq';
  const ReportFixedFilter.neq(this.field, this.value) : op = 'neq';
  const ReportFixedFilter.notNull(this.field)
      : op = 'not_null',
        value = null;

  final String field;
  final String op;
  final Object? value;
}

/// Static metadata for one report.
class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.title,
    this.description,
    required this.permission,
    required this.baseTable,
    this.societyColumn,
    this.societyViaRelation,
    this.societyViaColumn,
    required this.columns,
    required this.filters,
    this.joins = const [],
    this.defaultSort,
    this.defaultPageSize,
    this.defaultGroupBy,
    this.rowLimit,
    this.fixedFilters = const [],
  });

  final String id;
  final String title;
  final String? description;

  /// Admin panel permission key (web snake_case, e.g. `report`).
  final String permission;
  final String baseTable;
  final String? societyColumn;
  final String? societyViaRelation;
  final String? societyViaColumn;
  final List<ReportColumnDef> columns;
  final List<ReportFilterDef> filters;
  final List<ReportJoinDef> joins;
  final ReportSortDef? defaultSort;
  final int? defaultPageSize;
  final List<String>? defaultGroupBy;
  final int? rowLimit;
  final List<ReportFixedFilter> fixedFilters;
}

/// `{ from, to }` value of a date-range filter.
class DateRangeValue {
  const DateRangeValue({this.from, this.to});

  final String? from;
  final String? to;

  bool get isEmpty => (from == null || from!.isEmpty) && (to == null || to!.isEmpty);

  Map<String, Object?> toJson() => {if (from != null) 'from': from, if (to != null) 'to': to};

  static DateRangeValue? fromJson(Object? j) {
    if (j is DateRangeValue) return j;
    if (j is! Map) return null;
    String? s(Object? v) => (v == null || v.toString().isEmpty) ? null : v.toString();
    return DateRangeValue(from: s(j['from']), to: s(j['to']));
  }

  @override
  bool operator ==(Object other) => other is DateRangeValue && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

typedef ReportFilterValues = Map<String, Object?>;

class ReportRequest {
  const ReportRequest({
    required this.reportId,
    required this.societyId,
    required this.permissions,
    this.columns,
    this.filters = const {},
    this.sort,
    this.search,
    this.groupBy,
    this.page,
    this.pageSize,
  });

  final String reportId;
  final String societyId;

  /// Permission lookup by web key (`AdminPanelPermissions.flag`).
  final bool Function(String key) permissions;
  final List<String>? columns;
  final ReportFilterValues filters;
  final ReportSortDef? sort;
  final String? search;
  final List<String>? groupBy;
  final int? page;
  final int? pageSize;
}

class ReportTotal {
  const ReportTotal({required this.key, required this.label, required this.value, required this.aggregate});

  final String key;
  final String label;
  final double value;
  final ReportAggregate aggregate;
}

class ReportResult {
  const ReportResult({
    required this.reportId,
    required this.title,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.page,
    required this.pageSize,
    required this.totalRows,
    required this.totalPages,
    required this.grouped,
  });

  final String reportId;
  final String title;
  final List<ReportColumnDef> columns;
  final List<Map<String, Object?>> rows;
  final List<ReportTotal> totals;
  final int page;
  final int pageSize;
  final int totalRows;
  final int totalPages;
  final bool grouped;
}

class SavedReportDefinition {
  const SavedReportDefinition({
    required this.id,
    required this.societyId,
    required this.reportId,
    required this.name,
    this.description,
    this.columns,
    this.filters = const {},
    this.sort,
    this.groupBy,
    this.createdBy,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String societyId;
  final String reportId;
  final String name;
  final String? description;
  final List<String>? columns;
  final ReportFilterValues filters;
  final ReportSortDef? sort;
  final List<String>? groupBy;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  factory SavedReportDefinition.fromJson(Map<String, dynamic> row) {
    List<String>? list(Object? v) => v is List ? v.map((e) => e.toString()).toList() : null;
    final f = row['filters'];
    return SavedReportDefinition(
      id: row['id'].toString(),
      societyId: (row['society_id'] ?? '').toString(),
      reportId: (row['report_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      description: row['description']?.toString(),
      columns: list(row['columns']),
      filters: f is Map ? Map<String, Object?>.from(f) : const {},
      sort: ReportSortDef.fromJson(row['sort']),
      groupBy: list(row['group_by']),
      createdBy: row['created_by']?.toString(),
      createdAt: (row['created_at'] ?? '').toString(),
      updatedAt: (row['updated_at'] ?? '').toString(),
    );
  }
}
