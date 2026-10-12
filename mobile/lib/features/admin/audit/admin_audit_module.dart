import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import 'data/audit_service.dart';
import 'logic/js_compat.dart';
import 'widgets/audit_ui.dart';
import 'widgets/bank_reconciliation_panel.dart';
import 'widgets/finance_audit_alarms.dart';
import 'widgets/finance_integrity_audit.dart';
import 'widgets/manual_audit_tracer.dart';
import 'widgets/society_governance_guide.dart';

/// Admin "Audit" tab — port of `src/components/AuditLogViewer.tsx` with its embedded panels:
/// finance audit alarms, internal self-audit, bank reconciliation, manual tracer, governance guide,
/// and the security audit log (search by name / ID / IP, event filter, expandable details).
class AdminAuditModule extends StatefulWidget {
  const AdminAuditModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminAuditModule> createState() => _AdminAuditModuleState();
}

const _filters = [
  'all',
  'login_success',
  'login_failed',
  'password_change',
  'password_reset',
  'logout',
  'biometric_register',
  'geofence_violation',
];

class _AdminAuditModuleState extends State<AdminAuditModule> {
  final _service = const AuditService();
  final _alarmsKey = GlobalKey();
  late final TextEditingController _search;
  List<AuditLog> _logs = const [];
  bool _loading = true;
  String _filter = 'all';
  String? _expandedId;
  int _refreshSeq = 0;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.ctx.initialQuery ?? '');
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant AdminAuditModule old) {
    super.didUpdateWidget(old);
    final q = widget.ctx.initialQuery;
    if (q != null && q.isNotEmpty && q != old.ctx.initialQuery)
      setState(() => _search.text = q);
    if (old.ctx.societyId != widget.ctx.societyId) _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (widget.ctx.societyId.isEmpty) {
      setState(() {
        _logs = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final rows =
          await _service.fetchLogs(widget.ctx.societyId, filter: _filter);
      if (mounted) setState(() => _logs = rows);
    } catch (_) {
      if (mounted) setState(() => _logs = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshSeq++);
    await _loadLogs();
  }

  void _scrollToAlarms() {
    final c = _alarmsKey.currentContext;
    if (c != null)
      Scrollable.ensureVisible(c,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _navigate(String tab, String? subTab) {
    switch (tab) {
      case 'finance':
        widget.ctx.goTo(AdminTab.finance, subTab: subTab);
      case 'report':
        widget.ctx.goTo(AdminTab.report);
      case 'audit':
        // "Go to Duplicate Alarms" — already on this tab; bring the alarms into view.
        _scrollToAlarms();
      default:
        break;
    }
  }

  String _eventLabel(String type) => switch (type) {
        'login_success' => context.tr('✅ Login Success', '✅ लॉगिन सफल'),
        'login_failed' => context.tr('❌ Login Failed', '❌ लॉगिन विफल'),
        'password_change' =>
          context.tr('🔑 Password Changed', '🔑 पासवर्ड बदला गया'),
        'password_reset' => context.tr('🔄 Password Reset', '🔄 पासवर्ड रीसेट'),
        'logout' => context.tr('🚪 Logout', '🚪 लॉगआउट'),
        'biometric_register' =>
          context.tr('👆 Biometric Registered', '👆 बायोमेट्रिक पंजीकृत'),
        'geofence_violation' => context.tr(
            '📍 Geofence / Location breach', '📍 जियोफेंस / स्थान उल्लंघन'),
        _ => type,
      };

  String _filterLabel(String f) => switch (f) {
        'all' => context.tr('All Events', 'सभी घटनाएँ'),
        'login_success' => context.tr('Login Success', 'लॉगिन सफल'),
        'login_failed' => context.tr('Login Failed', 'लॉगिन विफल'),
        'password_change' => context.tr('Password Change', 'पासवर्ड बदलाव'),
        'password_reset' => context.tr('Password Reset', 'पासवर्ड रीसेट'),
        'logout' => context.tr('Logout', 'लॉगआउट'),
        'biometric_register' => context.tr('Biometric', 'बायोमेट्रिक'),
        'geofence_violation' =>
          context.tr('Geofence / Location', 'जियोफेंस / स्थान'),
        _ => f,
      };

  List<AuditLog> get _filtered {
    final s = _search.text.toLowerCase();
    if (s.isEmpty) return _logs;
    return _logs
        .where((l) =>
            (l.userName?.toLowerCase().contains(s) ?? false) ||
            (l.userId?.toLowerCase().contains(s) ?? false) ||
            (l.ipAddress?.contains(s) ?? false) ||
            l.userType.contains(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final t = context.tokens;
    final total = _logs.length;
    final failed = _logs.where((l) => l.eventType == 'login_failed').length;
    final resets = _logs
        .where((l) =>
            l.eventType == 'password_reset' || l.eventType == 'password_change')
        .length;
    final filtered = _filtered;

    return PageContainer(
      onRefresh: _refresh,
      children: [
        PageHeader(
          icon: Icons.description_outlined,
          title: context.tk(
              'audit.title', 'Security Audit Logs', 'सुरक्षा ऑडिट लॉग'),
          subtitle: context.isHi
              ? '$total घटनाएँ · $failed विफल · $resets रीसेट'
              : '$total events · $failed failed · $resets resets',
          bottomSpacing: 16,
        ),
        StatGrid(columns: 3, spacing: 8, children: [
          DescriptiveStatCard(
            icon: Icons.info_outline,
            iconColor: t.accent,
            title: context.tr('Total events', 'कुल घटनाएँ'),
            value: '$total',
            description: context.tr(
                'All security audit log entries stored for this society.',
                'इस सोसाइटी के लिए संग्रहीत सभी सुरक्षा ऑडिट लॉग प्रविष्टियाँ।'),
            howCalculated: context.tr(
                'Count of audit_logs rows loaded in this view.',
                'इस दृश्य में लोड की गई audit_logs पंक्तियों की संख्या।'),
          ),
          DescriptiveStatCard(
            icon: Icons.warning_amber_rounded,
            iconColor: t.warning,
            title: context.tr('Failed logins', 'विफल लॉगिन'),
            value: '$failed',
            description: context.tr(
                'Unsuccessful login attempts — possible wrong password or abuse.',
                'असफल लॉगिन प्रयास — संभवतः गलत पासवर्ड या दुरुपयोग।'),
            howCalculated: context.tr('Rows where event_type = login_failed.',
                'वे पंक्तियाँ जहाँ event_type = login_failed।'),
          ),
          DescriptiveStatCard(
            icon: Icons.shield_outlined,
            iconColor: t.success,
            title: context.tr('Password changes', 'पासवर्ड बदलाव'),
            caption: context.tr('Pwd changes', 'पासवर्ड बदलाव'),
            value: '$resets',
            description: context.tr(
                'Password reset or change events for admins, guards, or residents.',
                'एडमिन, गार्ड या निवासियों के पासवर्ड रीसेट या बदलाव की घटनाएँ।'),
            howCalculated: context.tr(
                'Rows where event_type is password_reset or password_change.',
                'वे पंक्तियाँ जहाँ event_type password_reset या password_change है।'),
          ),
        ]),
        const SizedBox(height: 16),
        KeyedSubtree(
            key: _alarmsKey,
            child: FinanceAuditAlarms(
                societyId: ctx.societyId, refreshSeq: _refreshSeq)),
        const SizedBox(height: 16),
        FinanceIntegrityAudit(
            societyId: ctx.societyId, onOpenAlarms: _scrollToAlarms),
        const SizedBox(height: 16),
        BankReconciliationPanel(
            societyId: ctx.societyId,
            adminName: ctx.adminName,
            refreshSeq: _refreshSeq),
        const SizedBox(height: 16),
        ManualAuditTracer(societyId: ctx.societyId, onNavigate: _navigate),
        const SizedBox(height: 16),
        const SocietyGovernanceGuide(),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: AppTextField(
              controller: _search,
              caps: false,
              hint:
                  context.tr('Search name, ID, IP...', 'नाम, ID, IP खोजें...'),
              prefixIcon: Icons.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: AppDropdown<String>(
              items: _filters,
              value: _filter,
              labelOf: _filterLabel,
              onChanged: (v) {
                if (v == null || v == _filter) return;
                setState(() => _filter = v);
                _loadLogs();
              },
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (_loading)
          const LoadingView()
        else if (filtered.isEmpty)
          EmptyView(
              message:
                  context.tr('No audit logs found', 'कोई ऑडिट लॉग नहीं मिला'))
        else
          for (final log in filtered) ...[
            _logCard(log),
            const SizedBox(height: 8)
          ],
      ],
    );
  }

  Widget _logCard(AuditLog log) {
    final t = context.tokens;
    final expanded = _expandedId == log.id;
    final tone = switch (log.severity) {
      'warning' => Tone.warning,
      'critical' => Tone.destructive,
      _ => Tone.info,
    };
    final sevLabel = switch (log.severity) {
      'info' => context.tr('INFO', 'सूचना'),
      'warning' => context.tr('WARNING', 'चेतावनी'),
      'critical' => context.tr('CRITICAL', 'गंभीर'),
      _ => log.severity.toUpperCase(),
    };
    return CardSection(
      padding: const EdgeInsets.all(12),
      onTap: () => setState(() => _expandedId = expanded ? null : log.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 8, runSpacing: 4, children: [
            TinyChip(sevLabel, tone: tone),
            TinyChip(log.userType, mono: true),
          ]),
          const SizedBox(height: 4),
          Text(_eventLabel(log.eventType), style: AppText.bodyMedium(context)),
          Text(
            '${(log.userName ?? '').isNotEmpty ? log.userName : ((log.userId ?? '').isNotEmpty ? log.userId : context.tr('Unknown', 'अज्ञात'))} · ${(log.ipAddress ?? '').isNotEmpty ? log.ipAddress : context.tr('no IP', 'IP नहीं')}',
            style: AppText.caption(context),
          ),
          const SizedBox(height: 4),
          Text(Fmt.dateTimeFull(log.createdAt), style: AppText.tiny(context)),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('IP Address', 'IP पता'),
                          style: AppText.caption(context)),
                      Text(
                          (log.ipAddress ?? '').isNotEmpty
                              ? log.ipAddress!
                              : 'N/A',
                          style: AppText.mono(context, size: 12)),
                    ]),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('User Type', 'उपयोगकर्ता प्रकार'),
                          style: AppText.caption(context)),
                      Text(
                          log.userType.isEmpty
                              ? ''
                              : '${log.userType[0].toUpperCase()}${log.userType.substring(1)}',
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ]),
            if (log.deviceInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.tr('Device Info', 'डिवाइस जानकारी'),
                  style: AppText.caption(context)),
              _kvBox(log.deviceInfo),
            ],
            if (log.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.tr('Details', 'विवरण'),
                  style: AppText.caption(context)),
              _kvBox(log.details),
            ],
            if ((log.userAgent ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.tr('User Agent', 'यूज़र एजेंट'),
                  style: AppText.caption(context)),
              Text(log.userAgent!,
                  style: AppText.mono(context,
                      size: 10, color: t.mutedForeground)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kvBox(Map<String, dynamic> m) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: AppTokens.tint(t.muted, 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in m.entries)
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '${e.key}: ',
                style:
                    AppText.mono(context, size: 10, color: t.mutedForeground)),
            TextSpan(
                text: jsString(e.value),
                style: AppText.mono(context, size: 10)),
          ])),
      ]),
    );
  }
}
