import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_repository.dart';
import '../data/query_helpers.dart';
import '../logic/contribution_rows.dart';
import '../logic/event_food_fund.dart';
import '../logic/finance_dates.dart';
import '../logic/js_compat.dart';
import '../logic/reconciliation.dart';
import '../widgets/cash_bank_breakdown.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';
import 'contribution_edit_sheet.dart';
import 'food_expense_edit_sheet.dart';

/// Port of `src/components/EventFoodReconciliation.tsx`.
class EventFoodReconciliationView extends StatefulWidget {
  const EventFoodReconciliationView({
    super.key,
    required this.societyId,
    required this.adminName,
    this.onRecordsChanged,
    this.hub,
    this.query = '',
  });

  final String societyId;
  final String adminName;
  final VoidCallback? onRecordsChanged;
  final EvReloadHub? hub;
  final String query;

  @override
  State<EventFoodReconciliationView> createState() => _EventFoodReconciliationViewState();
}

class _EventFoodReconciliationViewState extends State<EventFoodReconciliationView> {
  static const _repo = EventsRepository();

  ReconciliationData _data = ReconciliationData.empty;
  bool _loading = true;
  Object? _error;

  String? _adjustKey;
  String _adjustKind = EventFoodAdjustKind.shortfallCover;
  int _adjV = 0;
  String _adjAmount = '';
  String _adjSource = EventFoodAdjustSource.maintenancePool;
  String _adjFlat = '';
  String _adjMethod = 'cash';
  String _adjNotes = '';
  bool _savingAdj = false;

  @override
  void initState() {
    super.initState();
    widget.hub?.register(this, _loadAll);
    _loadAll();
  }

  @override
  void dispose() {
    widget.hub?.unregister(this);
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted && !_loading && _data.events.isEmpty && _data.foodExpenses.isEmpty) setState(() => _loading = true);
    try {
      final d = await _repo.loadReconciliation(widget.societyId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _handleSaved() {
    _loadAll();
    widget.onRecordsChanged?.call();
  }

  void _openAdjust(String eventKey, String kind, double suggested) {
    setState(() {
      _adjustKey = eventKey;
      _adjustKind = kind;
      _adjAmount = suggested > 0 ? jsNumStr(suggested) : '';
      _adjSource = kind == EventFoodAdjustKind.surplusToPool ? EventFoodAdjustSource.societyPool : EventFoodAdjustSource.maintenancePool;
      _adjFlat = '';
      _adjMethod = 'cash';
      _adjNotes = '';
      _adjV++;
    });
  }

  Future<void> _recordAdjustment(String eventKey, String kind) async {
    if (widget.societyId.isEmpty) return;
    final amount = jsNumber(_adjAmount);
    if (!jsPositive(amount)) {
      AppFeedback.toast(context, context.ev('efr.enterAmount'), tone: BadgeTone.alert);
      return;
    }
    if (kind == EventFoodAdjustKind.shortfallCover && _adjSource == EventFoodAdjustSource.memberAdvance && _adjFlat.trim().isEmpty) {
      AppFeedback.toast(context, context.ev('efr.enterFlat'), tone: BadgeTone.alert);
      return;
    }
    setState(() => _savingAdj = true);
    try {
      String? flatId;
      if (_adjSource == EventFoodAdjustSource.memberAdvance && _adjFlat.trim().isNotEmpty) {
        flatId = await _repo.flatIdByNumber(widget.societyId, _adjFlat.trim());
      }
      await _repo.insertAdjustment({
        'society_id': widget.societyId,
        'event_id': eventKey == kUnlinkedEventKey ? null : eventKey,
        'adjustment_kind': kind,
        'amount': amount,
        'source_type': kind == EventFoodAdjustKind.surplusToPool ? EventFoodAdjustSource.societyPool : _adjSource,
        'flat_number': _adjFlat.trim().isEmpty ? null : _adjFlat.trim(),
        'flat_id': flatId,
        'payment_method': _adjMethod,
        'notes': _adjNotes.trim().isEmpty ? null : _adjNotes.trim(),
        'created_by': widget.adminName,
      });
      if (!mounted) return;
      AppFeedback.toast(
        context,
        kind == EventFoodAdjustKind.surplusToPool ? context.ev('efr.surplusRecorded') : context.ev('efr.shortfallRecorded'),
        tone: BadgeTone.success,
      );
      setState(() => _adjustKey = null);
      _handleSaved();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _savingAdj = false);
    }
  }

  Future<void> _editContribution(String id) async {
    final saved = await ContributionEditSheet.show(context, contributionId: id, societyId: widget.societyId, adminName: widget.adminName);
    if (saved == true) _handleSaved();
  }

  Future<void> _editExpense(String id) async {
    final saved = await FoodExpenseEditSheet.show(context, expenseId: id);
    if (saved == true) _handleSaved();
  }

  bool _rowMatches(ReconRow r) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (r.event.title.toLowerCase().contains(q)) return true;
    if (r.expenses.any((e) => e.title.toLowerCase().contains(q) || e.groupName.toLowerCase().contains(q))) return true;
    return r.contribs.any((c) => contributionReceiptLabel(c).toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: EvHint(context.ev('efr.loading'), size: 12)));
    }
    if (_error != null) return ErrorView(message: supabaseErrorMessage(_error!), onRetry: _loadAll);

    final events = [
      for (final e in _data.events) ReconEvent(id: e.id, title: e.title, eventDate: e.eventDate, contributionAmount: e.contributionAmount),
    ];
    final totals =
        reconciliationTotals(contributions: _data.contributions, foodExpenses: _data.foodExpenses, adjustments: _data.adjustments);
    final allRows = reconciliationRows(
      events: events,
      contributions: _data.contributions,
      foodExpenses: _data.foodExpenses,
      adjustments: _data.adjustments,
      unlinkedTitle: context.ev('efr.unlinked'),
    );
    final rows = allRows.where(_rowMatches).toList();
    final b = totals.balance;

    var summary = context.ev('efr.summary', {
      'in': rupeeLoc(totals.contribIn),
      'out': rupeeLoc(totals.foodOut),
      'net': rupeeLoc(totals.net),
    });
    if (b.shortfallCovers > 0 || b.surplusTransfers > 0) {
      summary += ' · ${context.ev('efr.adjustedNet', {'amt': rupeeLoc(b.adjustedNet)})}';
    }

    return EvColumn(
      spacing: 12,
      children: [
        EvSummaryLine(
          label: summary,
          title: context.ev('efr.summaryTitle'),
          description: context.ev('efr.summaryDesc'),
          howCalculated: context.ev('efr.summaryHow'),
        ),
        if (b.remainingShortfall > 0 || b.remainingSurplus > 0)
          CardSection(
            padding: const EdgeInsets.all(12),
            borderColor: AppTokens.tint(t.primary, 0.2),
            child: EvColumn(
              children: [
                Text(context.ev('efr.societyWide'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (b.remainingShortfall > 0)
                  EvCallout(
                    color: t.destructive,
                    child: Text(
                      context.ev('efr.shortfallAll', {'amt': rupeeLoc(b.remainingShortfall)}),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.destructive),
                    ),
                  ),
                if (b.remainingSurplus > 0)
                  EvCallout(
                    color: t.success,
                    icon: Icons.swap_horiz,
                    child: Text(
                      context.ev('efr.excessAll', {'amt': rupeeLoc(b.remainingSurplus)}),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.success),
                    ),
                  ),
                if (b.shortfallCovers > 0) EvHint(context.ev('efr.coveredSoFar', {'amt': rupeeLoc(b.shortfallCovers)}), color: t.accent),
                if (b.surplusTransfers > 0) EvHint(context.ev('efr.transferredSoFar', {'amt': rupeeLoc(b.surplusTransfers)})),
              ],
            ),
          ),
        CashBankBreakdown(
          receipts: totals.receiptChannels,
          payments: totals.paymentChannels,
          receiptLabel: context.ev('efr.contribReceipts'),
          paymentLabel: context.ev('efr.foodBills'),
        ),
        if (allRows.isEmpty)
          CardSection(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.balance, size: 32, color: AppTokens.tint(t.mutedForeground, 0.5)),
                const SizedBox(height: 8),
                Text(context.ev('efr.empty'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: t.mutedForeground)),
                const SizedBox(height: 4),
                EvRichHint(context.ev('efr.emptyHint'), size: 12),
              ],
            ),
          )
        else if (rows.isEmpty)
          EmptyView(message: context.ev('evc.noMatch', {'q': widget.query.trim()}))
        else
          for (final r in rows) _rowCard(context, r),
      ],
    );
  }

  Widget _rowCard(BuildContext context, ReconRow r) {
    final t = context.tokens;
    final ev = r.event;
    final rawNet = r.rawNet;
    final words = contribWords(context);
    return CardSection(
      child: EvColumn(
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ev.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (ev.eventDate.isNotEmpty) EvHint(fmtIsoDateToDisplay(ev.eventDate)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _amountLine(Icons.trending_up, context.ev('efr.in', {'amt': rupeeLoc(r.contribIn)}), t.success),
                  _amountLine(Icons.trending_down, context.ev('efr.out', {'amt': rupeeLoc(r.foodOut)}), t.warning),
                  if (r.shortfallCovers > 0)
                    _amountLine(Icons.add, context.ev('efr.covered', {'amt': rupeeLoc(r.shortfallCovers)}), t.accent),
                  if (r.surplusTransfers > 0)
                    _amountLine(Icons.swap_horiz, context.ev('efr.toPoolAmt', {'amt': rupeeLoc(r.surplusTransfers)}), t.mutedForeground),
                  Text(
                    context.ev('efr.rawNet', {'amt': rupeeLoc(rawNet)}),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: rawNet >= 0 ? t.foreground : t.destructive),
                  ),
                  if (r.shortfallCovers > 0 || r.surplusTransfers > 0)
                    Text(
                      context.ev('efr.adjustedNet', {'amt': rupeeLoc(r.adjustedNet)}),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: r.adjustedNet >= 0 ? t.primary : t.destructive),
                    ),
                ],
              ),
            ],
          ),
          if (r.remainingShortfall > 0)
            EvCallout(
              color: t.destructive,
              icon: Icons.warning_amber_rounded,
              action: EvTintButton(
                label: context.ev('efr.cover'),
                onTap: () => _openAdjust(ev.id, EventFoodAdjustKind.shortfallCover, r.remainingShortfall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.ev('efr.shortOfFunds', {'amt': rupeeLoc(r.remainingShortfall)}),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.destructive),
                  ),
                  const SizedBox(height: 2),
                  EvHint(context.ev('efr.shortHint')),
                ],
              ),
            ),
          if (r.remainingSurplus > 0)
            EvCallout(
              color: t.success,
              icon: Icons.swap_horiz,
              action: EvTintButton(
                label: context.ev('efr.toPool'),
                onTap: () => _openAdjust(ev.id, EventFoodAdjustKind.surplusToPool, r.remainingSurplus),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.ev('efr.excess', {'amt': rupeeLoc(r.remainingSurplus)}),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.success),
                  ),
                  const SizedBox(height: 2),
                  EvHint(context.ev('efr.excessHint')),
                ],
              ),
            ),
          if (_adjustKey == ev.id) _adjustForm(context, ev.id),
          if (r.eventAdjustments.isNotEmpty)
            EvColumn(
              spacing: 4,
              children: [
                EvTinyLabel(context.ev('efr.adjustments'), bold: true),
                for (final a in r.eventAdjustments)
                  EvMutedBox(
                    color: AppTokens.tint(t.accent, 0.06),
                    child: Text(
                      '${a.adjustmentKind == EventFoodAdjustKind.surplusToPool ? context.ev('efr.arrowPool') : context.ev('efr.arrowCover')} '
                      '${rupeeLoc(a.amount)} — ${context.ev('efr.source.${a.sourceType}')}'
                      '${(a.flatNumber ?? '').isNotEmpty ? ' (${words.flat} ${a.flatNumber})' : ''}'
                      '${(a.notes ?? '').isNotEmpty ? ' · ${a.notes}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          if (r.contribIn > 0 || r.foodOut > 0)
            CashBankBreakdown(
              variant: CashBankVariant.compact,
              receipts: r.receiptChannels,
              payments: r.paymentChannels,
              receiptLabel: context.ev('efr.contributions'),
              paymentLabel: context.ev('efr.foodBills'),
            ),
          if (r.contribs.isNotEmpty)
            EvColumn(
              spacing: 4,
              children: [
                EvTinyLabel(context.ev('efr.contribReceipts'), icon: Icons.receipt_long, bold: true),
                for (final c in r.contribs)
                  EvMutedBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(contributionReceiptLabel(c, words), style: const TextStyle(fontSize: 12)),
                                  ChannelBadge(method: c.paymentMethod),
                                ],
                              ),
                            ),
                            Text(rupeeLoc(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            EvMiniChip(icon: Icons.edit_outlined, label: context.ev('evc.edit'), onTap: () => _editContribution(c.id)),
                          ],
                        ),
                        if ((c.screenshotUrl ?? '').isNotEmpty)
                          EvLink(context.ev('efr.viewProof'), onTap: () => openEvUrl(context, c.screenshotUrl!))
                        else
                          EvHint(context.ev('evc.noAttachment')),
                      ],
                    ),
                  ),
              ],
            ),
          if (r.expenses.isNotEmpty)
            EvColumn(
              spacing: 4,
              children: [
                EvTinyLabel(context.ev('efr.foodBillReceipts'), icon: Icons.attach_file, bold: true),
                for (final ex in r.expenses)
                  () {
                    final links = foodReceiptLinks(ex);
                    return EvMutedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(ex.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ChannelBadge(method: ex.paymentMethod),
                                  ],
                                ),
                              ),
                              Text(rupeeLoc(ex.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              EvMiniChip(icon: Icons.edit_outlined, label: context.ev('evc.edit'), onTap: () => _editExpense(ex.id)),
                            ],
                          ),
                          EvHint(
                            '${ex.groupName} · ${paymentMethodLabel(context, ex.paymentMethod)} · ${fmtIsoDateToDisplay(ex.expenseDate)}',
                          ),
                          if (links.isEmpty)
                            EvHint(context.ev('efr.noBill'))
                          else
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final l in links)
                                  EvLink(l.isBill ? context.ev('efr.billReceipt') : l.label, onTap: () => openEvUrl(context, l.url)),
                              ],
                            ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _amountLine(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 12, color: color), const SizedBox(width: 3), Text(text, style: TextStyle(fontSize: 12, color: color))],
      );

  Widget _adjustForm(BuildContext context, String eventKey) {
    final kind = _adjustKind;
    return EvPanel(
      padding: const EdgeInsets.all(12),
      children: [
        Text(context.ev('efr.kind.$kind'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        AppTextField(
          key: ValueKey('adj-amount-$_adjV'),
          hint: context.ev('evc.amountRs'),
          initialValue: _adjAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => _adjAmount = v,
        ),
        if (kind == EventFoodAdjustKind.shortfallCover) ...[
          AppDropdown<String>(
            items: EventFoodAdjustSource.all,
            value: _adjSource,
            labelOf: (s) => context.ev('efr.source.$s'),
            onChanged: (v) => setState(() => _adjSource = v ?? EventFoodAdjustSource.maintenancePool),
          ),
          if (_adjSource == EventFoodAdjustSource.memberAdvance)
            AppTextField(
              key: ValueKey('adj-flat-$_adjV'),
              hint: context.ev('efr.flatNumber'),
              initialValue: _adjFlat,
              onChanged: (v) => _adjFlat = v,
            ),
        ] else
          EvHint(context.ev('efr.destination', {'dest': context.ev('efr.source.society_pool')})),
        AppDropdown<String>(
          items: const ['cash', 'upi', 'bank_transfer'],
          value: _adjMethod,
          labelOf: (m) => m == 'upi' ? context.ev('pm.upiBank') : paymentMethodLabel(context, m),
          onChanged: (v) => setState(() => _adjMethod = v ?? 'cash'),
        ),
        AppTextField(
          key: ValueKey('adj-notes-$_adjV'),
          hint: context.ev('efr.notesOptional'),
          initialValue: _adjNotes,
          onChanged: (v) => _adjNotes = v,
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                dense: true,
                label: _savingAdj ? context.ev('evc.saving') : context.t('common.save'),
                loading: _savingAdj,
                onPressed: () => _recordAdjustment(eventKey, kind),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  AppButton.secondary(dense: true, label: context.t('common.cancel'), onPressed: () => setState(() => _adjustKey = null)),
            ),
          ],
        ),
      ],
    );
  }
}
