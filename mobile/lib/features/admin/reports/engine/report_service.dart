import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/db.dart';
import '../logic/js_compat.dart';
import 'report_metadata.dart';
import 'report_types.dart';

/// Port of `MetadataLoader`, `DynamicQueryBuilder`, `ReportRepository` and
/// `ReportService` (`src/services/reporting/*`). Callers pass report id +
/// filters; raw SQL is never accepted — only whitelisted fields / operators.

class MetadataLoader {
  MetadataLoader(
      [List<ReportDefinition> definitions = kBuiltinReportDefinitions])
      : _byId = {for (final d in definitions) d.id: d};

  final Map<String, ReportDefinition> _byId;

  List<ReportDefinition> list() => _byId.values.toList();

  ReportDefinition? get(String reportId) {
    final d = _byId[reportId];
    if (d != null) return d;
    for (final b in kBuiltinReportDefinitions) {
      if (b.id == reportId) return b;
    }
    return null;
  }

  ReportDefinition require(String reportId) {
    final def = get(reportId);
    if (def == null) throw StateError('Unknown report: $reportId');
    validate(def);
    return def;
  }

  void validate(ReportDefinition def) {
    if (!kReportableTables.contains(def.baseTable)) {
      throw StateError(
          'Report "${def.id}" uses non-reportable table: ${def.baseTable}');
    }
    if (def.societyColumn == null && def.societyViaRelation == null) {
      throw StateError(
          'Report "${def.id}" must define societyColumn or societyVia');
    }
    if (def.columns.isEmpty)
      throw StateError('Report "${def.id}" has no columns');
    final keys = <String>{};
    for (final c in def.columns) {
      if (!keys.add(c.key))
        throw StateError(
            'Report "${def.id}" has duplicate column key: ${c.key}');
    }
  }

  bool isReportableTable(String table) => kReportableTables.contains(table);
}

bool _isBlank(Object? v) =>
    v == null ||
    v == '' ||
    (v is List && v.isEmpty) ||
    (v is DateRangeValue && v.isEmpty);

Object? _nested(Map<String, dynamic> row, String path) {
  if (!path.contains('.')) return row[path];
  Object? cur = row;
  for (final part in path.split('.')) {
    if (cur is List) cur = cur.isEmpty ? null : cur.first;
    if (cur is! Map) return null;
    cur = cur[part];
  }
  return cur;
}

class DynamicQueryBuilder {
  const DynamicQueryBuilder();

  String buildSelect(ReportDefinition def) {
    final joinParts = def.joins.map((j) {
      final cols =
          (j.columns?.isNotEmpty ?? false) ? j.columns!.join(',') : '*';
      final inner = j.relation.endsWith('!inner');
      final rel = j.relation.replaceFirst(RegExp(r'!inner$'), '');
      return '$rel${inner ? '!inner' : ''}($cols)';
    });
    final base = <String>{
      for (final c in def.columns)
        if (!c.field.contains('.')) c.field
    };
    base.add('id');
    return [base.join(','), ...joinParts].where((s) => s.isNotEmpty).join(',');
  }

  String dateBound(String value, {required bool start}) {
    if (value.contains('T')) return value;
    return start ? '${value}T00:00:00' : '${value}T23:59:59.999';
  }

  PostgrestFilterBuilder<T> applySocietyScope<T>(
      PostgrestFilterBuilder<T> q, ReportDefinition def, String societyId) {
    if (def.societyColumn != null) return q.eq(def.societyColumn!, societyId);
    if (def.societyViaRelation != null)
      return q.eq(
          '${def.societyViaRelation}.${def.societyViaColumn}', societyId);
    throw StateError('Report "${def.id}" has no society scope');
  }

  PostgrestFilterBuilder<T> applyFilters<T>(PostgrestFilterBuilder<T> query,
      ReportDefinition def, ReportFilterValues filters) {
    var q = query;
    for (final f in def.filters) {
      final raw = filters[f.key] ?? f.defaultValue;
      if (_isBlank(raw)) continue;
      q = _applyOne(q, f, raw!);
    }
    for (final fixed in def.fixedFilters) {
      switch (fixed.op) {
        case 'not_null':
          q = q.not(fixed.field, 'is', null).neq(fixed.field, '');
        case 'eq':
          q = q.eq(fixed.field, fixed.value as Object);
        case 'neq':
          q = q.neq(fixed.field, fixed.value as Object);
      }
    }
    return q;
  }

  PostgrestFilterBuilder<T> _applyOne<T>(
      PostgrestFilterBuilder<T> q, ReportFilterDef f, Object raw) {
    if (f.type == ReportFilterType.dateRange) {
      final range =
          DateRangeValue.fromJson(raw is DateRangeValue ? raw.toJson() : raw);
      var out = q;
      if (range?.from != null)
        out = out.gte(f.field, dateBound(range!.from!, start: true));
      if (range?.to != null)
        out = out.lte(f.field, dateBound(range!.to!, start: false));
      return out;
    }
    final op = f.operator ?? ReportFilterOperator.eq;
    switch (op) {
      case ReportFilterOperator.eq:
        return q.eq(f.field, raw);
      case ReportFilterOperator.neq:
        return q.neq(f.field, raw);
      case ReportFilterOperator.gt:
        return q.gt(f.field, raw);
      case ReportFilterOperator.gte:
        return q.gte(f.field, raw);
      case ReportFilterOperator.lt:
        return q.lt(f.field, raw);
      case ReportFilterOperator.lte:
        return q.lte(f.field, raw);
      case ReportFilterOperator.ilike:
        return q.ilike(f.field, '%$raw%');
      case ReportFilterOperator.inList:
        final values = raw is List
            ? raw
            : raw.toString().split(',').map((s) => s.trim()).toList();
        return q.inFilter(f.field, values);
    }
  }

  /// Server-side sort field (null when the field is nested or not a known column).
  String? sortField(ReportDefinition def, ReportSortDef? sort) {
    final eff = sort ?? def.defaultSort;
    if (eff == null) return null;
    final allowed =
        def.columns.any((c) => c.field == eff.field || c.key == eff.field);
    if (!allowed) return null;
    String? byKey;
    for (final c in def.columns) {
      if (c.key == eff.field) {
        byKey = c.field;
        break;
      }
    }
    final field = byKey ?? eff.field;
    if (field.contains('.')) return null;
    return field;
  }

  /// Map raw DB rows to column-keyed rows using metadata field paths.
  List<Map<String, Object?>> projectRows(ReportDefinition def,
      List<Map<String, dynamic>> raw, List<String> columnKeys) {
    final cols = def.columns.where((c) => columnKeys.contains(c.key)).toList();
    return [
      for (final r in raw)
        {
          'id': r['id'],
          for (final c in cols) c.key: _nested(r, c.field),
        },
    ];
  }
}

/// Row source — Supabase in the app, in-memory in tests.
abstract class ReportRowSource {
  Future<List<Map<String, Object?>>> fetchRows({
    required ReportDefinition definition,
    required String societyId,
    required ReportFilterValues filters,
    ReportSortDef? sort,
    required List<String> columnKeys,
  });
}

class SupabaseReportRowSource implements ReportRowSource {
  const SupabaseReportRowSource([this.builder = const DynamicQueryBuilder()]);

  final DynamicQueryBuilder builder;

  @override
  Future<List<Map<String, Object?>>> fetchRows({
    required ReportDefinition definition,
    required String societyId,
    required ReportFilterValues filters,
    ReportSortDef? sort,
    required List<String> columnKeys,
  }) async {
    final select = builder.buildSelect(definition);
    final limit = definition.rowLimit ?? 2000;
    var q = db.from(definition.baseTable).select(select);
    q = builder.applySocietyScope(q, definition, societyId);
    q = builder.applyFilters(q, definition, filters);
    final eff = sort ?? definition.defaultSort;
    final field = builder.sortField(definition, sort);
    final data = field == null
        ? await q.limit(limit)
        : await q.order(field, ascending: eff?.ascending ?? true).limit(limit);
    return builder.projectRows(definition, rowsOf(data), columnKeys);
  }
}

/// Saved report views (`saved_report_definitions`).
class SavedReportRepository {
  const SavedReportRepository();

  static Object? _jsonFilters(ReportFilterValues f) => {
        for (final e in f.entries)
          e.key: e.value is DateRangeValue
              ? (e.value as DateRangeValue).toJson()
              : e.value
      };

  Future<List<SavedReportDefinition>> listSaved(String societyId,
      [String? reportId]) async {
    var q = db
        .from('saved_report_definitions')
        .select('*')
        .eq('society_id', societyId);
    if (reportId != null && reportId.isNotEmpty)
      q = q.eq('report_id', reportId);
    final data = await q.order('updated_at', ascending: false);
    return rowsOf(data).map(SavedReportDefinition.fromJson).toList();
  }

  Future<SavedReportDefinition> save({
    required String societyId,
    required String reportId,
    required String name,
    String? description,
    List<String>? columns,
    ReportFilterValues filters = const {},
    ReportSortDef? sort,
    List<String>? groupBy,
    String? createdBy,
  }) async {
    final d = description?.trim();
    final payload = {
      'society_id': societyId,
      'report_id': reportId,
      'name': name.trim(),
      'description': (d == null || d.isEmpty) ? null : d,
      'columns': columns,
      'filters': _jsonFilters(filters),
      'sort': sort?.toJson(),
      'group_by': groupBy,
      'created_by': createdBy,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final data = await db
        .from('saved_report_definitions')
        .insert(payload)
        .select('*')
        .single();
    return SavedReportDefinition.fromJson(data);
  }

  Future<void> remove(String societyId, String id) async {
    await db
        .from('saved_report_definitions')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }
}

bool _matchesSearch(
    Map<String, Object?> row, List<ReportColumnDef> columns, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = columns
      .where((c) => c.searchable != false)
      .map((c) => row[c.key] == null ? '' : jsString(row[c.key]))
      .join(' ')
      .toLowerCase();
  return hay.contains(q);
}

int _compareValues(Object? a, Object? b, bool ascending) {
  final mul = ascending ? 1 : -1;
  if (a == null && b == null) return 0;
  if (a == null) return -1 * mul;
  if (b == null) return 1 * mul;
  if (a is num && b is num) return a.compareTo(b) * mul;
  return jsLocaleCompare(jsString(a), jsString(b),
          numeric: true, baseOnly: true) *
      mul;
}

double aggregateValues(List<double> values, ReportAggregate agg) {
  if (values.isEmpty) return 0;
  switch (agg) {
    case ReportAggregate.sum:
      return values.fold(0.0, (s, n) => s + n);
    case ReportAggregate.count:
      return values.length.toDouble();
    case ReportAggregate.avg:
      return values.fold(0.0, (s, n) => s + n) / values.length;
    case ReportAggregate.min:
      return values.reduce((a, b) => a < b ? a : b);
    case ReportAggregate.max:
      return values.reduce((a, b) => a > b ? a : b);
  }
}

List<double> _finiteNumbers(Iterable<Object?> values) =>
    [for (final v in values) jsNumber(v)].where((n) => n.isFinite).toList();

List<ReportTotal> computeTotals(
        List<Map<String, Object?>> rows, List<ReportColumnDef> columns) =>
    [
      for (final c in columns)
        if (c.aggregate != null)
          ReportTotal(
            key: c.key,
            label: c.label,
            value: aggregateValues(
                _finiteNumbers(rows.map((r) => r[c.key])), c.aggregate!),
            aggregate: c.aggregate!,
          ),
    ];

List<Map<String, Object?>> groupRows(List<Map<String, Object?>> rows,
    List<ReportColumnDef> columns, List<String> groupBy) {
  if (groupBy.isEmpty) return rows;
  final groupCols = columns.where((c) => groupBy.contains(c.key)).toList();
  final hasAgg = columns.any((c) => c.aggregate != null);
  final groups = <String, List<Map<String, Object?>>>{};
  for (final r in rows) {
    final key = groupCols.map((c) => jsString(r[c.key])).join('||');
    groups.putIfAbsent(key, () => []).add(r);
  }
  final out = <Map<String, Object?>>[];
  for (final group in groups.values) {
    final first = group.first;
    final row = <String, Object?>{'id': 'grp-${out.length}'};
    for (final c in columns) {
      if (groupBy.contains(c.key)) {
        row[c.key] = first[c.key];
      } else if (c.aggregate != null) {
        row[c.key] = aggregateValues(
            _finiteNumbers(group.map((r) => r[c.key])), c.aggregate!);
      } else if (hasAgg) {
        row[c.key] = group.length > 1 ? '${group.length} rows' : first[c.key];
      } else {
        row[c.key] = first[c.key];
      }
    }
    out.add(row);
  }
  return out;
}

List<ReportColumnDef> resolveColumns(
    ReportDefinition def, List<String>? requested) {
  if (requested == null || requested.isEmpty)
    return def.columns.where((c) => c.defaultVisible != false).toList();
  final byKey = {for (final c in def.columns) c.key: c};
  return [
    for (final k in requested)
      if (byKey[k] != null) byKey[k]!
  ];
}

class ReportService {
  ReportService(
      {MetadataLoader? loader,
      ReportRowSource? source,
      SavedReportRepository? saved})
      : loader = loader ?? MetadataLoader(),
        source = source ?? const SupabaseReportRowSource(),
        savedRepo = saved ?? const SavedReportRepository();

  final MetadataLoader loader;
  final ReportRowSource source;
  final SavedReportRepository savedRepo;

  List<ReportDefinition> listCatalog(bool Function(String key) permissions) =>
      loader.list().where((d) => permissions(d.permission)).toList();

  ReportDefinition getDefinition(String reportId) => loader.require(reportId);

  Future<ReportResult> run(ReportRequest request) async {
    final def = loader.require(request.reportId);
    if (!request.permissions(def.permission))
      throw StateError('Permission denied for report: ${def.id}');
    if (request.societyId.isEmpty) throw StateError('societyId is required');

    final columns = resolveColumns(def, request.columns);
    final keys = [for (final c in columns) c.key];
    var rows = await source.fetchRows(
      definition: def,
      societyId: request.societyId,
      filters: request.filters,
      sort: request.sort,
      columnKeys: keys,
    );
    final search = request.search?.trim() ?? '';
    if (search.isNotEmpty)
      rows = rows.where((r) => _matchesSearch(r, columns, search)).toList();

    final groupBy = (request.groupBy?.isNotEmpty ?? false)
        ? request.groupBy!
        : (def.defaultGroupBy ?? const <String>[]);
    final grouped = groupBy.isNotEmpty;
    if (grouped) rows = groupRows(rows, columns, groupBy);

    final sort = request.sort ?? def.defaultSort;
    if (sort != null) {
      var sortKey = sort.field;
      for (final c in columns) {
        if (c.key == sort.field || c.field == sort.field) {
          sortKey = c.key;
          break;
        }
      }
      rows = [
        ...rows
      ]..sort((a, b) => _compareValues(a[sortKey], b[sortKey], sort.ascending));
    }

    final totals = computeTotals(rows, columns);
    final pageSize =
        (request.pageSize ?? def.defaultPageSize ?? 50).clamp(1, 1 << 30);
    final page = (request.page ?? 1) < 1 ? 1 : (request.page ?? 1);
    final totalRows = rows.length;
    final totalPages = totalRows == 0 ? 1 : (totalRows / pageSize).ceil();
    final start = (page - 1) * pageSize;
    final pageRows = start >= rows.length
        ? <Map<String, Object?>>[]
        : rows.sublist(start, (start + pageSize).clamp(0, rows.length));

    return ReportResult(
      reportId: def.id,
      title: def.title,
      columns: columns,
      rows: pageRows,
      totals: totals,
      page: page,
      pageSize: pageSize,
      totalRows: totalRows,
      totalPages: totalPages < 1 ? 1 : totalPages,
      grouped: grouped,
    );
  }

  /// Full result set (capped by `rowLimit`) for export.
  Future<ReportResult> runAll(ReportRequest r) => run(ReportRequest(
        reportId: r.reportId,
        societyId: r.societyId,
        permissions: r.permissions,
        columns: r.columns,
        filters: r.filters,
        sort: r.sort,
        search: r.search,
        groupBy: r.groupBy,
        page: 1,
        pageSize: r.pageSize ?? 100000,
      ));

  Future<List<SavedReportDefinition>> listSaved(String societyId,
          [String? reportId]) =>
      savedRepo.listSaved(societyId, reportId);

  Future<SavedReportDefinition> saveDefinition({
    required String societyId,
    required String reportId,
    required String name,
    List<String>? columns,
    ReportFilterValues filters = const {},
    ReportSortDef? sort,
    List<String>? groupBy,
    String? createdBy,
  }) {
    loader.require(reportId);
    if (name.trim().isEmpty) throw StateError('Saved report name is required');
    return savedRepo.save(
      societyId: societyId,
      reportId: reportId,
      name: name,
      columns: columns,
      filters: filters,
      sort: sort,
      groupBy: groupBy,
      createdBy: createdBy,
    );
  }

  Future<void> deleteSaved(String societyId, String id) =>
      savedRepo.remove(societyId, id);
}
