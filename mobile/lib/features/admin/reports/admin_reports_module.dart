import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../shared/pdf/letterhead_report_engine.dart';
import '../../../shared/pdf/report_export.dart';
import '../../../shared/pdf/report_pdf_actions.dart';
import '../core/admin_module.dart';
import 'data/report_models.dart';
import 'data/reports_repository.dart';
import 'engine/metadata_report_engine.dart';
import 'export/monthly_report_export.dart';
import 'logic/finance_period_report.dart';
import 'logic/flat_report.dart';
import 'logic/js_compat.dart';
import 'logic/metric_copy.dart';
import 'logic/report_aggregations.dart';
import 'logic/report_formatters.dart';
import 'logic/report_query_filter.dart';
import 'widgets/cash_flow_statement_view.dart';
import 'widgets/finance_period_head_tables.dart';
import 'widgets/finance_period_report_send_panel.dart';
import 'widgets/flat_report_view.dart';
import 'widgets/report_detail_sheet.dart';
import 'widgets/report_ui.dart';

enum _ReportTab { financial, visitor, vehicle, allModules, engine }

enum _FinancialKind { collectionReceipts, expenses, flatWise, cashFlow, donationStatuses }

const Map<_FinancialKind, String> _kindKey = {
  _FinancialKind.collectionReceipts: 'reports.kind.collectionReceipts',
  _FinancialKind.expenses: 'reports.kind.expenses',
  _FinancialKind.flatWise: 'reports.kind.flatWise',
  _FinancialKind.cashFlow: 'reports.kind.cashFlow',
  _FinancialKind.donationStatuses: 'reports.kind.donationStatuses',
};

/// Admin → Reports (web `ReportPage.tsx`): financial period reports (head-wise
/// receipts / expenses, flat-wise, cash flow, donations), visitor / vehicle /
/// all-modules summaries, the metadata-driven Custom Reports engine, shared
/// search, drill-down sheets and PDF (letterhead / plain) / Excel / Word / CSV /
/// WhatsApp exports.
class AdminReportsModule extends StatefulWidget {
  const AdminReportsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminReportsModule> createState() => _AdminReportsModuleState();
}

class _AdminReportsModuleState extends State<AdminReportsModule> {
  AdminModuleContext get ctx => widget.ctx;

  _ReportTab _tab = _ReportTab.financial;
  List<_FinancialKind> _kinds = [_FinancialKind.collectionReceipts];
  late final TextEditingController _search = TextEditingController(text: ctx.initialQuery ?? '');
  String get _q => _search.text;

  String _reportMonth = ymOf(DateTime.now());
  bool _monthlyMode = true;
  String _customFrom = defaultFinancePeriodFrom();
  String _customTo = defaultFinancePeriodTo();
  String _flatFrom = '';
  String _flatTo = '';
  String _flatSelected = 'all';

  // Data
  bool _financeLoading = true;
  Object? _financeError;
  ReportFinanceData _finance = ReportFinanceData.empty;
  List<FinanceOpeningBalanceAnchor> _anchors = const [];
  ReportModuleAggregations _aggregations = ReportModuleAggregations.empty;
  String _aggKey = '';
  FlatReportSource? _flatSource;
  bool _flatLoading = false;
  List<ReportShiftRow> _shifts = const [];
  List<ReportVisitor> _monthVisitors = const [];
  bool _monthLoading = true;
  String _loadedMonth = '';
  ReportExporter? _engineExporter;

  @override
  void initState() {
    super.initState();
    final r = _statementRange;
    _flatFrom = r.from;
    _flatTo = r.to;
    _loadFinance();
    _loadMonth();
    _loadAggregations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ─── Periods ──────────────────────────────────────────────────────────────

  ({String from, String to}) get _monthRange => financeReportingMonthRange(_reportMonth);

  ({String from, String to}) get _statementRange =>
      _monthlyMode ? _monthRange : (from: _customFrom, to: _customTo);

  String get _statementLabel => _monthlyMode
      ? fmtIsoMonthToDisplay(_reportMonth)
      : '${fmtIsoDateToDisplay(_customFrom)} – ${fmtIsoDateToDisplay(_customTo)}';

  bool get _periodInvalid => _statementRange.from.compareTo(_statementRange.to) > 0;

  void _onStatementPeriodChanged() {
    final r = _statementRange;
    _flatFrom = r.from;
    _flatTo = r.to;
    _loadAggregations();
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Future<void> _loadFinance() async {
    setState(() {
      _financeLoading = true;
      _financeError = null;
    });
    try {
      final results = await Future.wait<Object>([
        ReportsRepository.loadFinanceCore(ctx.societyId),
        ReportsRepository.loadOpeningAnchors(ctx.societyId),
      ]);
      if (!mounted) return;
      setState(() {
        _finance = results[0] as ReportFinanceData;
        _anchors = results[1] as List<FinanceOpeningBalanceAnchor>;
      });
    } catch (e) {
      if (mounted) setState(() => _financeError = e);
    } finally {
      if (mounted) setState(() => _financeLoading = false);
    }
  }

  Future<void> _loadMonth() async {
    final ym = _reportMonth;
    setState(() => _monthLoading = true);
    try {
      final range = _monthRange;
      final results = await Future.wait<Object>([
        ReportsRepository.loadShifts(ctx.societyId, range.from, range.to),
        ReportsRepository.loadVisitorsForMonth(ctx.societyId, ym),
      ]);
      if (!mounted || ym != _reportMonth) return;
      setState(() {
        _shifts = results[0] as List<ReportShiftRow>;
        _monthVisitors = results[1] as List<ReportVisitor>;
        _loadedMonth = ym;
      });
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('mobile.loadFailed'), tone: BadgeTone.alert);
    } finally {
      if (mounted && ym == _reportMonth) setState(() => _monthLoading = false);
    }
  }

  Future<void> _loadAggregations({bool force = false}) async {
    final r = _statementRange;
    final key = '${r.from}|${r.to}';
    if (!force && key == _aggKey) return;
    _aggKey = key;
    if (r.from.compareTo(r.to) > 0) {
      setState(() => _aggregations = ReportModuleAggregations.empty);
      return;
    }
    try {
      final a = await ReportsRepository.loadModuleAggregations(ctx.societyId, r.from, r.to);
      if (mounted && key == _aggKey) setState(() => _aggregations = a);
    } catch (_) {}
  }

  Future<void> _ensureFlatReport({bool force = false}) async {
    if (_flatLoading || (_flatSource != null && !force)) return;
    setState(() => _flatLoading = true);
    try {
      final s = await ReportsRepository.loadFlatReportSource(ctx.societyId);
      if (mounted) setState(() => _flatSource = s);
    } catch (_) {
      if (mounted) setState(() => _flatSource = const FlatReportSource());
    } finally {
      if (mounted) setState(() => _flatLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadFinance(),
      _loadMonth(),
      _loadAggregations(force: true),
      if (_flatSource != null) _ensureFlatReport(force: true),
    ]);
  }

  // ─── Derived data ─────────────────────────────────────────────────────────

  List<ReportVisitor> get _displayVisitors => filterVisitorRows(_monthVisitors, _q);

  List<ReportVisitor> get _displayVehicles => _displayVisitors.where((v) => v.hasVehicle).toList();

  List<ReportShiftRow> get _searchedShifts => filterShiftRows(_shifts, _q);

  FinancePeriodReportResult? get _periodReport => _periodInvalid
      ? null
      : computeFinancePeriodReport(
          periodFrom: _statementRange.from,
          periodTo: _statementRange.to,
          payments: _finance.payments,
          ledgerEntries: _finance.societyLedgerEntries,
          expenseCategoryById: _finance.expenseCategoryById,
          openingBalanceAnchors: _anchors,
        );

  List<FinancePeriodLedgerEntry> get _periodEntries => _periodInvalid
      ? const []
      : filterLedgerByTransactionDateRange(_finance.societyLedgerEntries, _statementRange.from, _statementRange.to);

  List<FinancePeriodLedgerEntry> get _searchedPeriodEntries => filterLedgerEntries(_periodEntries, _q);

  List<FinancePeriodLedgerEntry> get _monthEntries {
    final r = _monthRange;
    return _finance.societyLedgerEntries.where((e) {
      final d = e.ledgerDate;
      return d.isNotEmpty && _inRange(d, r.from, r.to);
    }).toList();
  }

  static bool _inRange(String d, String from, String to) => jsDateMs(d) != null && d.isNotEmpty && _dateIn(d, from, to);

  static bool _dateIn(String iso, String from, String to) {
    final t = jsDateMs(iso), a = localDayStartMs(from), b = localDayEndMs(to);
    return t != null && a != null && b != null && t >= a && t <= b;
  }

  List<FinancePeriodLedgerEntry> get _searchedMonthEntries => filterLedgerEntries(_monthEntries, _q);

  ReportExportContext _exportContext() {
    final searched = _searchedPeriodEntries;
    final groups = computeLedgerInflowGroups(searched);
    final report = _periodReport;
    final visitors = _displayVisitors;
    return ReportExportContext(
      societyName: _societyName,
      reportMonth: _statementLabel,
      tab: switch (_tab) {
        _ReportTab.financial => MonthlyReportTab.financial,
        _ReportTab.visitor => MonthlyReportTab.visitor,
        _ReportTab.vehicle => MonthlyReportTab.vehicle,
        _ => MonthlyReportTab.allModules,
      },
      financeEntries: searched,
      financeGroups: groups,
      financeMonthTotal: groups.fold<double>(0, (s, g) => s + g.total),
      reportMonthNet: report,
      periodReport: report,
      visitors: visitors,
      visitorStats: ReportVisitorStats.of(visitors),
    );
  }

  String get _societyName {
    if (_finance.societyName.isNotEmpty) return _finance.societyName;
    return ctx.societyName.isNotEmpty ? ctx.societyName : 'Society';
  }

  String get _tabId => switch (_tab) {
        _ReportTab.financial => 'financial',
        _ReportTab.visitor => 'visitor',
        _ReportTab.vehicle => 'vehicle',
        _ReportTab.allModules => 'all_modules',
        _ReportTab.engine => 'engine',
      };

  String _fileLabel() => _statementLabel.replaceAll(RegExp(r'\s+'), '-').replaceAll('/', '-');

  // ─── Exports ──────────────────────────────────────────────────────────────

  Future<Uint8List> _buildPdf(ReportPdfMode mode, SocietyLetterhead? lh) =>
      buildMonthlyReportPdf(_exportContext().withPdf(lh, mode));

  Future<Uint8List> _shareBytes() async {
    final c = await resolveLetterheadReportContext(ctx.societyId);
    return _buildPdf(c?.mode ?? ReportPdfMode.letterhead, c?.letterhead);
  }

  Future<void> _export(ExportFormat format) async {
    if (_tab == _ReportTab.engine) {
      try {
        await _engineExporter?.call(format);
      } catch (e) {
        if (mounted) AppFeedback.toast(context, '${context.tr('Export failed', 'निर्यात विफल')}: $e', tone: BadgeTone.alert);
      }
      return;
    }
    try {
      if (format == ExportFormat.pdf) {
        final c = await resolveLetterheadReportContext(ctx.societyId);
        if (!mounted) return;
        if (c?.warning != null) AppFeedback.toast(context, letterheadWarningText(context), tone: BadgeTone.warning);
        final bytes = await _buildPdf(c?.mode ?? ReportPdfMode.letterhead, c?.letterhead);
        if (!mounted) return;
        await SocietyPdfOutput.preview(context, bytes, '$_tabId-report-${_fileLabel()}.pdf');
        return;
      }
      final file = await buildMonthlyReportFile(format, _exportContext());
      await shareExportFile(file.bytes, file.filename, format);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '${context.tr('Export failed', 'निर्यात विफल')}: $e', tone: BadgeTone.alert);
    }
  }

  // ─── Detail sheets ────────────────────────────────────────────────────────

  void _openSheet(String title, String subtitle, List<ReportDetailRow> rows, {double? total}) {
    ReportDetailSheet.show(
      context,
      ReportDetailLayer(title: title, subtitle: subtitle, totalAmount: total, rows: rows),
      initialSearchQuery: _q,
      societyName: _societyName,
    );
  }

  void _openMonthFinance() {
    final entries = _searchedMonthEntries;
    final total = entries.fold<double>(0, (s, e) => s + e.totalAmount);
    _openSheet(
      context.tr('Finance — All Entries', 'वित्त — सभी प्रविष्टियाँ'),
      context.tr('All finance entries for ${fmtIsoMonthToDisplay(_reportMonth)}', '${fmtIsoMonthToDisplay(_reportMonth)} की सभी वित्त प्रविष्टियाँ'),
      [
        for (final e in entries)
          ReportDetailRow(
            id: e.id,
            label: '${formatLedgerFieldLabel(e.recordMode)} → ${formatLedgerFieldLabel(e.destination)}',
            sublabel: 'Flats: ${jsNumberString(e.aggregateFlatCount)} | Method: ${(e.paymentMethod ?? '').isEmpty ? 'N/A' : e.paymentMethod}',
            amount: e.totalAmount,
            date: fmtDate(e.ledgerDate),
            dateIso: e.ledgerDate,
            status: e.paymentStatus,
          ),
      ],
      total: total,
    );
  }

  void _openVisitors() => _openSheet(
        context.tr('Visitors — Detail', 'आगंतुक — विवरण'),
        context.tr('All visitors for $_reportMonth', '$_reportMonth के सभी आगंतुक'),
        [
          for (final v in _displayVisitors.where((v) => v.category == 'visitor'))
            ReportDetailRow(
              id: v.id,
              label: v.name,
              sublabel: 'Flat ${v.flatNumber} · ${v.purpose}',
              date: fmtDateTime(v.entryTime),
              extra: v.isInside ? 'Still inside' : 'Out: ${fmtDateTime(v.exitTime)}',
              status: v.isInside ? 'inside' : 'exited',
            ),
        ],
      );

  void _openVehicles() => _openSheet(
        context.tr('Vehicles — Detail', 'वाहन — विवरण'),
        context.tr('All vehicle entries for $_reportMonth', '$_reportMonth की सभी वाहन प्रविष्टियाँ'),
        [
          for (final v in _displayVehicles)
            ReportDetailRow(
              id: v.id,
              label: v.vehicleNumber ?? 'N/A',
              sublabel: '${v.name} · Flat ${v.flatNumber}',
              date: fmtDateTime(v.entryTime),
              extra: v.category,
              status: v.isInside ? 'inside' : 'exited',
            ),
        ],
      );

  void _openDeliveries() => _openSheet(
        context.tr('Deliveries & Services — Detail', 'वितरण व सेवाएँ — विवरण'),
        context.tr('All delivery/service entries for $_reportMonth', '$_reportMonth की सभी वितरण/सेवा प्रविष्टियाँ'),
        [
          for (final v in _displayVisitors.where((v) => v.category == 'delivery' || v.category == 'service'))
            ReportDetailRow(
              id: v.id,
              label: v.name,
              sublabel: 'Flat ${v.flatNumber} · ${v.purpose}',
              date: fmtDateTime(v.entryTime),
              extra: v.vehicleNumber,
              status: v.isInside ? 'inside' : 'exited',
            ),
        ],
      );

  void _openShifts() => _openSheet(
        context.tr('Guard Shifts — Detail', 'गार्ड पारी — विवरण'),
        context.tr('All guard shifts for $_reportMonth', '$_reportMonth की सभी गार्ड पारियाँ'),
        [
          for (final s in _searchedShifts)
            ReportDetailRow(
              id: s.id,
              label: s.guardName,
              sublabel: 'Guard ID: ${s.guardId}',
              date: '${fmtDate(s.loginTime)}, ${fmtTime(s.loginTime)}',
              extra: s.logoutTime != null ? 'Out: ${fmtTime(s.logoutTime)}' : 'Active',
              status: s.logoutTime != null ? 'completed' : 'active',
            ),
        ],
      );

  void _openDonations() {
    final d = _aggregations.donationStatuses;
    _openSheet(
      context.tr('Donations — Summary', 'दान — सारांश'),
      context.tr('Donation payments for $_statementLabel', '$_statementLabel के दान भुगतान'),
      [
        for (var i = 0; i < d.length; i++)
          ReportDetailRow(
            id: 'don-$i',
            label: 'Donations — ${d[i].status}',
            sublabel: '${d[i].count} payment(s)',
            amount: d[i].total,
            status: d[i].status,
          ),
      ],
      total: d.fold<double>(0, (s, x) => s + x.total),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  String _searchHint() => switch (_tab) {
        _ReportTab.financial => context.t('report.searchPlaceholderFinancial'),
        _ReportTab.visitor => context.t('report.searchPlaceholderVisitor'),
        _ReportTab.vehicle => context.t('report.searchPlaceholderVehicle'),
        _ReportTab.engine => rs(context, 'reports.searchCustom'),
        _ReportTab.allModules => context.t('report.searchPlaceholderAll'),
      };

  String? _searchSummary() {
    if (_q.trim().isEmpty) return null;
    final hi = isHindi(context);
    switch (_tab) {
      case _ReportTab.financial:
        final a = _searchedPeriodEntries.length, b = _periodEntries.length;
        return hi ? '$b में से $a खाता-बही प्रविष्टियाँ मेल खाती हैं' : '$a of $b ledger entries match';
      case _ReportTab.visitor:
        final a = _displayVisitors.length, b = _monthVisitors.length;
        return hi ? '$b में से $a प्रविष्टियाँ मेल खाती हैं' : '$a of $b entries match';
      case _ReportTab.vehicle:
        final a = _displayVehicles.length, b = _monthVisitors.where((v) => v.hasVehicle).length;
        return hi ? '$b में से $a वाहन प्रविष्टियाँ मेल खाती हैं' : '$a of $b vehicle entries match';
      case _ReportTab.allModules:
        final f = _searchedMonthEntries.length, v = _displayVisitors.length, s = _searchedShifts.length;
        return hi ? '$f वित्त · $v आगंतुक · $s पारियाँ मेल खाती हैं' : '$f finance · $v visitors · $s shifts match';
      case _ReportTab.engine:
        return hi ? 'कस्टम प्रतिवेदन पंक्तियाँ फ़िल्टर हो रही हैं…' : 'Filtering custom report rows…';
    }
  }

  void _toggleKind(_FinancialKind k) {
    setState(() {
      _tab = _ReportTab.financial;
      if (_kinds.contains(k)) {
        if (_kinds.length > 1) _kinds = _kinds.where((x) => x != k).toList();
      } else {
        _kinds = _FinancialKind.values.where((x) => x == k || _kinds.contains(x)).toList();
      }
    });
    if (_kinds.contains(_FinancialKind.flatWise)) _ensureFlatReport();
  }

  Future<void> _openFinancialMenu() async {
    setState(() => _tab = _ReportTab.financial);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSt) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(rs(sheetCtx, 'reports.tab.financial'), style: AppText.sectionTitle(sheetCtx)),
              ),
            ),
            for (final k in _FinancialKind.values)
              CheckboxListTile(
                dense: true,
                value: _kinds.contains(k),
                title: Text(rs(sheetCtx, _kindKey[k]!), style: const TextStyle(fontSize: 13)),
                onChanged: (_) {
                  _toggleKind(k);
                  setSt(() {});
                },
              ),
          ]),
        ),
      ),
    );
  }

  List<String> get _kindLabels => [for (final k in _kinds) rs(context, _kindKey[k]!)];

  Widget _headerActions() {
    final engine = _tab == _ReportTab.engine;
    final filename = '$_tabId-report-${_fileLabel()}.pdf';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ReportPdfActionsButton(
            societyId: ctx.societyId,
            filename: filename,
            buildPdf: _buildPdf,
            label: rs(context, 'reports.generate'),
          ),
          ExportFormatMenuButton(
            label: context.tr('Export', 'निर्यात'),
            onExport: _export,
            formats: engine
                ? const [ExportFormat.excel, ExportFormat.csv, ExportFormat.pdf]
                : const [ExportFormat.excel, ExportFormat.word, ExportFormat.csv],
          ),
          if (!engine)
            SharePdfWhatsAppButton(
              label: rs(context, 'reports.shareWhatsApp'),
              filename: filename,
              message: '$_societyName — $_statementLabel report',
              getBytes: _shareBytes,
            ),
          MonthPickerButton(
            value: _reportMonth,
            minMonth: kFinanceReportingEarliestMonth,
            onChanged: _setMonth,
          ),
        ],
      ),
    );
  }

  void _setMonth(String v) {
    setState(() => _reportMonth = v);
    _loadMonth();
    if (_monthlyMode) _onStatementPeriodChanged();
  }

  Widget _searchCard() {
    final t = context.tokens;
    final summary = _searchSummary();
    return ReportPanel(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.t('report.searchTitle'), style: AppText.bodyMedium(context).copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
            hintText: _searchHint(),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _search.clear()),
                  ),
          ),
        ),
        if (summary != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(summary, style: AppText.tiny(context))),
      ]),
    );
  }

  Widget _tabs() {
    final labels = _kindLabels;
    final finLabel = _tab == _ReportTab.financial
        ? (labels.length == 1 ? '${rs(context, 'reports.tab.financial')}: ${labels.first}' : '${rs(context, 'reports.tab.financial')} (${labels.length})')
        : rs(context, 'reports.tab.financial');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ReportTabPill(
            label: finLabel,
            icon: Icons.currency_rupee,
            trailing: Icons.expand_more,
            selected: _tab == _ReportTab.financial,
            onTap: _openFinancialMenu,
          ),
          for (final (tab, key, icon) in [
            (_ReportTab.visitor, 'reports.tab.visitor', Icons.people_outline),
            (_ReportTab.vehicle, 'reports.tab.vehicle', Icons.directions_car_outlined),
            (_ReportTab.allModules, 'reports.tab.allModules', Icons.assignment_outlined),
            (_ReportTab.engine, 'reports.tab.custom', Icons.table_chart_outlined),
          ]) ...[
            const SizedBox(width: 6),
            ReportTabPill(
              label: rs(context, key),
              icon: icon,
              selected: _tab == tab,
              onTap: () {
                setState(() => _tab = tab);
                if (tab == _ReportTab.allModules) _loadAggregations();
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _financialTab() {
    final t = context.tokens;
    final report = _periodReport;
    final labels = _kindLabels;
    final filename = 'financial-report-${_fileLabel()}.pdf';
    if (_financeError != null && _finance.flats.isEmpty) {
      return ErrorView(onRetry: _loadFinance);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReportPanel(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            labels.length == 1 ? labels.first : context.tr('${labels.length} reports selected', '${labels.length} प्रतिवेदन चुने गए'),
            style: AppText.bodyMedium(context).copyWith(fontSize: 11),
          ),
          Text(
            '${labels.length > 1 ? '${labels.join(' · ')} · $_statementLabel' : _statementLabel} — '
            '${context.tr('PDF opens to view; Share opens WhatsApp', 'PDF देखने हेतु खुलता है; साझा करें से व्हाट्सऐप खुलता है')}',
            style: AppText.tiny(context),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ReportPdfActionsButton(
              societyId: ctx.societyId,
              filename: filename,
              buildPdf: _buildPdf,
              label: rs(context, 'reports.generate'),
            ),
            ExportFormatMenuButton(
              label: rs(context, 'reports.downloadView'),
              onExport: _export,
              formats: const [ExportFormat.excel, ExportFormat.word, ExportFormat.csv],
            ),
            SharePdfWhatsAppButton(
              label: rs(context, 'reports.shareWhatsApp'),
              filename: filename,
              message: '$_societyName — $_statementLabel financial report (${labels.join(', ')})',
              getBytes: _shareBytes,
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ReportTabPill(
              label: context.tr('Monthly', 'मासिक'),
              icon: Icons.calendar_month_outlined,
              selected: _monthlyMode,
              onTap: () {
                setState(() => _monthlyMode = true);
                _onStatementPeriodChanged();
              },
            ),
            ReportTabPill(
              label: context.tr('Date range', 'तारीख सीमा'),
              icon: Icons.date_range_outlined,
              selected: !_monthlyMode,
              onTap: () {
                setState(() => _monthlyMode = false);
                _onStatementPeriodChanged();
              },
            ),
            if (_monthlyMode) MonthPickerButton(value: _reportMonth, minMonth: kFinanceReportingEarliestMonth, onChanged: _setMonth),
          ]),
          if (!_monthlyMode) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ReportDateField(
                  label: context.tr('From', 'से'),
                  value: _customFrom,
                  onChanged: (v) {
                    setState(() => _customFrom = v);
                    _onStatementPeriodChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportDateField(
                  label: context.tr('To', 'तक'),
                  value: _customTo,
                  onChanged: (v) {
                    setState(() => _customTo = v);
                    _onStatementPeriodChanged();
                  },
                ),
              ),
            ]),
          ],
          if (_periodInvalid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('End date must be on or after start date.', 'अंतिम तारीख प्रारंभ तारीख के बराबर या बाद की होनी चाहिए।'),
                style: TextStyle(fontSize: 11, color: t.destructive),
              ),
            ),
        ]),
      ),
      if (_financeLoading && _finance.flats.isEmpty && _finance.payments.isEmpty)
        const LoadingView()
      else ...[
        if (report != null && ctx.societyId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FinancePeriodReportSendPanel(
              societyId: ctx.societyId,
              societyName: _societyName,
              adminName: ctx.adminName,
              periodFrom: _statementRange.from,
              periodTo: _statementRange.to,
              periodLabel: _statementLabel,
              periodReport: report,
              flatNumbers: [for (final f in _finance.flats) f.flatNumber],
            ),
          ),
        for (final k in _kinds) ...[
          _financialSection(k, report),
          const SizedBox(height: 20),
        ],
      ],
    ]);
  }

  Widget _financialSection(_FinancialKind k, FinancePeriodReportResult? report) {
    switch (k) {
      case _FinancialKind.collectionReceipts:
        return report == null ? const SizedBox.shrink() : FinancePeriodHeadTables(report: report, section: FinancePeriodHeadSection.receipts);
      case _FinancialKind.expenses:
        return report == null ? const SizedBox.shrink() : FinancePeriodHeadTables(report: report, section: FinancePeriodHeadSection.expenses);
      case _FinancialKind.flatWise:
        if (_finance.flats.isEmpty) return const SizedBox.shrink();
        final src = _flatSource;
        final rows = buildFlatReportRows(
          from: _flatFrom,
          to: _flatTo,
          selectedFlat: _flatSelected,
          payments: _finance.payments,
          ledgerEntries: _finance.ledgerEntries,
          flatReportExpenses: src?.expenses ?? const [],
          flatReportSplits: src?.splits ?? const [],
          flats: _finance.flats,
          primaryByFlatId: _finance.primaryByFlatId,
          charges: _finance.charges,
        );
        return FlatReportView(
          from: _flatFrom,
          to: _flatTo,
          selectedFlat: _flatSelected,
          onFromChanged: (v) => setState(() => _flatFrom = v),
          onToChanged: (v) => setState(() => _flatTo = v),
          onSelectedFlatChanged: (v) => setState(() => _flatSelected = v),
          flats: _finance.flats,
          primaryByFlatId: _finance.primaryByFlatId,
          isLoading: _flatLoading || _financeLoading,
          rows: rows,
        );
      case _FinancialKind.cashFlow:
        return CashFlowStatementView(
          periodFrom: _statementRange.from,
          periodTo: _statementRange.to,
          periodLabel: _statementLabel,
          societyName: _societyName,
          loading: _financeLoading,
          payments: _finance.payments,
          societyLedgerEntries: _finance.societyLedgerEntries,
          expenseCategoryById: _finance.expenseCategoryById,
          reserveTransfers: _finance.reserveTransfers,
          openingBalanceAnchors: _anchors,
        );
      case _FinancialKind.donationStatuses:
        final d = _aggregations.donationStatuses;
        return ReportStatCard(
          metric: ReportMetrics.moduleDonations,
          title: context.t('report.donationsStatuses'),
          caption: context.t('report.donationsStatuses'),
          icon: Icons.favorite_border,
          iconColor: context.tokens.destructive,
          label: context.t('report.donationsStatuses'),
          value: '${d.fold<int>(0, (s, x) => s + x.count)}',
          onNavigate: _openDonations,
          navigateLabel: context.tr('View donation detail', 'दान विवरण देखें'),
          children: [
            const SizedBox(height: 8),
            if (d.isEmpty)
              Text(context.tr('No donations for this period.', 'इस अवधि में कोई दान नहीं।'), style: AppText.caption(context))
            else
              for (final s in d)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(child: Text(capitalizeWords(s.status), style: AppText.body(context).copyWith(fontSize: 12))),
                    Text('${s.count} · ${rupees(s.total)}', style: AppText.mono(context, size: 12)),
                  ]),
                ),
          ],
        );
    }
  }

  Widget _visitorTab() {
    final v = _displayVisitors;
    final stats = ReportVisitorStats.of(v);
    final filteredCount = _q.trim().isNotEmpty && v.length != _monthVisitors.length ? ' / ${_monthVisitors.length}' : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatGrid(columns: 3, spacing: 8, children: [
        ReportStatCard(
          metric: const MetricCopy('Visitors', 'आगंतुक', 'Visitor log entries in the selected report month.',
              'चुने गए प्रतिवेदन माह की आगंतुक प्रविष्टियाँ।', 'Count of visitor records in the month filter.', 'माह फ़िल्टर में आगंतुक अभिलेखों की गिनती।'),
          title: context.t('dashboard.visitors'),
          caption: context.t('dashboard.visitors'),
          icon: Icons.people_outline,
          value: '${stats.totalVisitors}',
          center: true,
          compact: true,
          onNavigate: _openVisitors,
          navigateLabel: context.tr('View visitor list', 'आगंतुक सूची देखें'),
        ),
        ReportStatCard(
          metric: const MetricCopy('Deliveries', 'वितरण', 'Delivery personnel entries in the selected month.',
              'चुने गए माह की वितरण कर्मी प्रविष्टियाँ।', 'Visitors categorised as deliveries in the month.', 'माह में वितरण श्रेणी के आगंतुक।'),
          title: context.t('dashboard.deliveries'),
          caption: context.t('dashboard.deliveries'),
          icon: Icons.local_shipping_outlined,
          value: '${stats.totalDeliveries}',
          center: true,
          compact: true,
          onNavigate: _openDeliveries,
          navigateLabel: context.tr('View delivery list', 'वितरण सूची देखें'),
        ),
        ReportStatCard(
          metric: const MetricCopy('Inside now', 'अभी अंदर', 'Visitors who entered but have no exit time recorded yet.',
              'जो आगंतुक अंदर आए पर जिनका बाहर जाने का समय दर्ज नहीं हुआ।', 'Entries in month with exit_time null.', 'माह की प्रविष्टियाँ जिनका exit_time खाली है।'),
          title: context.t('dashboard.insideNow'),
          caption: context.t('dashboard.insideNow'),
          icon: Icons.door_front_door_outlined,
          value: '${stats.currentlyInside}',
          center: true,
          compact: true,
        ),
      ]),
      const SizedBox(height: 20),
      SectionTitle('${context.t('report.entries')} (${v.length}$filteredCount)'),
      if (_monthLoading && _loadedMonth != _reportMonth)
        const LoadingView()
      else if (v.isEmpty)
        EmptyView(message: _q.trim().isNotEmpty ? context.t('report.searchNoResults') : context.t('report.noEntries'))
      else
        for (final x in v) _visitorRow(x),
    ]);
  }

  Widget _visitorRow(ReportVisitor v) {
    final t = context.tokens;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: v.isInside ? t.success : t.mutedForeground)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: v.name),
                TextSpan(text: ' · ${v.flatNumber}', style: TextStyle(color: t.mutedForeground)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMedium(context).copyWith(fontSize: 12),
            ),
            Text('${v.category} · ${fmtDateTime(v.entryTime)}', style: AppText.tiny(context)),
          ]),
        ),
        if (v.hasVehicle) _plate(v.vehicleNumber!),
      ]),
    );
  }

  Widget _plate(String n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: context.tokens.muted, borderRadius: BorderRadius.circular(4)),
        child: Text(n, style: AppText.mono(context, size: 10)),
      );

  Widget _vehicleTab() {
    final t = context.tokens;
    final v = _displayVehicles;
    final all = _monthVisitors.where((x) => x.hasVehicle).length;
    final stats = ReportVisitorStats.of(_displayVisitors);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatGrid(spacing: 8, children: [
        ReportStatCard(
          metric: const MetricCopy('Vehicle entries', 'वाहन प्रविष्टियाँ', 'Visitor log rows that include a vehicle number in the period.',
              'अवधि की वे आगंतुक प्रविष्टियाँ जिनमें वाहन नंबर है।', 'Count of month visitors with vehicle_number set.', 'माह के आगंतुक जिनका vehicle_number भरा है, उनकी गिनती।'),
          icon: Icons.directions_car_outlined,
          value: '${stats.totalVehicles}',
          center: true,
          compact: true,
          onNavigate: _openVehicles,
          navigateLabel: context.tr('View vehicles', 'वाहन देखें'),
        ),
        ReportStatCard(
          metric: const MetricCopy('Unique flats', 'अलग-अलग फ्लैट', 'Distinct flat numbers that had vehicle entries in the period.',
              'अवधि में वाहन प्रविष्टि वाले अलग-अलग फ्लैट नंबर।', 'Distinct flat_number on vehicle visitor rows.', 'वाहन आगंतुक पंक्तियों पर अलग flat_number।'),
          icon: Icons.people_outline,
          value: '${stats.uniqueFlats}',
          center: true,
          compact: true,
        ),
      ]),
      const SizedBox(height: 20),
      SectionTitle(
        '${context.tr('Vehicle Entries', 'वाहन प्रविष्टियाँ')} (${v.length}${_q.trim().isNotEmpty && v.length != all ? ' / $all' : ''})',
      ),
      if (_monthLoading && _loadedMonth != _reportMonth)
        const LoadingView()
      else if (v.isEmpty)
        EmptyView(
          message: _q.trim().isNotEmpty
              ? context.t('report.searchNoResults')
              : context.tr('No vehicle entries this month', 'इस माह कोई वाहन प्रविष्टि नहीं'),
        )
      else
        for (final x in v)
          CardSection(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.directions_car_outlined, size: 16, color: t.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.vehicleNumber ?? '', style: AppText.mono(context, size: 12, weight: FontWeight.w600)),
                  Text('${x.name} · ${context.t('common.flat')} ${x.flatNumber} · ${fmtDateTime(x.entryTime)}', style: AppText.tiny(context)),
                ]),
              ),
              MiniStatusChip(
                x.isInside ? context.tr('Inside', 'अंदर') : context.tr('Exited', 'बाहर'),
                color: x.isInside ? t.success : t.mutedForeground,
                capitalize: false,
              ),
            ]),
          ),
    ]);
  }

  Widget _allModulesTab() {
    final t = context.tokens;
    final monthEntries = _searchedMonthEntries;
    final monthTotal = monthEntries.fold<double>(0, (s, e) => s + e.totalAmount);
    final stats = ReportVisitorStats.of(_displayVisitors);
    final d = _aggregations.donationStatuses;
    Widget extra(String s) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(s, style: AppText.tiny(context)));
    Widget soon(IconData icon, Color color, String label) => Opacity(
          opacity: 0.6,
          child: CardSection(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Text(rs(context, 'reports.comingSoon'), style: AppText.tiny(context)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(context.tr('Summary across all modules for $_reportMonth', '$_reportMonth के सभी मॉड्यूल का सारांश'), style: AppText.caption(context)),
      ),
      StatGrid(children: [
        ReportStatCard(
          metric: ReportMetrics.financeGross,
          title: context.tr('Finance', 'वित्त'),
          caption: context.tr('Finance', 'वित्त'),
          label: context.tr('Finance', 'वित्त'),
          icon: Icons.currency_rupee,
          iconColor: t.success,
          value: rupees(monthTotal),
          onNavigate: _openMonthFinance,
          navigateLabel: context.tr('View finance detail', 'वित्त विवरण देखें'),
          children: [extra(context.tr('${monthEntries.length} entries', '${monthEntries.length} प्रविष्टियाँ'))],
        ),
        ReportStatCard(
          metric: ReportMetrics.guardShifts,
          title: context.tr('Guard Shifts', 'गार्ड पारी'),
          caption: context.tr('Guard Shifts', 'गार्ड पारी'),
          label: context.tr('Guard Shifts', 'गार्ड पारी'),
          icon: Icons.shield_outlined,
          iconColor: t.primary,
          value: '${_searchedShifts.length}',
          onNavigate: _openShifts,
          navigateLabel: context.tr('View shift list', 'पारी सूची देखें'),
          children: [extra(context.tr('Login/Logout records', 'लॉगिन/लॉगआउट अभिलेख'))],
        ),
        ReportStatCard(
          metric: ReportMetrics.moduleVisitors,
          title: context.tr('Visitors', 'आगंतुक'),
          caption: context.tr('Visitors', 'आगंतुक'),
          label: context.tr('Visitors', 'आगंतुक'),
          icon: Icons.people_outline,
          iconColor: t.accent,
          value: '${stats.totalVisitors}',
          onNavigate: _openVisitors,
          navigateLabel: context.tr('View visitors', 'आगंतुक देखें'),
          children: [extra(context.tr('Guest entries', 'अतिथि प्रविष्टियाँ'))],
        ),
        ReportStatCard(
          metric: ReportMetrics.moduleVehicles,
          title: context.tr('Vehicles', 'वाहन'),
          caption: context.tr('Vehicles', 'वाहन'),
          label: context.tr('Vehicles', 'वाहन'),
          icon: Icons.directions_car_outlined,
          iconColor: t.warning,
          value: '${stats.totalVehicles}',
          onNavigate: _openVehicles,
          navigateLabel: context.tr('View vehicles', 'वाहन देखें'),
          children: [extra(context.tr('Vehicle entries', 'वाहन प्रविष्टियाँ'))],
        ),
        ReportStatCard(
          metric: ReportMetrics.moduleDeliveries,
          title: context.tr('Deliveries', 'वितरण'),
          caption: context.tr('Deliveries', 'वितरण'),
          label: context.tr('Deliveries', 'वितरण'),
          icon: Icons.local_shipping_outlined,
          iconColor: t.primary,
          value: '${stats.totalDeliveries}',
          onNavigate: _openDeliveries,
          navigateLabel: context.tr('View deliveries', 'वितरण देखें'),
          children: [extra(context.tr('Delivery/Service entries', 'वितरण/सेवा प्रविष्टियाँ'))],
        ),
        ReportStatCard(
          metric: ReportMetrics.moduleDonations,
          title: context.tr('Donations', 'दान'),
          caption: context.tr('Donations', 'दान'),
          label: context.tr('Donations', 'दान'),
          icon: Icons.favorite_border,
          iconColor: t.destructive,
          value: '${d.fold<int>(0, (s, x) => s + x.count)}',
          onNavigate: _openDonations,
          navigateLabel: context.tr('View donations', 'दान देखें'),
          children: [extra(rupees(d.fold<double>(0, (s, x) => s + x.total)))],
        ),
        soon(Icons.local_parking_outlined, t.accent, context.tr('Parking', 'पार्किंग')),
        soon(Icons.how_to_vote_outlined, t.primary, context.tr('Polls & Elections', 'मतदान व चुनाव')),
        soon(Icons.build_outlined, t.mutedForeground, context.tr('Maintenance Requests', 'रखरखाव अनुरोध')),
      ]),
    ]);
  }

  Widget _engineTab() => MetadataReportEngine(
        societyId: ctx.societyId,
        societyName: _societyName,
        adminName: ctx.adminName,
        permissions: ctx.session.admin.permissions.flag,
        periodFrom: _monthRange.from,
        periodTo: _monthRange.to,
        searchQuery: _q,
        onExportReady: (e) => _engineExporter = e,
      );

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      onRefresh: _refreshAll,
      children: [
        PageHeader(
          title: context.t('report.title'),
          subtitle: context.t('report.subtitle'),
          icon: Icons.bar_chart_rounded,
          bottomSpacing: 12,
        ),
        if (_tab != _ReportTab.financial) _headerActions(),
        _searchCard(),
        _tabs(),
        switch (_tab) {
          _ReportTab.financial => _financialTab(),
          _ReportTab.visitor => _visitorTab(),
          _ReportTab.vehicle => _vehicleTab(),
          _ReportTab.allModules => _allModulesTab(),
          _ReportTab.engine => ctx.societyId.isEmpty ? const SizedBox.shrink() : _engineTab(),
        },
      ],
    );
  }
}
