import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../shared/pdf/report_export.dart';
import '../../gate/guard_duty_review_panel.dart';
import '../core/admin_module.dart';
import 'data/report_models.dart';
import 'data/reports_repository.dart';
import 'logic/js_compat.dart';
import 'logic/report_formatters.dart';
import 'widgets/report_ui.dart';

enum _LogsTab { visitors, duty }

/// Admin → Logs (web `AdminLogsHub` + embedded `LogsPage`): visitor logs for a
/// day with search, category filter, mark-exit and CSV export, plus the guard
/// duty review (GATE's `GuardDutyReviewPanel`).
class AdminLogsModule extends StatefulWidget {
  const AdminLogsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminLogsModule> createState() => _AdminLogsModuleState();
}

class _AdminLogsModuleState extends State<AdminLogsModule> {
  AdminModuleContext get ctx => widget.ctx;

  _LogsTab _tab = _LogsTab.visitors;
  late final TextEditingController _search = TextEditingController(text: ctx.initialQuery ?? '');
  String _category = 'all';
  String _date = ymdOf(DateTime.now());
  List<ReportVisitor> _visitors = const [];
  bool _loading = true;
  bool _failed = false;
  final Set<String> _exiting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final day = _date;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await ReportsRepository.loadVisitorsForDay(ctx.societyId, day);
      if (!mounted || day != _date) return;
      setState(() => _visitors = rows);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted && day == _date) setState(() => _loading = false);
    }
  }

  List<ReportVisitor> get _filtered {
    final s = _search.text;
    final q = s.toLowerCase();
    return _visitors.where((v) {
      final matchSearch = s.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.phone.contains(s) ||
          v.flatNumber.toLowerCase().contains(q) ||
          (v.vehicleNumber != null && v.vehicleNumber!.toLowerCase().contains(q)) ||
          v.guardName.toLowerCase().contains(q);
      final matchCategory = _category == 'all' || v.category == _category;
      return matchSearch && matchCategory;
    }).toList();
  }

  Future<void> _markExit(ReportVisitor v) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmExit'),
      message: context.t('swal.confirmExitText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
    );
    if (!ok || !mounted) return;
    setState(() => _exiting.add(v.id));
    try {
      final now = await ReportsRepository.markVisitorExit(ctx.societyId, v);
      if (!mounted) return;
      setState(() => _visitors = [for (final x in _visitors) x.id == v.id ? x.markedExit(now) : x]);
      AppFeedback.toast(context, context.t('swal.exitMarked'), tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _exiting.remove(v.id));
    }
  }

  Future<void> _exportCsv() async {
    final rows = [
      for (final v in _filtered)
        [
          v.name,
          v.phone,
          v.flatNumber,
          v.category,
          v.purpose,
          fmtDateTime(v.entryTime),
          v.isInside ? 'Inside' : fmtDateTime(v.exitTime),
          v.guardName,
          v.hasVehicle ? v.vehicleNumber : '-',
        ],
    ];
    try {
      final bytes = rowsToCsvBytes(const ['Name', 'Phone', 'Flat', 'Category', 'Purpose', 'Entry', 'Exit', 'Guard', 'Vehicle'], rows);
      await shareExportFile(bytes, 'kutumbika-log-$_date.csv', ExportFormat.csv);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Widget _hubButton(_LogsTab tab, IconData icon, String label) {
    final t = context.tokens;
    final active = _tab == tab;
    return Material(
      color: active ? AppTokens.tint(t.primary, 0.15) : t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: active ? t.primary : t.border, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: () => setState(() => _tab = tab),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: active ? t.primary : t.foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? t.primary : t.foreground)),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _visitorLogs() {
    final t = context.tokens;
    final filtered = _filtered;
    final labels = {
      'all': context.t('logs.all'),
      'visitor': context.t('blacklist.visitor'),
      'delivery': context.t('delivery.tab.delivery'),
      'service': context.t('delivery.tab.service'),
    };
    return [
      Align(
        alignment: Alignment.centerRight,
        child: AppButton.secondary(label: 'CSV', icon: Icons.download_outlined, dense: true, expand: false, onPressed: _exportCsv),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
          hintText: context.t('logs.searchPlaceholder'),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _search.clear())),
        ),
      ),
      const SizedBox(height: 12),
      ReportDateField(
        label: context.tr('Date', 'तारीख'),
        value: _date,
        onChanged: (v) {
          setState(() => _date = v);
          _load();
        },
      ),
      const SizedBox(height: 10),
      PillChoiceGroup<String>(
        options: const ['all', 'visitor', 'delivery', 'service'],
        value: _category,
        labelOf: (c) => labels[c]!,
        onChanged: (c) => setState(() => _category = c),
      ),
      const SizedBox(height: 14),
      Text('${filtered.length} ${context.t('common.records')}', style: AppText.caption(context)),
      const SizedBox(height: 10),
      if (_loading)
        const LoadingView()
      else if (_failed)
        ErrorView(onRetry: _load)
      else if (filtered.isEmpty)
        EmptyView(message: context.t('logs.noRecords'))
      else
        for (final v in filtered) _logCard(v),
    ];
  }

  Widget _logCard(ReportVisitor v) {
    final t = context.tokens;
    final catColor = switch (v.category) {
      'visitor' => t.primary,
      'delivery' => t.warning,
      _ => t.secondaryForeground,
    };
    return CardSection(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: v.isInside ? t.success : t.mutedForeground),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(v.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sectionTitle(context)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: v.category == 'service' ? t.secondary : AppTokens.tint(catColor, 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(v.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: catColor)),
              ),
            ]),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: v.phone, style: const TextStyle(fontFamily: 'JetBrainsMono')),
                TextSpan(text: ' · ${context.t('common.flat')} ${v.flatNumber}'),
              ]),
              style: AppText.caption(context),
            ),
            if (v.purpose.isNotEmpty) Text(v.purpose, style: AppText.caption(context)),
            const SizedBox(height: 6),
            Wrap(spacing: 12, children: [
              Text('In: ${fmtTime(v.entryTime)}', style: AppText.caption(context)),
              if (!v.isInside) Text('Out: ${fmtTime(v.exitTime)}', style: AppText.caption(context)),
              if (v.hasVehicle) Text(v.vehicleNumber!, style: AppText.mono(context, size: 12, color: t.mutedForeground)),
            ]),
            const SizedBox(height: 4),
            Text('${context.t('logs.guard')}: ${v.guardName}', style: AppText.tiny(context)),
          ]),
        ),
        if (v.isInside)
          AppButton.secondary(
            label: context.t('common.exit'),
            icon: Icons.logout,
            dense: true,
            expand: false,
            loading: _exiting.contains(v.id),
            onPressed: () => _markExit(v),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      onRefresh: _tab == _LogsTab.visitors ? _load : null,
      children: [
        PageHeader(
          title: context.t('nav.logs'),
          subtitle: context.t('logs.subtitle'),
          icon: Icons.article_outlined,
          bottomSpacing: 16,
        ),
        Row(children: [
          Expanded(child: _hubButton(_LogsTab.visitors, Icons.description_outlined, context.t('duty.visitorLogs'))),
          const SizedBox(width: 8),
          Expanded(child: _hubButton(_LogsTab.duty, Icons.fact_check_outlined, context.t('duty.adminTab'))),
        ]),
        const SizedBox(height: 16),
        if (_tab == _LogsTab.visitors) ..._visitorLogs() else GuardDutyReviewPanel(societyId: ctx.societyId),
      ],
    );
  }
}
