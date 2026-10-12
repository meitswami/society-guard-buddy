import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../../models/session_models.dart';
import '../../../../providers/session_provider.dart';
import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../data/reports_repository.dart';
import '../export/finance_period_report_export.dart';
import '../logic/finance_period_report.dart';
import '../logic/report_formatters.dart';
import 'report_ui.dart';

/// Port of `src/components/FinancePeriodReportSendPanel.tsx` — "Send to members":
/// uploads the period report PDF, posts one in-app alert per flat (optional push)
/// and can recall the latest batch.
///
/// Contract: `FinancePeriodReportSendPanel(societyId:, societyName:)`. With only
/// those two it is self-contained (own Monthly / Date-range period picker, loads
/// payments + ledger + opening anchors + flats). Pass [periodFrom], [periodTo],
/// [periodLabel], [periodReport] and [flatNumbers] to drive it from a parent page
/// (Reports → Financial, Finance → Totals) like the web.
class FinancePeriodReportSendPanel extends ConsumerStatefulWidget {
  const FinancePeriodReportSendPanel({
    super.key,
    required this.societyId,
    required this.societyName,
    this.adminName,
    this.periodFrom,
    this.periodTo,
    this.periodLabel,
    this.periodReport,
    this.flatNumbers,
  });

  final String societyId;
  final String societyName;
  final String? adminName;
  final String? periodFrom;
  final String? periodTo;
  final String? periodLabel;
  final FinancePeriodReportResult? periodReport;
  final List<String>? flatNumbers;

  @override
  ConsumerState<FinancePeriodReportSendPanel> createState() => _FinancePeriodReportSendPanelState();
}

class _FinancePeriodReportSendPanelState extends ConsumerState<FinancePeriodReportSendPanel> {
  bool _sendPush = true;
  bool _sending = false;
  String? _batchId;

  // Self-contained mode.
  bool get _driven => widget.periodReport != null;
  bool _loading = false;
  ReportFinanceData _data = ReportFinanceData.empty;
  List<FinanceOpeningBalanceAnchor> _anchors = const [];
  bool _monthly = true;
  String _month = ymNow();
  String _customFrom = defaultFinancePeriodFrom();
  String _customTo = defaultFinancePeriodTo();

  static String ymNow() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _reloadBatch();
    if (!_driven) _loadData();
  }

  @override
  void didUpdateWidget(covariant FinancePeriodReportSendPanel old) {
    super.didUpdateWidget(old);
    if (old.societyId != widget.societyId) {
      _reloadBatch();
      if (!_driven) _loadData();
    }
  }

  Future<void> _reloadBatch() async {
    try {
      final id = await ReportsRepository.latestPeriodReportBatch(widget.societyId);
      if (mounted) setState(() => _batchId = id);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        ReportsRepository.loadFinanceCore(widget.societyId),
        ReportsRepository.loadOpeningAnchors(widget.societyId),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as ReportFinanceData;
        _anchors = results[1] as List<FinanceOpeningBalanceAnchor>;
      });
    } catch (e) {
      if (mounted) AppFeedback.toast(context, context.t('mobile.loadFailed'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _from => widget.periodFrom ?? (_monthly ? financeReportingMonthRange(_month).from : _customFrom);
  String get _to => widget.periodTo ?? (_monthly ? financeReportingMonthRange(_month).to : _customTo);
  String get _label =>
      widget.periodLabel ??
      (_monthly ? fmtIsoMonthToDisplay(_month) : '${fmtIsoDateToDisplay(_customFrom)} – ${fmtIsoDateToDisplay(_customTo)}');

  FinancePeriodReportResult? get _report {
    if (widget.periodReport != null) return widget.periodReport;
    if (_from.compareTo(_to) > 0) return null;
    return computeFinancePeriodReport(
      periodFrom: _from,
      periodTo: _to,
      payments: _data.payments,
      ledgerEntries: _data.societyLedgerEntries,
      expenseCategoryById: _data.expenseCategoryById,
      openingBalanceAnchors: _anchors,
    );
  }

  List<String> get _flats => widget.flatNumbers ?? [for (final f in _data.flats) f.flatNumber];

  String get _adminName {
    if (widget.adminName != null && widget.adminName!.isNotEmpty) return widget.adminName!;
    final s = ref.read(sessionProvider).value;
    return s is SessionAdmin ? s.admin.name : 'Admin';
  }

  Future<void> _send(FinancePeriodReportResult report) async {
    final flats = <String>{for (final f in _flats) if (f.isNotEmpty) f}.toList();
    if (flats.isEmpty) {
      AppFeedback.toast(context, context.tr('No flats to notify', 'सूचित करने के लिए कोई फ्लैट नहीं'), tone: BadgeTone.alert);
      return;
    }
    final label = _label;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Send period report to members?', 'सदस्यों को अवधि प्रतिवेदन भेजें?'),
      message: context.tr(
        'Delivers one in-app alert per flat (${flats.length})${_sendPush ? ' and a push notification' : ''} for $label.',
        '$label के लिए प्रति फ्लैट एक इन-ऐप सूचना (${flats.length})${_sendPush ? ' और पुश सूचना' : ''} भेजी जाएगी।',
      ),
      confirmLabel: context.tr('Send', 'भेजें'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final ctx = await resolveLetterheadReportContext(widget.societyId);
      final pdf = await buildFinancePeriodReportPdf(toFinancePeriodReportExportInput(
        report,
        societyName: widget.societyName,
        periodFrom: _from,
        periodTo: _to,
        letterhead: ctx?.letterhead,
        pdfMode: ctx?.mode ?? ReportPdfMode.letterhead,
      ));
      await ReportsRepository.sendPeriodReportToMembers(
        societyId: widget.societyId,
        adminName: _adminName,
        periodLabel: label,
        summaryMessage: financePeriodSummaryMessage(report, label),
        pdfBytes: pdf,
        flatNumbers: flats,
        sendPush: _sendPush,
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        context.tr('Period report sent to ${flats.length} flat(s)', 'अवधि प्रतिवेदन ${flats.length} फ्लैट को भेजा गया'),
        tone: BadgeTone.success,
      );
      await _reloadBatch();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '${context.tr('Could not send period report', 'अवधि प्रतिवेदन नहीं भेजा जा सका')}: $e',
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recall() async {
    final batch = _batchId;
    if (batch == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Recall last period report batch?', 'पिछला अवधि प्रतिवेदन बैच वापस लें?'),
      message: context.tr(
        'Removes in-app notifications and the stored PDF for the most recent send.',
        'सबसे हाल में भेजी गई इन-ऐप सूचनाएँ और संग्रहीत PDF हटा दी जाएँगी।',
      ),
      confirmLabel: context.tr('Recall', 'वापस लें'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ReportsRepository.recallPeriodReport(widget.societyId, batch);
      if (!mounted) return;
      AppFeedback.toast(context, context.tr('Last period report batch recalled', 'पिछला अवधि प्रतिवेदन बैच वापस लिया गया'),
          tone: BadgeTone.success);
      await _reloadBatch();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '${context.tr('Recall failed', 'वापस लेना विफल')}: $e', tone: BadgeTone.alert);
    }
  }

  Widget _ownPeriodControls(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ReportTabPill(
            label: context.tr('Monthly', 'मासिक'),
            icon: Icons.calendar_month_outlined,
            selected: _monthly,
            onTap: () => setState(() => _monthly = true),
          ),
          ReportTabPill(
            label: context.tr('Date range', 'तारीख सीमा'),
            icon: Icons.date_range_outlined,
            selected: !_monthly,
            onTap: () => setState(() => _monthly = false),
          ),
          if (_monthly)
            MonthPickerButton(value: _month, minMonth: kFinanceReportingEarliestMonth, onChanged: (v) => setState(() => _month = v)),
        ]),
        if (!_monthly) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ReportDateField(label: context.tr('From', 'से'), value: _customFrom, onChanged: (v) => setState(() => _customFrom = v))),
            const SizedBox(width: 8),
            Expanded(child: ReportDateField(label: context.tr('To', 'तक'), value: _customTo, onChanged: (v) => setState(() => _customTo = v))),
          ]),
        ],
        if (_from.compareTo(_to) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.tr('End date must be on or after start date.', 'अंतिम तारीख प्रारंभ तारीख के बराबर या बाद की होनी चाहिए।'),
              style: TextStyle(fontSize: 11, color: t.destructive),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.societyId.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final report = _report;
    final flatsEmpty = _flats.isEmpty;
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.notifications_none, size: 14, color: t.foreground),
            const SizedBox(width: 6),
            Text(context.tr('Send to members', 'सदस्यों को भेजें'),
                style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 2),
          Text(
            '$_label — ${context.tr('PDF + in-app alert per flat', 'PDF + प्रति फ्लैट इन-ऐप सूचना')}'
            '${_batchId != null ? context.tr(' · latest batch on file', ' · नवीनतम बैच उपलब्ध') : ''}',
            style: AppText.tiny(context),
          ),
          if (!_driven) _ownPeriodControls(context),
          if (!_driven && report != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(financePeriodSummaryMessage(report, _label), style: AppText.tiny(context)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => setState(() => _sendPush = !_sendPush),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(value: _sendPush, onChanged: (v) => setState(() => _sendPush = v ?? false)),
                  ),
                  Text(context.tr('Push notification', 'पुश सूचना'), style: AppText.tiny(context).copyWith(fontSize: 11)),
                ]),
              ),
              AppButton(
                label: _sending ? context.tr('Sending…', 'भेजा जा रहा है…') : context.tr('Send', 'भेजें'),
                icon: Icons.send_outlined,
                dense: true,
                expand: false,
                loading: _sending || _loading,
                onPressed: (_sending || flatsEmpty || report == null) ? null : () => _send(report),
              ),
              if (_batchId != null)
                AppButton.secondary(
                  label: context.tr('Recall', 'वापस लें'),
                  icon: Icons.undo,
                  dense: true,
                  expand: false,
                  onPressed: _recall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
