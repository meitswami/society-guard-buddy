import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/ui.dart';
import '../data/audit_service.dart';
import '../logic/finance_audit_detection.dart';
import '../logic/integrity_audit_engine.dart';
import '../logic/js_compat.dart';
import 'audit_ui.dart';

/// Port of `FinanceIntegrityAudit.tsx` — internal finance self-audit with a chronological fix queue.
class FinanceIntegrityAudit extends StatefulWidget {
  const FinanceIntegrityAudit(
      {super.key, required this.societyId, this.onOpenAlarms});

  final String societyId;

  /// Scrolls to the duplicate / ledger alarm panels (web `scrollToAuditAlarms`).
  final VoidCallback? onOpenAlarms;

  @override
  State<FinanceIntegrityAudit> createState() => _FinanceIntegrityAuditState();
}

class _FinanceIntegrityAuditState extends State<FinanceIntegrityAudit> {
  final _service = const AuditService();
  bool _running = false;
  IntegrityAuditResult? _result;
  String? _expandedId;
  String? _busyKey;
  final Set<String> _resolved = {};

  Future<void> _run() async {
    final hi = context.isHi;
    setState(() {
      _running = true;
      _result = null;
      _resolved.clear();
    });
    IntegrityAuditResult result;
    try {
      final input = await _service.fetchIntegrityInput(widget.societyId);
      result = computeIntegrityAudit(input, hi: hi);
    } catch (e) {
      result = integrityAuditError(auditErrText(e), hi: hi);
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
    });
  }

  void _markDone(AuditFixQueueItem item) =>
      setState(() => _resolved.add(item.queueKey));

  Future<void> _queueDelete(AuditFixQueueItem item) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete this entry?', 'यह प्रविष्टि हटाएँ?'),
      message:
          '${item.title} — ${jsInr(item.amount)} ${context.tr('on', 'तिथि')} ${fmtIsoDateToDisplay(item.sortDate)}. ${item.actionHint}',
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final hi = context.isHi;
    setState(() => _busyKey = item.queueKey);
    final res = item.entryKind == FixEntryKind.payment
        ? await _service.deleteMaintenancePayment(
            item.entryId, item.financeEntryId)
        : await _service.deleteOrphanLedgerEntry(item.entryId, hi: hi);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(
        context,
        context.tr('Entry deleted — re-run audit when done with this batch',
            'प्रविष्टि हटाई गई — यह बैच पूरा होने पर ऑडिट फिर चलाएँ'),
        tone: BadgeTone.success);
    _markDone(item);
  }

  Future<void> _queueAlignPayment(AuditFixQueueItem item) async {
    final target = item.alignTargetMonth;
    if (target == null) return;
    setState(() => _busyKey = item.queueKey);
    final res = await _service.alignPaymentDueToMonth(item.entryId, target);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(
        context,
        context.tr('Payment aligned to ${fmtIsoMonthToDisplay(target)}',
            'भुगतान ${fmtIsoMonthToDisplay(target)} से मिलाया गया'),
        tone: BadgeTone.success);
    _markDone(item);
  }

  Future<void> _queueAlignLedger(
      AuditFixQueueItem item, String paymentMonth) async {
    final related = item.relatedEntryId;
    if (related == null) return;
    setState(() => _busyKey = item.queueKey);
    final res = await _service.alignLedgerEntryMonth(related, paymentMonth);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(
        context,
        context.tr('Ledger aligned to ${fmtIsoMonthToDisplay(paymentMonth)}',
            'लेजर ${fmtIsoMonthToDisplay(paymentMonth)} से मिलाया गया'),
        tone: BadgeTone.success);
    _markDone(item);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.verified_user_outlined,
          title: context.tr('Internal Finance Audit', 'आंतरिक वित्त ऑडिट'),
          subtitle: context.tr(
              'Checks for negative balances, discrepancies, duplicates & data bugs',
              'ऋणात्मक शेष, असंगतियाँ, डुप्लिकेट और डेटा त्रुटियों की जाँच'),
          trailing: SmallButton(
            label: _running
                ? context.tr('Running…', 'चल रहा है…')
                : context.tr('Run Self-Audit', 'स्व-ऑडिट चलाएँ'),
            icon: Icons.play_arrow_rounded,
            style: SmallBtnStyle.primary,
            busy: _running,
            fontSize: 12,
            onPressed: widget.societyId.isEmpty ? null : _run,
          ),
        ),
        const SizedBox(height: 12),
        if (result != null) ..._results(result),
        if (result == null && !_running)
          CardSection(
            child: Column(children: [
              Icon(Icons.verified_user_outlined,
                  size: 32, color: AppTokens.tint(t.mutedForeground, 0.4)),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Click "Run Self-Audit" to scan for discrepancies. Results list exact entries to inspect from the earliest date through today.',
                  'असंगतियाँ खोजने के लिए "स्व-ऑडिट चलाएँ" दबाएँ। परिणाम सबसे पुरानी तिथि से आज तक जाँचने योग्य सटीक प्रविष्टियाँ दिखाते हैं।',
                ),
                textAlign: TextAlign.center,
                style: AppText.caption(context),
              ),
            ]),
          ),
      ],
    );
  }

  List<Widget> _results(IntegrityAuditResult r) {
    final t = context.tokens;
    Widget stat(String title, String hiTitle, String desc, String hiDesc,
            String how, String hiHow, int v, Color c) =>
        DescriptiveStatCard(
          compact: true,
          title: context.tr(title, hiTitle),
          caption: context.tr(title, hiTitle),
          description: context.tr(desc, hiDesc),
          howCalculated: context.tr(how, hiHow),
          value: '$v',
          valueColor: c,
          borderColor: AppTokens.tint(c, 0.3),
        );
    final pass =
        r.findings.where((f) => f.severity == FindingSeverity.pass).toList();
    final issues =
        r.findings.where((f) => f.severity != FindingSeverity.pass).toList();
    return [
      StatGrid(columns: 4, spacing: 8, children: [
        stat(
            'Critical',
            'गंभीर',
            'Checks that indicate data integrity risk or broken links between payments and ledger.',
            'जाँचें जो डेटा अखंडता जोखिम या भुगतान और लेजर के बीच टूटे लिंक दर्शाती हैं।',
            'Count of self-audit findings with severity critical.',
            'गंभीर स्तर वाले स्व-ऑडिट निष्कर्षों की संख्या।',
            r.summary.critical,
            t.destructive),
        stat(
            'Warnings',
            'चेतावनी',
            'Possible duplicates or mismatches that should be reviewed by the treasurer.',
            'संभावित डुप्लिकेट या असंगतियाँ जिनकी कोषाध्यक्ष को समीक्षा करनी चाहिए।',
            'Count of findings with severity warning.',
            'चेतावनी स्तर वाले निष्कर्षों की संख्या।',
            r.summary.warning,
            t.warning),
        stat(
            'Info',
            'सूचना',
            'Informational notices that do not block reporting but help reconciliation.',
            'सूचनात्मक संदेश जो रिपोर्टिंग नहीं रोकते पर मिलान में मदद करते हैं।',
            'Count of findings with severity info.',
            'सूचना स्तर वाले निष्कर्षों की संख्या।',
            r.summary.info,
            t.accent),
        stat(
            'Passed',
            'सफल',
            'Rules that completed with no issues detected.',
            'नियम जो बिना किसी समस्या के पूरे हुए।',
            'Count of findings with severity pass.',
            'सफल निष्कर्षों की संख्या।',
            r.summary.pass,
            t.success),
      ]),
      const SizedBox(height: 8),
      Text(
          '${context.tr('Audit ran at', 'ऑडिट चलाया गया')} ${DateFormat('dd MMM yyyy, hh:mm a').format(r.ranAt)}',
          style: AppText.tiny(context)),
      const SizedBox(height: 12),
      if (r.fixQueue.isNotEmpty) ...[_fixQueue(r), const SizedBox(height: 12)],
      for (final f in issues) ...[_findingCard(f), const SizedBox(height: 12)],
      if (pass.isNotEmpty)
        ToneCard(
          tone: Tone.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.check_circle_outline, size: 16, color: t.success),
                const SizedBox(width: 8),
                Text(
                  context.isHi
                      ? '${pass.length} जाँचें सफल'
                      : '${pass.length} check${pass.length > 1 ? 's' : ''} passed',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.success),
                ),
              ]),
              const SizedBox(height: 8),
              for (final f in pass)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle_outline,
                        size: 10, color: t.success),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(f.title, style: AppText.tiny(context))),
                  ]),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _fixQueue(IntegrityAuditResult r) {
    final t = context.tokens;
    return ToneCard(
      tone: Tone.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.format_list_numbered, size: 16, color: t.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        context.tr('Entries to inspect (earliest first)',
                            'जाँचने योग्य प्रविष्टियाँ (पुरानी पहले)'),
                        style: AppText.sectionTitle(context)),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          'Fix one entry at a time from the oldest discrepancy through today, then re-run the audit.',
                          'सबसे पुरानी असंगति से आज तक एक-एक प्रविष्टि सुधारें, फिर ऑडिट दोबारा चलाएँ।'),
                      style: AppText.tiny(context),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < r.fixQueue.length; i++) ...[
            _queueItem(r.fixQueue[i], i),
            const SizedBox(height: 8)
          ],
          if (_resolved.isNotEmpty)
            SmallButton(
              label: context.isHi
                  ? 'सुधार के बाद ऑडिट फिर चलाएँ (${_resolved.length} पूर्ण)'
                  : 'Re-run audit after fixes (${_resolved.length} marked done)',
              style: SmallBtnStyle.primary,
              expand: true,
              fontSize: 12,
              onPressed: _run,
            ),
        ],
      ),
    );
  }

  Widget _queueItem(AuditFixQueueItem item, int idx) {
    final t = context.tokens;
    final done = _resolved.contains(item.queueKey);
    final busy = _busyKey == item.queueKey;
    final border = done
        ? AppTokens.tint(t.success, 0.3)
        : item.severity == FixSeverity.critical
            ? AppTokens.tint(t.destructive, 0.3)
            : AppTokens.tint(t.warning, 0.3);
    final box = InnerBox(
      borderColor: border,
      color: done
          ? Color.alphaBlend(AppTokens.tint(t.success, 0.05), t.card)
          : t.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TinyChip(done ? '✓' : '${idx + 1}',
              tone: done ? Tone.success : Tone.primary,
              pill: false,
              bold: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.issueLabel,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      TinyChip(fmtIsoDateToDisplay(item.sortDate), pill: false),
                      TinyChip(fmtIsoMonthToDisplay(item.month), pill: false),
                    ]),
                const SizedBox(height: 4),
                Text(item.title, style: AppText.bodyMedium(context)),
                Text(jsInr(item.amount),
                    style: AppText.mono(context, size: 12)),
                const SizedBox(height: 4),
                Text(item.detail, style: AppText.tiny(context)),
                const SizedBox(height: 4),
                Text.rich(TextSpan(
                    style: TextStyle(fontSize: 10, color: t.foreground),
                    children: [
                      TextSpan(
                          text: '${context.tr('Action', 'कार्रवाई')}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: item.actionHint),
                    ])),
                Text(
                  '${item.entryKind == FixEntryKind.payment ? context.tr('Payment', 'भुगतान') : context.tr('Ledger', 'लेजर')} ID: ${jsSlice(item.entryId, 0, 8)}…',
                  style: AppText.mono(context,
                      size: 9, color: AppTokens.tint(t.mutedForeground, 0.7)),
                ),
                if (!done) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (item.action == AuditFixAction.delete)
                      SmallButton(
                        label: context.t('common.delete'),
                        icon: Icons.delete_outline,
                        style: SmallBtnStyle.destructive,
                        busy: busy,
                        fontSize: 10,
                        onPressed: () => _queueDelete(item),
                      ),
                    if (item.action == AuditFixAction.alignPaymentMonth &&
                        item.alignTargetMonth != null) ...[
                      SmallButton(
                        label: context.isHi
                            ? 'भुगतान ${fmtIsoMonthToDisplay(item.alignTargetMonth)} पर करें'
                            : 'Set payment to ${fmtIsoMonthToDisplay(item.alignTargetMonth)}',
                        icon: Icons.calendar_month_outlined,
                        busy: busy,
                        fontSize: 10,
                        onPressed: () => _queueAlignPayment(item),
                      ),
                      SmallButton(
                        label: context.isHi
                            ? 'लेजर ${fmtIsoMonthToDisplay(item.month)} पर करें'
                            : 'Set ledger to ${fmtIsoMonthToDisplay(item.month)}',
                        icon: Icons.calendar_month_outlined,
                        busy: busy,
                        fontSize: 10,
                        onPressed: () => _queueAlignLedger(item, item.month),
                      ),
                    ],
                    if (item.action == AuditFixAction.review)
                      SmallButton(
                        label: context.tr(
                            'Review in Finance', 'वित्त में समीक्षा करें'),
                        icon: Icons.edit_outlined,
                        fontSize: 10,
                        onPressed: widget.onOpenAlarms,
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return done ? Opacity(opacity: 0.6, child: box) : box;
  }

  Widget _findingCard(AuditFinding f) {
    final t = context.tokens;
    final (Tone tone, IconData icon) = switch (f.severity) {
      FindingSeverity.critical => (Tone.destructive, Icons.cancel_outlined),
      FindingSeverity.warning => (Tone.warning, Icons.warning_amber_rounded),
      FindingSeverity.info => (Tone.info, Icons.bug_report_outlined),
      FindingSeverity.pass => (Tone.success, Icons.check_circle_outline),
    };
    final expanded = _expandedId == f.id;
    final ledgerIssues = f.ledgerIssues ?? const <LedgerOvercountMonth>[];
    return ToneCard(
      tone: tone,
      onTap: () => setState(() => _expandedId = expanded ? null : f.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: toneColor(context, tone)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title, style: AppText.sectionTitle(context)),
                    const SizedBox(height: 2),
                    Text(f.description, style: AppText.caption(context)),
                  ]),
            ),
          ]),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 12),
            if (f.reason.isNotEmpty) ...[
              TinyLabel(context.tr('Why This Happens', 'ऐसा क्यों होता है'),
                  icon: Icons.trending_down),
              const SizedBox(height: 4),
              Text(f.reason,
                  style: TextStyle(fontSize: 12, color: t.foreground)),
              const SizedBox(height: 8),
            ],
            if ((f.faultTrace ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.primary, 0.05),
                  border: Border.all(color: AppTokens.tint(t.primary, 0.3)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TinyLabel(
                          context.tr('Trace to Fault', 'गड़बड़ी तक ट्रेस'),
                          icon: Icons.place_outlined,
                          color: t.primary),
                      const SizedBox(height: 4),
                      Text(f.faultTrace!,
                          style: AppText.mono(context, size: 11)),
                    ]),
              ),
              const SizedBox(height: 8),
            ],
            if (f.rectification.isNotEmpty) ...[
              TinyLabel(context.tr('How to Rectify', 'कैसे सुधारें'),
                  icon: Icons.arrow_forward),
              const SizedBox(height: 4),
              Text(f.rectification,
                  style: TextStyle(fontSize: 12, color: t.foreground)),
              if (f.kind == FindingKind.ledgerOvercount ||
                  f.kind == FindingKind.duplicatePayments) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SmallButton(
                    label: context.tr(
                        'Open fix panel above', 'ऊपर सुधार पैनल खोलें'),
                    style: SmallBtnStyle.primary,
                    fontSize: 12,
                    onPressed: widget.onOpenAlarms,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            if (f.kind == FindingKind.ledgerOvercount &&
                ledgerIssues.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.warning, 0.05),
                  border: Border.all(color: AppTokens.tint(t.warning, 0.3)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TinyLabel(context.tr('Affected months (oldest first)',
                          'प्रभावित माह (पुराने पहले)')),
                      const SizedBox(height: 6),
                      for (final issue in stableSorted(
                          ledgerIssues,
                          (LedgerOvercountMonth a, LedgerOvercountMonth b) =>
                              jsLocaleCompare(a.month, b.month))) ...[
                        Text(
                          context.isHi
                              ? '${fmtIsoMonthToDisplay(issue.month)} — ${jsInr(issue.excess)} अतिरिक्त'
                              : '${fmtIsoMonthToDisplay(issue.month)} — ${jsInr(issue.excess)} extra',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        for (final e in issue.unlinkedLedger.take(4))
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(
                              '• ${context.tr('Orphan ledger', 'बिना लिंक लेजर')}: ${(e.title ?? '').isNotEmpty ? e.title : context.tr('Entry', 'प्रविष्टि')} · ${jsInr(e.totalAmount)}',
                              style: AppText.tiny(context),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ]),
              ),
              const SizedBox(height: 8),
            ],
            if (f.data != null) ...[
              TinyLabel(context.tr('Raw Data', 'कच्चा डेटा')),
              RawDataBox(data: f.data!),
            ],
          ],
        ],
      ),
    );
  }
}
