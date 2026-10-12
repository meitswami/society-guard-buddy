import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../data/audit_service.dart';
import '../logic/finance_audit_detection.dart';
import '../logic/js_compat.dart';
import 'audit_ui.dart';
import 'finance_ledger_overcount_panel.dart';

const _methods = [
  'cash',
  'upi',
  'bank_transfer',
  'cheque',
  'neft',
  'rtgs',
  'online'
];
const _statuses = ['verified', 'pending', 'rejected'];

String _methodLabel(BuildContext c, String m) => switch (m) {
      'cash' => c.tr('Cash', 'नकद'),
      'upi' => 'UPI',
      'bank_transfer' => c.tr('Bank Transfer', 'बैंक ट्रांसफर'),
      'cheque' => c.tr('Cheque', 'चेक'),
      'neft' => 'NEFT',
      'rtgs' => 'RTGS',
      'online' => c.tr('Online', 'ऑनलाइन'),
      _ => m,
    };

String _statusLabel(BuildContext c, String s) => switch (s) {
      'verified' => c.tr('Verified', 'सत्यापित'),
      'pending' => c.tr('Pending', 'लंबित'),
      'rejected' => c.tr('Rejected', 'अस्वीकृत'),
      _ => s,
    };

/// Port of `FinanceAuditAlarms.tsx`: ledger over-count panel, receipt-head lookup and
/// duplicate maintenance payment alarms with inline edit / delete.
class FinanceAuditAlarms extends StatefulWidget {
  const FinanceAuditAlarms(
      {super.key, required this.societyId, this.refreshSeq = 0});

  final String societyId;
  final int refreshSeq;

  @override
  State<FinanceAuditAlarms> createState() => _FinanceAuditAlarmsState();
}

class _FinanceAuditAlarmsState extends State<FinanceAuditAlarms> {
  final _service = const AuditService();
  List<DuplicatePaymentGroup> _alarms = const [];
  List<AuditPaymentRow> _allPayments = const [];
  List<ChargeOption> _charges = const [];
  bool _loading = true;
  int? _expandedIdx;
  int? _lookupExpandedIdx;

  // Edit state (one row at a time, shared between both lists like the web).
  String? _editId;
  final _editAmount = TextEditingController();
  final _editNotes = TextEditingController();
  String _editMethod = 'cash';
  String _editStatus = 'verified';
  bool _saving = false;
  String? _deletingId;

  final _lookupFlat = TextEditingController();
  final _lookupMonth = TextEditingController();
  String _lookupChargeId = '';
  List<DuplicatePaymentGroup> _lookupResults = const [];
  bool _lookupSearched = false;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  @override
  void didUpdateWidget(covariant FinanceAuditAlarms old) {
    super.didUpdateWidget(old);
    if (old.refreshSeq != widget.refreshSeq ||
        old.societyId != widget.societyId) _detect();
  }

  @override
  void dispose() {
    _editAmount.dispose();
    _editNotes.dispose();
    _lookupFlat.dispose();
    _lookupMonth.dispose();
    super.dispose();
  }

  Map<String, String> get _titleById =>
      {for (final c in _charges) c.id: c.title};

  Future<void> _detect() async {
    setState(() => _loading = true);
    try {
      final d = await _service.fetchAlarmData(widget.societyId);
      if (!mounted) return;
      final ids = d.charges.map((c) => c.id).toList();
      setState(() {
        _charges = d.charges;
        _allPayments = d.payments;
        _alarms = d.charges.isEmpty
            ? const []
            : findDuplicatePaymentGroups(
                d.payments, {for (final c in d.charges) c.id: c.title},
                chargeIds: ids, groupAcrossCharges: true);
      });
    } catch (_) {
      if (mounted) setState(() => _alarms = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bumpRefresh() => _detect();

  Future<void> _delete(AuditPaymentRow p) async {
    final hi = context.isHi;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr(
          'Delete this payment entry?', 'यह भुगतान प्रविष्टि हटाएँ?'),
      message: hi
          ? 'फ्लैट ${p.flatNumber} के लिए ${p.paymentMethod ?? ''} से ${jsInr(p.amount)}। इसे पूर्ववत नहीं किया जा सकता।'
          : '${jsInr(p.amount)} for Flat ${p.flatNumber} via ${p.paymentMethod ?? ''}. This cannot be undone.',
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deletingId = p.id);
    final res = await _service.deleteMaintenancePayment(p.id, p.financeEntryId);
    if (!mounted) return;
    setState(() => _deletingId = null);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context,
        context.tr('Payment entry deleted', 'भुगतान प्रविष्टि हटाई गई'),
        tone: BadgeTone.success);
    setState(() {
      _editId = null;
      _expandedIdx = null;
      _lookupExpandedIdx = null;
      _lookupResults = _lookupResults
          .map((g) => DuplicatePaymentGroup(
                flatNumber: g.flatNumber,
                chargeId: g.chargeId,
                chargeTitle: g.chargeTitle,
                month: g.month,
                paymentMethod: g.paymentMethod,
                count: g.payments.where((x) => x.id != p.id).length,
                totalAmount: g.payments
                    .where((x) => x.id != p.id)
                    .fold(0.0, (s, x) => s + x.amount),
                payments: g.payments.where((x) => x.id != p.id).toList(),
              ))
          .where((g) => g.payments.isNotEmpty)
          .toList();
    });
    _detect();
  }

  void _startEdit(AuditPaymentRow p) {
    setState(() {
      _editId = p.id;
      _editAmount.text = jsNumStr(p.amount);
      _editMethod = _methods.contains(p.paymentMethod)
          ? p.paymentMethod!
          : (p.paymentMethod ?? 'cash');
      _editStatus = p.paymentStatus;
      _editNotes.text = p.notes ?? '';
    });
  }

  Future<void> _saveEdit() async {
    final id = _editId;
    if (id == null) return;
    setState(() => _saving = true);
    final res = await _service.updatePayment(
      id,
      amount: double.tryParse(_editAmount.text.trim()) ?? 0,
      method: _editMethod,
      status: _editStatus,
      notes: _editNotes.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.ok) {
      AppFeedback.toast(context, res.error ?? '', tone: BadgeTone.alert);
      return;
    }
    AppFeedback.toast(context,
        context.tr('Payment entry updated', 'भुगतान प्रविष्टि अपडेट हुई'),
        tone: BadgeTone.success);
    setState(() => _editId = null);
    await _detect();
    if (_lookupSearched && mounted) _runLookup(silent: true);
  }

  void _runLookup({bool silent = false}) {
    final flat = _lookupFlat.text.trim();
    final month = _lookupMonth.text.trim();
    if (flat.isEmpty && _lookupChargeId.isEmpty && month.isEmpty) {
      if (!silent)
        AppFeedback.toast(context, context.t('finance.filterNeedOne'),
            tone: BadgeTone.alert);
      return;
    }
    setState(() {
      _lookupResults = findReceiptHeadLookupGroups(
        _allPayments,
        _titleById,
        ReceiptHeadLookupFilter(
          flatNumber: flat.isEmpty ? null : flat,
          chargeId: _lookupChargeId.isEmpty ? null : _lookupChargeId,
          month: month.isEmpty ? null : month,
        ),
      );
      _lookupSearched = true;
      _lookupExpandedIdx = null;
      if (!silent) _editId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceLedgerOvercountPanel(
            societyId: widget.societyId,
            onResolved: _bumpRefresh,
            refreshSeq: widget.refreshSeq),
        const SizedBox(height: 16),
        _lookupCard(),
        const SizedBox(height: 16),
        if (_loading)
          CardSection(
              child: Text(context.t('finance.scanningDuplicates'),
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground)))
        else if (_alarms.isEmpty)
          ToneCard(
            tone: Tone.success,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.currency_rupee, size: 16, color: t.success),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(context.t('finance.noDuplicateTitle'),
                          style: AppText.bodyMedium(context)
                              .copyWith(color: t.success))),
                ]),
                const SizedBox(height: 4),
                Text(context.t('finance.noDuplicateBody'),
                    style: AppText.caption(context)),
              ],
            ),
          )
        else ...[
          PanelHeader(
            icon: Icons.warning_amber_rounded,
            tone: Tone.destructive,
            titleColor: t.destructive,
            title: context.t('finance.duplicateDetectedTitle'),
            subtitle: context
                .t('finance.duplicateDetectedBody', {'count': _alarms.length}),
            trailing: SquareIconButton(
                icon: Icons.refresh,
                onPressed: _detect,
                tooltip: context.tr('Refresh', 'रीफ्रेश')),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _alarms.length; i++) ...[
            _groupCard(
                _alarms[i],
                _expandedIdx == i,
                () => setState(
                    () => _expandedIdx = _expandedIdx == i ? null : i)),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _lookupCard() {
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search, size: 16, color: context.tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('finance.findReceiptHeadTitle'),
                        style: AppText.sectionTitle(context)),
                    Text(context.t('finance.findReceiptHeadHint'),
                        style: AppText.tiny(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PanelInput(
              controller: _lookupFlat,
              hint: context.t('finance.flatPlaceholder')),
          const SizedBox(height: 8),
          AppDropdown<String>(
            items: ['', ..._charges.map((c) => c.id)],
            value: _lookupChargeId,
            labelOf: (id) => id.isEmpty
                ? context.t('finance.allReceiptHeads')
                : (_titleById[id] ?? id),
            onChanged: (v) => setState(() => _lookupChargeId = v ?? ''),
          ),
          const SizedBox(height: 8),
          PanelInput(
              controller: _lookupMonth,
              hint: context.t('finance.monthPlaceholder'),
              mono: true),
          const SizedBox(height: 12),
          AppButton(
              label: context.t('finance.searchRecorded'),
              onPressed: _runLookup),
          if (_lookupSearched && _lookupResults.isEmpty) ...[
            const SizedBox(height: 12),
            Text(context.t('finance.noMatchingReceiptHeads'),
                style: AppText.caption(context)),
          ],
          if (_lookupResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _lookupResults.length; i++) ...[
              _groupCard(
                  _lookupResults[i],
                  _lookupExpandedIdx == i,
                  () => setState(() =>
                      _lookupExpandedIdx = _lookupExpandedIdx == i ? null : i)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _groupCard(
      DuplicatePaymentGroup g, bool expanded, VoidCallback onToggle) {
    final t = context.tokens;
    final hi = context.isHi;
    final head = hi
        ? 'फ्लैट ${g.flatNumber} — ${g.count > 1 ? '${g.count}× जमा' : 'पहले से दर्ज'}, माध्यम '
        : 'Flat ${g.flatNumber} — ${g.count > 1 ? 'credited ${g.count}×' : 'already recorded'} via ';
    return ToneCard(
      tone: Tone.destructive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppTokens.tint(t.destructive, 0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded,
                      size: 16, color: t.destructive),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(
                          style: AppText.sectionTitle(context),
                          children: [
                            TextSpan(text: head),
                            TextSpan(
                                text: g.paymentMethod.toUpperCase(),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: t.destructive)),
                          ])),
                      const SizedBox(height: 2),
                      Text(
                          '${g.chargeTitle} · ${fmtIsoMonthToDisplay(g.month)}',
                          style: AppText.caption(context)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTokens.tint(t.destructive, 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          hi
                              ? '${jsInr(g.totalAmount)} कुल (${g.count} प्रविष्टि)'
                              : '${jsInr(g.totalAmount)} total (${g.count} entr${g.count > 1 ? 'ies' : 'y'})',
                          style: AppText.mono(context,
                              size: 12, color: t.destructive),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          context.tr(
                              'Tap to expand — edit or delete individual entries',
                              'खोलने के लिए टैप करें — अलग-अलग प्रविष्टियाँ संपादित करें या हटाएँ'),
                          style: AppText.tiny(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTokens.tint(t.destructive, 0.2)),
            const SizedBox(height: 12),
            for (final p in g.payments) ...[
              _paymentRow(p),
              const SizedBox(height: 8)
            ],
          ],
        ],
      ),
    );
  }

  Widget _paymentRow(AuditPaymentRow p) {
    final t = context.tokens;
    if (_editId == p.id) {
      return InnerBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: context.tr('Amount (₹)', 'राशि (₹)'),
                    controller: _editAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppDropdown<String>(
                    label: context.tr('Method', 'माध्यम'),
                    items: {..._methods, _editMethod}.toList(),
                    value: _editMethod,
                    labelOf: (m) => _methodLabel(context, m),
                    onChanged: (v) =>
                        setState(() => _editMethod = v ?? _editMethod),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppDropdown<String>(
              label: context.tr('Status', 'स्थिति'),
              items: {..._statuses, _editStatus}.toList(),
              value: _editStatus,
              labelOf: (s) => _statusLabel(context, s),
              onChanged: (v) => setState(() => _editStatus = v ?? _editStatus),
            ),
            const SizedBox(height: 8),
            AppTextField(
                label: context.tr('Notes', 'टिप्पणी'),
                controller: _editNotes,
                hint: context.tr('Optional note', 'वैकल्पिक टिप्पणी')),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              SmallButton(
                label: context.t('common.cancel'),
                icon: Icons.close,
                style: SmallBtnStyle.secondary,
                onPressed: () => setState(() => _editId = null),
              ),
              const SizedBox(width: 8),
              SmallButton(
                  label: context.t('common.save'),
                  icon: Icons.check,
                  style: SmallBtnStyle.primary,
                  busy: _saving,
                  onPressed: _saveEdit),
            ]),
          ],
        ),
      );
    }
    final statusTone = p.paymentStatus == 'verified'
        ? Tone.success
        : p.paymentStatus == 'rejected'
            ? Tone.destructive
            : Tone.warning;
    return InnerBox(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(jsInr(p.amount),
                          style: AppText.mono(context,
                              size: 14, weight: FontWeight.w600)),
                      TinyChip(_statusLabel(context, p.paymentStatus),
                          tone: statusTone),
                      if ((p.paymentMethod ?? '').isNotEmpty)
                        TinyChip(p.paymentMethod!),
                    ]),
                const SizedBox(height: 2),
                Text(
                  '${context.tr('Due', 'देय')}: ${(p.dueDate ?? '').isNotEmpty ? fmtIsoDateToDisplay(p.dueDate) : '—'} · ${context.tr('Created', 'बनाया')}: ${fmtIsoDateToDisplay(p.createdAt)}',
                  style: AppText.tiny(context),
                ),
                if ((p.transactionId ?? '').isNotEmpty)
                  Text('Txn: ${p.transactionId}',
                      style: AppText.mono(context,
                          size: 10, color: t.mutedForeground)),
                if ((p.notes ?? '').isNotEmpty)
                  Text(p.notes!,
                      style: AppText.tiny(context)
                          .copyWith(fontStyle: FontStyle.italic)),
                Text('ID: ${jsSlice(p.id, 0, 8)}',
                    style: AppText.mono(context,
                        size: 9,
                        color: AppTokens.tint(t.mutedForeground, 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareIconButton(
            icon: Icons.edit_outlined,
            tooltip: context.tr('Edit this entry', 'यह प्रविष्टि संपादित करें'),
            onPressed: () => _startEdit(p),
          ),
          const SizedBox(width: 6),
          SquareIconButton(
            icon: Icons.delete_outline,
            tone: Tone.destructive,
            busy: _deletingId == p.id,
            tooltip: context.tr('Delete this entry', 'यह प्रविष्टि हटाएँ'),
            onPressed: () => _delete(p),
          ),
        ],
      ),
    );
  }
}
