import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/audit_service.dart';
import '../logic/finance_audit_detection.dart';
import '../logic/js_compat.dart';
import 'audit_ui.dart';

/// Port of `FinanceLedgerOvercountPanel.tsx` — ledger double-count in period reports.
class FinanceLedgerOvercountPanel extends StatefulWidget {
  const FinanceLedgerOvercountPanel({super.key, required this.societyId, this.focusMonth, this.onResolved, this.refreshSeq = 0});

  final String societyId;

  /// When set, only show issues for this month.
  final String? focusMonth;
  final VoidCallback? onResolved;
  final int refreshSeq;

  @override
  State<FinanceLedgerOvercountPanel> createState() => _FinanceLedgerOvercountPanelState();
}

class _FinanceLedgerOvercountPanelState extends State<FinanceLedgerOvercountPanel> {
  final _service = const AuditService();
  List<LedgerOvercountMonth> _issues = const [];
  bool _loading = true;
  String? _expandedMonth;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  @override
  void didUpdateWidget(covariant FinanceLedgerOvercountPanel old) {
    super.didUpdateWidget(old);
    if (old.refreshSeq != widget.refreshSeq || old.societyId != widget.societyId || old.focusMonth != widget.focusMonth) _detect();
  }

  Future<void> _detect() async {
    setState(() => _loading = true);
    try {
      final d = await _service.fetchOvercountData(widget.societyId);
      var found = analyzeLedgerOvercountByMonth(d.payments, d.ledger);
      if (widget.focusMonth != null) found = found.where((x) => x.month == widget.focusMonth).toList();
      if (mounted) setState(() => _issues = found);
    } catch (_) {
      if (mounted) setState(() => _issues = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _afterFix() {
    _detect();
    widget.onResolved?.call();
  }

  Future<void> _deleteLedger(LedgerOvercountEntry e, String month) async {
    final hi = context.isHi;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Remove extra ledger receipt?', 'अतिरिक्त लेजर रसीद हटाएँ?'),
      message: hi
          ? 'यह ${fmtIsoMonthToDisplay(month)} की ${jsInr(e.totalAmount)} की बिना लिंक लेजर प्रविष्टि हटा देगा। अवधि रिपोर्ट इसे दोबारा गिनना बंद कर देंगी। जुड़े भुगतान प्रभावित नहीं होंगे।'
          : 'This deletes the orphan ledger entry of ${jsInr(e.totalAmount)} for ${fmtIsoMonthToDisplay(month)}. Period reports will stop double-counting it. Linked payments are not affected.',
      confirmLabel: context.tr('Delete ledger entry', 'लेजर प्रविष्टि हटाएँ'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = e.id);
    final res = await _service.deleteOrphanLedgerEntry(e.id, hi: hi);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context, context.tr('Ledger entry removed', 'लेजर प्रविष्टि हटाई गई'), tone: BadgeTone.success);
    _afterFix();
  }

  Future<void> _alignPayment(DateBoundaryMismatch row) async {
    setState(() => _busyId = row.payment.id);
    final res = await _service.alignPaymentDueToMonth(row.payment.id, row.entryMonth);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context, context.tr('Payment due date set to ${row.entryMonth}', 'भुगतान देय तिथि ${row.entryMonth} की गई'),
        tone: BadgeTone.success);
    _afterFix();
  }

  Future<void> _alignLedger(DateBoundaryMismatch row) async {
    setState(() => _busyId = row.entryId);
    final res = await _service.alignLedgerEntryMonth(row.entryId, row.paymentMonth);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context, context.tr('Ledger month set to ${row.paymentMonth}', 'लेजर माह ${row.paymentMonth} किया गया'),
        tone: BadgeTone.success);
    _afterFix();
  }

  String _field(String? v) => (v == null || v.isEmpty) ? '—' : v.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) {
      return CardSection(
        child: Text(context.tr('Scanning for ledger double-count in period reports…', 'अवधि रिपोर्ट में लेजर दोहरी गिनती जाँची जा रही है…'),
            style: AppText.body(context).copyWith(color: t.mutedForeground)),
      );
    }
    if (_issues.isEmpty) {
      return ToneCard(
        tone: Tone.success,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.menu_book_outlined, size: 16, color: t.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('No ledger double-count in period reports', 'अवधि रिपोर्ट में कोई लेजर दोहरी गिनती नहीं'),
                    style: AppText.bodyMedium(context).copyWith(color: t.success)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Receipt totals match verified payments — no extra unlinked finance ledger rows are inflating monthly reports.',
                'रसीदों का योग सत्यापित भुगतानों से मेल खाता है — कोई अतिरिक्त बिना लिंक लेजर पंक्ति मासिक रिपोर्ट नहीं बढ़ा रही।',
              ),
              style: AppText.caption(context),
            ),
          ],
        ),
      );
    }

    final totalExcess = _issues.fold(0.0, (s, i) => s + i.excess);
    final n = _issues.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.menu_book_outlined,
          tone: Tone.warning,
          titleColor: t.warning,
          title: context.tr('Ledger double-count (period reports)', 'लेजर दोहरी गिनती (अवधि रिपोर्ट)'),
          subtitle: context.isHi
              ? '${jsInr(totalExcess)} अतिरिक्त, $n माह में — यह डुप्लिकेट भुगतान पंक्तियों जैसा नहीं है'
              : '${jsInr(totalExcess)} extra across $n month${n > 1 ? 's' : ''} — not the same as duplicate payment rows',
          trailing: SquareIconButton(icon: Icons.refresh, onPressed: _detect, tooltip: context.tr('Refresh', 'रीफ्रेश')),
        ),
        const SizedBox(height: 12),
        for (final issue in _issues) ...[
          _issueCard(issue),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _issueCard(LedgerOvercountMonth issue) {
    final t = context.tokens;
    final hi = context.isHi;
    final expanded = _expandedMonth == issue.month;
    final m = fmtIsoMonthToDisplay(issue.month);
    return ToneCard(
      tone: Tone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandedMonth = expanded ? null : issue.month),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.warning_amber_rounded, size: 16, color: t.warning)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hi ? '$m — ${jsInr(issue.excess)} अधिक गिना गया' : '$m — ${jsInr(issue.excess)} over-counted',
                          style: AppText.sectionTitle(context)),
                      const SizedBox(height: 2),
                      Text(
                        hi
                            ? 'रिपोर्ट ${jsInr(issue.reportTotal)} दिखाती है, भुगतानों से ${jsInr(issue.paymentTotal)}'
                            : 'Report shows ${jsInr(issue.reportTotal)} vs ${jsInr(issue.paymentTotal)} from payments',
                        style: AppText.tiny(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Tap to fix — remove orphan ledger rows or align payment / ledger months',
                            'सुधारने के लिए टैप करें — बिना लिंक लेजर पंक्तियाँ हटाएँ या भुगतान / लेजर माह मिलाएँ'),
                        style: AppText.tiny(context),
                      ),
                    ],
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: t.mutedForeground),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTokens.tint(t.warning, 0.2)),
            const SizedBox(height: 12),
            if (issue.unlinkedLedger.isNotEmpty) ...[
              TinyLabel(context.tr('Extra ledger receipts (no linked payments)', 'अतिरिक्त लेजर रसीदें (कोई जुड़ा भुगतान नहीं)')),
              const SizedBox(height: 8),
              for (final e in issue.unlinkedLedger)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InnerBox(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((e.title ?? '').isNotEmpty ? e.title! : context.tr('Ledger entry', 'लेजर प्रविष्टि'),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium(context)),
                              Text(jsInr(e.totalAmount), style: AppText.mono(context, size: 12)),
                              Text(
                                '${_field(e.recordMode)} · ${_field(e.destination)} · ${fmtIsoMonthToDisplay((e.entryMonth ?? '').isNotEmpty ? e.entryMonth : issue.month)}',
                                style: AppText.tiny(context),
                              ),
                            ],
                          ),
                        ),
                        SquareIconButton(
                          icon: Icons.delete_outline,
                          tone: Tone.destructive,
                          busy: _busyId == e.id,
                          tooltip: context.tr('Delete this orphan ledger entry', 'यह बिना लिंक लेजर प्रविष्टि हटाएँ'),
                          onPressed: () => _deleteLedger(e, issue.month),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (issue.dateBoundary.isNotEmpty) ...[
              TinyLabel(context.tr('Payment month ≠ ledger month', 'भुगतान माह ≠ लेजर माह')),
              const SizedBox(height: 8),
              for (final row in issue.dateBoundary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InnerBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${context.t('common.flat')} ${row.payment.flatNumber} · ${jsInr(row.payment.amount)}', style: AppText.body(context)),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('Payment month', 'भुगतान माह')}: ${fmtIsoMonthToDisplay(row.paymentMonth)} · ${context.tr('Ledger month', 'लेजर माह')}: ${fmtIsoMonthToDisplay(row.entryMonth)}${(row.entryTitle ?? '').isNotEmpty ? ' · ${row.entryTitle}' : ''}',
                          style: AppText.tiny(context),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          SmallButton(
                            icon: Icons.calendar_month_outlined,
                            busy: _busyId == row.payment.id,
                            fontSize: 10,
                            label: hi
                                ? 'भुगतान ${fmtIsoMonthToDisplay(row.entryMonth)} पर करें'
                                : 'Set payment to ${fmtIsoMonthToDisplay(row.entryMonth)}',
                            onPressed: () => _alignPayment(row),
                          ),
                          SmallButton(
                            icon: Icons.calendar_month_outlined,
                            busy: _busyId == row.entryId,
                            fontSize: 10,
                            label: hi
                                ? 'लेजर ${fmtIsoMonthToDisplay(row.paymentMonth)} पर करें'
                                : 'Set ledger to ${fmtIsoMonthToDisplay(row.paymentMonth)}',
                            onPressed: () => _alignLedger(row),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
            ],
            if (issue.unlinkedLedger.isEmpty && issue.dateBoundary.isEmpty)
              Text(
                context.tr(
                  'Over-count detected but no automatic culprit listed. Use Manual Discrepancy Tracer for this month or review Finance → Receipts for duplicate bulk entries.',
                  'अधिक गिनती मिली पर कोई स्वचालित कारण सूचीबद्ध नहीं। इस माह के लिए मैन्युअल असंगति ट्रेसर का उपयोग करें या डुप्लिकेट बल्क प्रविष्टियों के लिए वित्त → रसीदें देखें।',
                ),
                style: AppText.caption(context),
              ),
          ],
        ],
      ),
    );
  }
}
