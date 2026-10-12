import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../../../../shared/pdf/report_export.dart';
import '../logic/report_formatters.dart';
import '../widgets/report_ui.dart';
import 'report_export_service.dart';
import 'report_service.dart';
import 'report_types.dart';

/// Export hook registered with the Reports page header Export menu.
typedef ReportExporter = Future<void> Function(ExportFormat format);

/// Port of `MetadataReportEngine.tsx` + `useMetadataReport.ts` (Custom Reports tab).
/// Period and search come from the Reports page so all tabs stay in sync.
class MetadataReportEngine extends StatefulWidget {
  const MetadataReportEngine({
    super.key,
    required this.societyId,
    this.societyName,
    this.adminName = 'Admin',
    required this.permissions,
    required this.periodFrom,
    required this.periodTo,
    this.searchQuery = '',
    this.onExportReady,
    this.service,
  });

  final String societyId;
  final String? societyName;
  final String adminName;
  final bool Function(String key) permissions;
  final String periodFrom;
  final String periodTo;
  final String searchQuery;
  final ValueChanged<ReportExporter?>? onExportReady;
  final ReportService? service;

  @override
  State<MetadataReportEngine> createState() => _MetadataReportEngineState();
}

String? _primaryDateRangeKey(ReportDefinition? def) {
  if (def == null) return null;
  for (final f in def.filters) {
    if (f.key == 'period' && f.type == ReportFilterType.dateRange) return f.key;
  }
  for (final f in def.filters) {
    if (f.type == ReportFilterType.dateRange) return f.key;
  }
  return null;
}

ReportFilterValues _withSyncedPeriod(
    ReportFilterValues base, ReportDefinition def, String from, String to) {
  final key = _primaryDateRangeKey(def);
  if (key == null || (from.isEmpty && to.isEmpty)) return base;
  return {
    ...base,
    key: DateRangeValue(
        from: from.isEmpty ? null : from, to: to.isEmpty ? null : to)
  };
}

class _MetadataReportEngineState extends State<MetadataReportEngine> {
  late final ReportService _service = widget.service ?? ReportService();
  late List<ReportDefinition> _catalog;
  String _reportId = '';
  ReportDefinition? _def;
  List<String> _selectedColumns = [];
  ReportFilterValues _filters = {};
  ReportSortDef? _sort;
  List<String> _groupBy = [];
  int _page = 1;
  int _pageSize = 50;
  ReportResult? _result;
  bool _loading = false;
  String? _error;
  List<SavedReportDefinition> _saved = [];
  final TextEditingController _saveName = TextEditingController();
  String _debouncedSearch = '';
  Timer? _searchTimer;
  Timer? _textFilterTimer;
  int _runToken = 0;

  @override
  void initState() {
    super.initState();
    _catalog = _service.listCatalog(widget.permissions);
    _debouncedSearch = widget.searchQuery;
    if (_catalog.isNotEmpty) _selectReport(_catalog.first.id, run: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onExportReady?.call(_export);
      _run();
      _refreshSaved();
    });
  }

  @override
  void didUpdateWidget(covariant MetadataReportEngine old) {
    super.didUpdateWidget(old);
    if (old.periodFrom != widget.periodFrom ||
        old.periodTo != widget.periodTo) {
      final key = _primaryDateRangeKey(_def);
      if (key != null) {
        setState(() {
          _filters = {
            ..._filters,
            key: DateRangeValue(
              from: widget.periodFrom.isEmpty ? null : widget.periodFrom,
              to: widget.periodTo.isEmpty ? null : widget.periodTo,
            ),
          };
          _page = 1;
        });
        _run();
      }
    }
    if (old.searchQuery != widget.searchQuery) {
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _debouncedSearch = widget.searchQuery;
          _page = 1;
        });
        _run();
      });
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _textFilterTimer?.cancel();
    _saveName.dispose();
    final cb = widget.onExportReady;
    if (cb != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => cb(null));
    super.dispose();
  }

  void _selectReport(String id,
      {SavedReportDefinition? saved, bool run = true}) {
    final def = _service.getDefinition(id);
    final defaults = <String, Object?>{
      for (final f in def.filters)
        if (f.defaultValue != null) f.key: f.defaultValue,
    };
    void apply() {
      _reportId = id;
      _def = def;
      if (saved != null) {
        _selectedColumns = (saved.columns?.isNotEmpty ?? false)
            ? [...saved.columns!]
            : [
                for (final c in def.columns)
                  if (c.defaultVisible != false) c.key
              ];
        final restored = <String, Object?>{
          for (final e in saved.filters.entries)
            e.key: e.value is Map ? DateRangeValue.fromJson(e.value) : e.value,
        };
        _filters = _withSyncedPeriod(
            restored, def, widget.periodFrom, widget.periodTo);
        _sort = saved.sort ?? def.defaultSort;
        _groupBy = saved.groupBy ?? def.defaultGroupBy ?? [];
      } else {
        _selectedColumns = [
          for (final c in def.columns)
            if (c.defaultVisible != false) c.key
        ];
        _filters = _withSyncedPeriod(
            defaults, def, widget.periodFrom, widget.periodTo);
        _sort = def.defaultSort;
        _groupBy = [...?def.defaultGroupBy];
      }
      _page = 1;
      _pageSize = def.defaultPageSize ?? 50;
      _result = null;
      _error = null;
    }

    if (run) {
      setState(apply);
      _run();
      _refreshSaved();
    } else {
      apply();
    }
  }

  ReportRequest _request({bool forExport = false}) => ReportRequest(
        reportId: _reportId,
        societyId: widget.societyId,
        permissions: widget.permissions,
        columns: _selectedColumns,
        filters: _filters,
        sort: _sort,
        search: _debouncedSearch,
        groupBy: _groupBy.isEmpty ? null : _groupBy,
        page: forExport ? 1 : _page,
        pageSize: forExport ? null : _pageSize,
      );

  Future<void> _run() async {
    if (widget.societyId.isEmpty ||
        _reportId.isEmpty ||
        _selectedColumns.isEmpty) return;
    final token = ++_runToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.run(_request());
      if (!mounted || token != _runToken) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted || token != _runToken) return;
      setState(() {
        _result = null;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted && token == _runToken) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSaved() async {
    if (widget.societyId.isEmpty) return;
    try {
      final list = await _service.listSaved(
          widget.societyId, _reportId.isEmpty ? null : _reportId);
      if (mounted) setState(() => _saved = list);
    } catch (_) {
      if (mounted) setState(() => _saved = []);
    }
  }

  Future<void> _export(ExportFormat format) async {
    if (widget.societyId.isEmpty || _reportId.isEmpty) return;
    final result = await _service.runAll(_request(forExport: true));
    final ctx = await resolveLetterheadReportContext(widget.societyId);
    final file = await exportReportResult(
      result,
      format,
      societyName: widget.societyName ?? ctx?.letterhead?.name,
      filenameBase: '$_reportId-report',
      letterhead: ctx?.letterhead,
      pdfMode: ctx?.mode ?? ReportPdfMode.letterhead,
    );
    await shareExportFile(file.bytes, file.filename, format);
  }

  void _setFilter(String key, Object? value) {
    setState(() {
      final next = {..._filters};
      final blank = value == null ||
          value == '' ||
          (value is DateRangeValue && value.isEmpty);
      if (blank) {
        next.remove(key);
      } else {
        next[key] = value;
      }
      _filters = next;
      _page = 1;
    });
    _run();
  }

  void _toggleColumn(String key) {
    setState(() {
      if (_selectedColumns.contains(key)) {
        if (_selectedColumns.length > 1)
          _selectedColumns = _selectedColumns.where((k) => k != key).toList();
      } else {
        _selectedColumns = [..._selectedColumns, key];
      }
      _page = 1;
    });
    _run();
  }

  Future<void> _save() async {
    final name = _saveName.text.trim();
    if (name.isEmpty) return;
    try {
      await _service.saveDefinition(
        societyId: widget.societyId,
        reportId: _reportId,
        name: name,
        columns: _selectedColumns,
        filters: _filters,
        sort: _sort,
        groupBy: _groupBy.isEmpty ? null : _groupBy,
        createdBy: widget.adminName,
      );
      _saveName.clear();
      await _refreshSaved();
      if (mounted)
        AppFeedback.toast(context,
            context.tr('Report definition saved', 'प्रतिवेदन परिभाषा सहेजी गई'),
            tone: BadgeTone.success);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(
            context, '${context.tr('Save failed', 'सहेजना विफल')}: $e',
            tone: BadgeTone.alert);
    }
  }

  Future<void> _deleteSaved(SavedReportDefinition s) async {
    try {
      await _service.deleteSaved(widget.societyId, s.id);
      await _refreshSaved();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _openColumns() async {
    final def = _def;
    if (def == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(ctx.tr('Columns', 'कॉलम'),
                      style: AppText.sectionTitle(ctx)),
                ),
                for (final c in def.columns)
                  CheckboxListTile(
                    dense: true,
                    value: _selectedColumns.contains(c.key),
                    title: Text(c.label),
                    onChanged: (_) {
                      _toggleColumn(c.key);
                      setSt(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterField(ReportFilterDef f) {
    final label = f.label;
    switch (f.type) {
      case ReportFilterType.dateRange:
        final v =
            DateRangeValue.fromJson(_filters[f.key]) ?? const DateRangeValue();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: AppText.tiny(context)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: ReportDateField(
                    label: context.tr('From', 'से'),
                    value: v.from ?? '',
                    onChanged: (x) =>
                        _setFilter(f.key, DateRangeValue(from: x, to: v.to)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ReportDateField(
                    label: context.tr('To', 'तक'),
                    value: v.to ?? '',
                    onChanged: (x) =>
                        _setFilter(f.key, DateRangeValue(from: v.from, to: x)),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Clear', 'साफ़ करें'),
                  onPressed: v.isEmpty ? null : () => _setFilter(f.key, null),
                  icon: const Icon(Icons.clear, size: 18),
                ),
              ]),
            ]);
      case ReportFilterType.select:
        final items = ['', ...?f.options?.map((o) => o.value)];
        final cur = (_filters[f.key] ?? '').toString();
        return AppDropdown<String>(
          label: label,
          items: items,
          value: items.contains(cur) ? cur : '',
          labelOf: (v) => v.isEmpty
              ? context.tr('All', 'सभी')
              : f.options!.firstWhere((o) => o.value == v).label,
          onChanged: (v) =>
              _setFilter(f.key, (v == null || v.isEmpty) ? null : v),
        );
      case ReportFilterType.boolean:
        final cur = _filters[f.key] == true
            ? 'true'
            : (_filters[f.key] == false ? 'false' : '');
        return AppDropdown<String>(
          label: label,
          items: const ['', 'true', 'false'],
          value: cur,
          labelOf: (v) => v.isEmpty
              ? context.tr('All', 'सभी')
              : (v == 'true'
                  ? context.tr('Yes', 'हाँ')
                  : context.tr('No', 'नहीं')),
          onChanged: (v) =>
              _setFilter(f.key, (v == null || v.isEmpty) ? null : v == 'true'),
        );
      case ReportFilterType.text:
      case ReportFilterType.number:
      case ReportFilterType.date:
        return AppTextField(
          key: ValueKey('filter-$_reportId-${f.key}'),
          label: label,
          caps: false,
          initialValue: (_filters[f.key] ?? '').toString(),
          keyboardType:
              f.type == ReportFilterType.number ? TextInputType.number : null,
          onChanged: (v) {
            _textFilterTimer?.cancel();
            _textFilterTimer = Timer(const Duration(milliseconds: 350), () {
              if (mounted) _setFilter(f.key, v.isEmpty ? null : v);
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_catalog.isEmpty) {
      return ReportPanel(
        child: Text(
            context.tr('No reports available for your role.',
                'आपकी भूमिका के लिए कोई प्रतिवेदन उपलब्ध नहीं।'),
            style: AppText.caption(context)),
      );
    }
    final def = _def;
    final syncedKey = _primaryDateRangeKey(def);
    final extraFilters = [
      for (final f in def?.filters ?? const <ReportFilterDef>[])
        if (f.type != ReportFilterType.dateRange || f.key != syncedKey) f,
    ];
    final result = _result;
    final colLabel = {
      for (final c in def?.columns ?? const <ReportColumnDef>[]) c.key: c.label
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: AppDropdown<String>(
              label: context.tr('Report', 'प्रतिवेदन'),
              items: [for (final r in _catalog) r.id],
              value: _reportId,
              labelOf: (id) => _catalog.firstWhere((r) => r.id == id).title,
              onChanged: (v) {
                if (v != null && v != _reportId) _selectReport(v);
              },
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(context.tr('Updating…', 'अपडेट हो रहा है…'),
                  style: AppText.tiny(context)),
            ),
        ]),
        if ((def?.description ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${def!.description} · ${context.tr('Period synced with report month above', 'अवधि ऊपर के प्रतिवेदन माह से समन्वित')}',
              style: AppText.caption(context),
            ),
          ),
        if (extraFilters.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReportPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('Filters', 'फ़िल्टर'),
                      style:
                          AppText.bodyMedium(context).copyWith(fontSize: 12)),
                  for (final f in extraFilters)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _filterField(f)),
                ]),
          ),
        ],
        if (def != null) ...[
          const SizedBox(height: 12),
          ReportPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FieldLabel(context.tr('Columns', 'कॉलम')),
                            AppButton.secondary(
                              label:
                                  context.tr('Toggle column…', 'कॉलम चुनें…'),
                              icon: Icons.view_column_outlined,
                              dense: true,
                              onPressed: _openColumns,
                            ),
                          ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppDropdown<String>(
                        label: context.tr('Group by', 'समूह द्वारा'),
                        items: ['', for (final c in def.columns) c.key],
                        value: _groupBy.isEmpty ? '' : _groupBy.first,
                        labelOf: (k) => k.isEmpty
                            ? context.tr('None', 'कोई नहीं')
                            : colLabel[k] ?? k,
                        onChanged: (v) {
                          setState(() =>
                              _groupBy = (v == null || v.isEmpty) ? [] : [v]);
                          _run();
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('Showing', 'दिखाए गए')}: ${_selectedColumns.map((k) => colLabel[k] ?? k).join(', ')}',
                    style: AppText.tiny(context),
                  ),
                ]),
          ),
        ],
        const SizedBox(height: 12),
        ReportPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.bookmark_border, size: 14, color: t.foreground),
              const SizedBox(width: 4),
              Text(context.tr('Saved views', 'सहेजे गए दृश्य'),
                  style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _saveName,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          context.tr('Name this view…', 'इस दृश्य का नाम…')),
                ),
              ),
              const SizedBox(width: 8),
              AppButton.secondary(
                label: context.t('common.save'),
                dense: true,
                expand: false,
                onPressed: _saveName.text.trim().isEmpty ? null : _save,
              ),
            ]),
            for (final s in _saved)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.secondary, 0.5),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectReport(s.reportId, saved: s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(s.name,
                            style:
                                AppText.body(context).copyWith(fontSize: 12)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr(
                        'Delete saved report', 'सहेजा प्रतिवेदन हटाएं'),
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: t.mutedForeground),
                    onPressed: () => _deleteSaved(s),
                  ),
                ]),
              ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          NoticeBanner(
              message: _error!,
              tone: BadgeTone.alert,
              icon: Icons.error_outline),
        ],
        if (result != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                [
                  '${result.totalRows} ${context.tr(result.totalRows == 1 ? 'row' : 'rows', 'पंक्तियाँ')}',
                  if (result.grouped) context.tr(' (grouped)', ' (समूहित)'),
                  if (result.totals.isNotEmpty)
                    ' · ${result.totals.map((x) => '${x.label} ${moneyInr(x.value)}').join(' · ')}',
                ].join(),
                style: AppText.caption(context),
              ),
            ),
            IconPillButton(
              icon: Icons.chevron_left,
              onPressed: _page <= 1
                  ? null
                  : () {
                      setState(() => _page = _page - 1);
                      _run();
                    },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('${result.page} / ${result.totalPages}',
                  style: AppText.tiny(context).copyWith(fontSize: 11)),
            ),
            IconPillButton(
              icon: Icons.chevron_right,
              onPressed: _page >= result.totalPages
                  ? null
                  : () {
                      setState(() => _page = _page + 1);
                      _run();
                    },
            ),
          ]),
          const SizedBox(height: 8),
          CardSection(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                horizontalMargin: 10,
                columnSpacing: 16,
                headingRowColor:
                    WidgetStatePropertyAll(AppTokens.tint(t.secondary, 0.4)),
                headingTextStyle: AppText.caption(context)
                    .copyWith(fontWeight: FontWeight.w600),
                dataTextStyle: AppText.body(context).copyWith(fontSize: 12),
                columns: [
                  for (final c in result.columns)
                    DataColumn(
                      numeric: c.isNumeric,
                      label: c.sortable != false
                          ? InkWell(
                              onTap: () {
                                final same = _sort?.field == c.field ||
                                    _sort?.field == c.key;
                                setState(() => _sort = ReportSortDef(
                                    field: c.field,
                                    ascending:
                                        same ? !(_sort!.ascending) : true));
                                _run();
                              },
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.label),
                                    if (_sort?.field == c.field ||
                                        _sort?.field == c.key)
                                      Icon(
                                          _sort!.ascending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          size: 12),
                                  ]),
                            )
                          : Text(c.label),
                    ),
                ],
                rows: result.rows.isEmpty
                    ? [
                        DataRow(cells: [
                          DataCell(Text(
                              context.tr('No rows match the current filters.',
                                  'वर्तमान फ़िल्टर से कोई पंक्ति मेल नहीं खाती।'),
                              style: AppText.caption(context))),
                          for (var i = 1; i < result.columns.length; i++)
                            const DataCell(SizedBox()),
                        ]),
                      ]
                    : [
                        for (final row in result.rows)
                          DataRow(cells: [
                            for (final c in result.columns)
                              DataCell(Text(
                                formatReportCell(c, row[c.key]),
                                style: c.isNumeric
                                    ? const TextStyle(fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ])
                                    : null,
                              )),
                          ]),
                      ],
              ),
            ),
          ),
        ] else if (_loading) ...[
          const SizedBox(height: 12),
          const LoadingView(),
        ],
      ],
    );
  }
}
