// Port of FinanceRecordPaymentTab (+ HeadFundReconciliation). The ExpenseSplitter
// (society payment recorder) belongs to the EVENTS module and is opened via AdminTab.splits.

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../core/admin_module.dart';
import '../data/finance_repository.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/head_fund_match.dart';
import '../state/finance_controller.dart';
import '../widgets/cash_bank_breakdown.dart';
import '../widgets/fin_kit.dart';

class FinanceRecordPaymentTab extends StatefulWidget {
  const FinanceRecordPaymentTab(
      {super.key,
      required this.c,
      required this.ctx,
      required this.onOpenRecordReceipt});

  final FinanceController c;
  final AdminModuleContext ctx;
  final VoidCallback onOpenRecordReceipt;

  @override
  State<FinanceRecordPaymentTab> createState() =>
      _FinanceRecordPaymentTabState();
}

class _FinanceRecordPaymentTabState extends State<FinanceRecordPaymentTab> {
  bool _showRecon = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(
            'Record society outflows (electricity, vendors, repairs) and split across flats — same pattern as Record receipt for inflows. Event food/catering → Events & food.',
            'सोसाइटी जावक (बिजली, विक्रेता, मरम्मत) दर्ज करें और फ्लैटों में बाँटें — आवक के लिए रसीद दर्ज करें जैसा ही। कार्यक्रम भोजन/कैटरिंग → कार्यक्रम व भोजन।',
          ),
          style: AppText.caption(context),
        ),
        const SizedBox(height: 12),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                  context.tr(
                      'Record society payment', 'सोसाइटी भुगतान दर्ज करें'),
                  icon: Icons.receipt_long_outlined),
              Text(
                context.tr(
                  'Payment heads, vendor bills, bill photos and per-flat splits are recorded in the expense splitter (payment heads only). Saved payments post a separate-entry ledger row and show up in Transactions and Totals.',
                  'भुगतान शीर्ष, विक्रेता बिल, बिल फ़ोटो और प्रति फ्लैट बँटवारा व्यय विभाजक में दर्ज होते हैं (केवल भुगतान शीर्ष)। सहेजे भुगतान अलग-प्रविष्टि खाता पंक्ति बनाते हैं और लेन-देन व कुल योग में दिखते हैं।',
                ),
                style: AppText.caption(context),
              ),
              const SizedBox(height: 12),
              AppButton(
                icon: Icons.open_in_new,
                label:
                    context.tr('Open Record payment', 'भुगतान दर्ज करना खोलें'),
                onPressed: () =>
                    widget.ctx.goTo(AdminTab.splits, subTab: 'payment'),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppTokens.tint(t.border, 0.6)))),
          child: AppButton.secondary(
            icon: Icons.balance_outlined,
            label: _showRecon
                ? context.tr(
                    'Hide head fund reconciliation', 'शीर्ष निधि मिलान छिपाएँ')
                : context.tr('Head fund reconciliation', 'शीर्ष निधि मिलान'),
            onPressed: () => setState(() => _showRecon = !_showRecon),
          ),
        ),
        if (_showRecon)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ListenableBuilder(
              listenable: widget.c,
              builder: (_, __) => HeadFundReconciliation(
                key: ValueKey('recon-${widget.c.headReconciliationKey}'),
                c: widget.c,
                onOpenRecordReceipt: widget.onOpenRecordReceipt,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeadRow {
  _HeadRow(this.group, this.chargeTitles, this.contribs, this.expenses,
      this.adjustments);

  final HeadFundGroup group;
  final List<String> chargeTitles;
  final List<HeadFundContribution> contribs;
  final List<HeadFundExpense> expenses;
  final List<HeadFundAdjustment> adjustments;

  double get contribIn => contribs.fold(0.0, (s, x) => s + x.amount);
  double get adjustIn => adjustments.fold(0.0, (s, x) => s + x.amount);
  double get expenseOut => expenses.fold(0.0, (s, x) => s + x.totalAmount);
  double get net => contribIn + adjustIn - expenseOut;
  double get shortfall {
    final v = expenseOut - contribIn - adjustIn;
    return v > 0 ? v : 0;
  }
}

/// Web `HeadFundReconciliation`.
class HeadFundReconciliation extends StatefulWidget {
  const HeadFundReconciliation(
      {super.key, required this.c, this.onOpenRecordReceipt});

  final FinanceController c;
  final VoidCallback? onOpenRecordReceipt;

  @override
  State<HeadFundReconciliation> createState() => _HeadFundReconciliationState();
}

class _HeadFundReconciliationState extends State<HeadFundReconciliation> {
  HeadFundData? _data;
  bool _loading = true;
  String? _adjustGroup;
  final _amount = TextEditingController();
  final _flat = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'maintenance_pool';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _flat.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await widget.c.repo.fetchHeadFundData(widget.c.societyId);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  List<_HeadRow> _rows(HeadFundData d) {
    final chargeByGroup = <String, List<String>>{};
    for (final ch in d.charges) {
      if ((ch.expenseGroupId ?? '').isEmpty) continue;
      chargeByGroup.putIfAbsent(ch.expenseGroupId!, () => []).add(ch.title);
    }
    final contribByGroup = <String, List<HeadFundContribution>>{};
    for (final x in d.contributions) {
      contribByGroup.putIfAbsent(x.groupId, () => []).add(x);
    }
    bool matches(HeadFundGroup g, HeadFundExpense e) =>
        expenseMatchesHead(g.name,
            title: e.title,
            vendorOrService: e.vendorOrService,
            groupName: e.groupName);
    final candidates = d.groups.where((g) =>
        chargeByGroup.containsKey(g.id) ||
        (contribByGroup[g.id]?.isNotEmpty ?? false) ||
        d.expenses.any((e) => e.groupId == g.id || matches(g, e)) ||
        d.adjustments.any((a) => a.expenseGroupId == g.id));
    final rows = <_HeadRow>[];
    for (final g in candidates) {
      final matched = <HeadFundExpense>[];
      for (final e in d.expenses) {
        final inGroup = e.groupId == g.id;
        final correlated = !inGroup && matches(g, e);
        if (inGroup || correlated) matched.add(e.asCorrelated(correlated));
      }
      final row = _HeadRow(
        g,
        chargeByGroup[g.id] ?? const [],
        contribByGroup[g.id] ?? const [],
        matched,
        d.adjustments.where((a) => a.expenseGroupId == g.id).toList(),
      );
      if (row.contribIn > 0 ||
          row.adjustIn > 0 ||
          row.expenseOut > 0 ||
          chargeByGroup.containsKey(g.id)) {
        rows.add(row);
      }
    }
    rows.sort((a, b) => compareText(a.group.name, b.group.name));
    return rows;
  }

  Future<void> _record(String groupId, double shortfall) async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      AppFeedback.toast(context,
          context.tr('Enter adjustment amount', 'समायोजन राशि दर्ज करें'),
          tone: BadgeTone.alert);
      return;
    }
    if (_source == 'member_advance' && _flat.text.trim().isEmpty) {
      AppFeedback.toast(
          context,
          context.tr('Enter flat number for member advance',
              'सदस्य अग्रिम के लिए फ्लैट नंबर दर्ज करें'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.c.repo.insertHeadAdjustment(
        societyId: widget.c.societyId,
        groupId: groupId,
        amount: amount,
        sourceType: _source,
        flatNumber: _flat.text,
        notes: _notes.text,
        adminName: widget.c.adminName,
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        shortfall > 0 && amount >= shortfall
            ? context.tr(
                'Shortfall covered — head balanced', 'कमी पूरी — शीर्ष संतुलित')
            : context.tr('Adjustment recorded', 'समायोजन दर्ज हुआ'),
        tone: BadgeTone.success,
      );
      setState(() {
        _adjustGroup = null;
        _amount.clear();
        _flat.clear();
        _notes.clear();
        _source = 'maintenance_pool';
      });
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, financeErrorMessage(e),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _srcLabel(String k) => context.lang == AppLang.hi
      ? (kHeadAdjustmentSourceLabelsHi[k] ?? k)
      : (kHeadAdjustmentSourceLabels[k] ?? k);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = _data;
    if (_loading || d == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
            context.tr(
                'Loading head reconciliation…', 'शीर्ष मिलान लोड हो रहा है…'),
            textAlign: TextAlign.center,
            style: AppText.caption(context)),
      );
    }
    final rows = _rows(d);
    if (rows.isEmpty) {
      return CardSection(
        child: Column(
          children: [
            Icon(Icons.balance_outlined,
                size: 28, color: AppTokens.tint(t.mutedForeground, 0.5)),
            const SizedBox(height: 8),
            Text(
                context.tr('No linked expense heads yet.',
                    'अभी कोई जुड़ा व्यय शीर्ष नहीं।'),
                style:
                    AppText.body(context).copyWith(color: t.mutedForeground)),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Create a receipt type under Create Receipts and link it to a payment head, or add expenses under Record payment.',
                'बनाएँ में रसीद प्रकार बनाकर भुगतान शीर्ष से जोड़ें, या भुगतान दर्ज करें में व्यय जोड़ें।',
              ),
              textAlign: TextAlign.center,
              style: AppText.caption(context),
            ),
          ],
        ),
      );
    }
    final receiptCh = sumByChannel<HeadFundContribution>(
        d.contributions, (x) => x.amount, (x) => x.paymentMethod);
    final paymentCh = sumByChannel<HeadFundExpense>(
        d.expenses, (x) => x.totalAmount, (x) => x.paymentMethod);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSummaryLine(
          label: context.tr('Head fund reconciliation', 'शीर्ष निधि मिलान'),
          description: context.tr(
            'Contributions collected (receipt type linked to head) vs expenses incurred under the same head. Cash and bank shown separately.',
            'शीर्ष से जुड़े रसीद प्रकार से एकत्र योगदान बनाम उसी शीर्ष के व्यय। नकद और बैंक अलग दिखते हैं।',
          ),
          howCalculated: context.tr(
            'Contributions = maintenance_payments on linked charges. Expenses = payment expenses in the head group + correlated items. Channel from payment_method.',
            'योगदान = जुड़े शुल्कों के maintenance_payments। व्यय = शीर्ष समूह के भुगतान व्यय + मेल खाते आइटम। माध्यम payment_method से।',
          ),
        ),
        CashBankBreakdown(
          receipts: receiptCh,
          payments: paymentCh,
          receiptLabel: context.tr(
              'Head contributions (receipts)', 'शीर्ष योगदान (रसीदें)'),
          paymentLabel:
              context.tr('Head expenses (payments)', 'शीर्ष व्यय (भुगतान)'),
        ),
        const SizedBox(height: 12),
        for (final r in rows) _headCard(context, r),
      ],
    );
  }

  Widget _headCard(BuildContext context, _HeadRow r) {
    final t = context.tokens;
    final g = r.group;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: AppText.sectionTitle(context)),
                    if ((g.majorHead ?? '').isNotEmpty)
                      Text(g.majorHead!, style: AppText.tiny(context)),
                    if (r.chargeTitles.isNotEmpty)
                      Text(
                          '${context.tr('Receipt type', 'रसीद प्रकार')}: ${r.chargeTitles.join(', ')}',
                          style: AppText.tiny(context)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      '↑ ${inrLocale(r.contribIn)} ${context.tr('collected', 'एकत्र')}',
                      style: TextStyle(fontSize: 12, color: t.success)),
                  if (r.adjustIn > 0)
                    Text(
                        '+ ${inrLocale(r.adjustIn)} ${context.tr('adjusted', 'समायोजित')}',
                        style: TextStyle(fontSize: 12, color: t.accent)),
                  Text(
                      '↓ ${inrLocale(r.expenseOut)} ${context.tr('spent', 'खर्च')}',
                      style: TextStyle(fontSize: 12, color: t.warning)),
                  Text('${context.tr('Net', 'शुद्ध')} ${inrLocale(r.net)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: r.net >= 0 ? t.foreground : t.destructive)),
                ],
              ),
            ],
          ),
          if (r.contribIn > 0 || r.expenseOut > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CashBankBreakdown(
                variant: CashBankVariant.compact,
                receipts: sumByChannel<HeadFundContribution>(
                    r.contribs, (x) => x.amount, (x) => x.paymentMethod),
                payments: sumByChannel<HeadFundExpense>(
                    r.expenses, (x) => x.totalAmount, (x) => x.paymentMethod),
                receiptLabel: context.tr('Contributions', 'योगदान'),
                paymentLabel: context.tr('Expenses', 'व्यय'),
              ),
            ),
          if (r.shortfall > 0)
            FinTintBox(
              color: t.destructive,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: t.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${context.tr('Short of funds', 'निधि की कमी')}: ${inrLocale(r.shortfall)}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: t.destructive)),
                        FinHint(context.tr(
                          'Contributions + adjustments are less than expenses. Record member top-up, draw from maintenance collections, or corpus.',
                          'योगदान + समायोजन व्यय से कम हैं। सदस्य टॉप-अप दर्ज करें, रखरखाव संग्रह या कॉर्पस से लें।',
                        )),
                        if (widget.onOpenRecordReceipt != null &&
                            r.contribs.isEmpty)
                          InkWell(
                            onTap: widget.onOpenRecordReceipt,
                            child: Text(
                              context.tr(
                                  'Record flat contributions (Create Receipts / Record receipt)',
                                  'फ्लैट योगदान दर्ज करें (रसीद बनाएँ / दर्ज करें)'),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: t.primary,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                      ],
                    ),
                  ),
                  FinMiniButton(
                    color: t.primary,
                    label: context.tr('Adjust', 'समायोजित करें'),
                    onTap: () => setState(() {
                      _adjustGroup = g.id;
                      _amount.text = numToText(r.shortfall);
                    }),
                  ),
                ],
              ),
            ),
          if (_adjustGroup == g.id)
            FinTintBox(
              margin: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      context.tr('Record shortfall adjustment',
                          'कमी समायोजन दर्ज करें'),
                      style:
                          AppText.bodyMedium(context).copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _amount,
                    hint: context.tr('Amount (₹)', 'राशि (₹)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kAmountFormatters,
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String>(
                    items: kHeadAdjustmentSourceLabels.keys.toList(),
                    value: _source,
                    labelOf: _srcLabel,
                    onChanged: (v) =>
                        setState(() => _source = v ?? 'maintenance_pool'),
                  ),
                  if (_source == 'member_advance') ...[
                    const SizedBox(height: 8),
                    AppTextField(
                        controller: _flat,
                        hint: context.tr('Flat number', 'फ्लैट नंबर')),
                  ],
                  const SizedBox(height: 8),
                  AppTextField(
                      controller: _notes,
                      caps: false,
                      hint:
                          context.tr('Notes (optional)', 'टिप्पणी (वैकल्पिक)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: _saving
                              ? context.tr('Saving…', 'सहेजा जा रहा है…')
                              : context.tr('Save adjustment', 'समायोजन सहेजें'),
                          loading: _saving,
                          onPressed: () => _record(g.id, r.shortfall),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: AppButton.secondary(
                              label: context.fin('fin.cancel'),
                              onPressed: () =>
                                  setState(() => _adjustGroup = null))),
                    ],
                  ),
                ],
              ),
            ),
          if (r.contribs.isNotEmpty) ...[
            const SizedBox(height: 12),
            FinMicroLabel(context.tr('Contribution receipts', 'योगदान रसीदें')),
            for (final x in r.contribs)
              _line(
                context,
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        '${context.tr('Flat', 'फ्लैट')} ${x.flatNumber}${(x.residentName ?? '').isNotEmpty ? ' · ${x.residentName}' : ''}',
                        style: AppText.body(context).copyWith(fontSize: 12)),
                    FinChannelBadge(method: x.paymentMethod),
                  ],
                ),
                inrLocale(x.amount),
              ),
          ],
          if (r.expenses.isNotEmpty) ...[
            const SizedBox(height: 12),
            FinMicroLabel(context.tr('Expenses incurred', 'हुए व्यय')),
            for (final x in r.expenses)
              _line(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(x.title,
                            style: AppText.bodyMedium(context)
                                .copyWith(fontSize: 12)),
                        FinChannelBadge(method: x.paymentMethod),
                        if (x.correlated)
                          Text(context.tr('(linked)', '(जुड़ा)'),
                              style: AppText.tiny(context)),
                      ],
                    ),
                    Text(
                      '${x.groupName}${(x.vendorOrService ?? '').isNotEmpty ? ' · ${x.vendorOrService}' : ''} · ${isoDateToDisplay(x.expenseDate)}',
                      style: AppText.tiny(context),
                    ),
                  ],
                ),
                inrLocale(x.totalAmount),
              ),
          ],
          if (r.adjustments.isNotEmpty) ...[
            const SizedBox(height: 12),
            FinMicroLabel(context.tr('Adjustments', 'समायोजन')),
            for (final a in r.adjustments)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.accent, 0.05),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '${inrLocale(a.amount)} — ${_srcLabel(a.sourceType)}'
                  '${(a.flatNumber ?? '').isNotEmpty ? ' (${context.tr('Flat', 'फ्लैट')} ${a.flatNumber})' : ''}'
                  '${(a.notes ?? '').isNotEmpty ? ' · ${a.notes}' : ''}',
                  style: AppText.body(context).copyWith(fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String numToText(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  Widget _line(BuildContext context, Widget left, String amount) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppTokens.tint(context.tokens.muted, 0.4),
            borderRadius: BorderRadius.circular(4)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            Text(amount,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
          ],
        ),
      );
}
