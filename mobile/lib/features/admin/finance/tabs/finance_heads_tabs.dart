// Ports of FinanceMaintenanceTab (receipt types) and FinanceCreatePaymentTab (payment types)
// with FinanceManager's addCharge / deleteCharge / addPaymentHead / deletePaymentGroup.

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/finance_repository.dart';
import '../logic/finance_expense_head.dart';
import '../logic/finance_format.dart';
import '../logic/finance_models.dart';
import '../state/finance_controller.dart';
import '../state/finance_forms.dart';
import '../widgets/fin_kit.dart';

const _frequencies = ['monthly', 'quarterly', 'yearly', 'one-time'];
const _newSubHead = '__new__';

Widget _majorHeading(BuildContext context, String major) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTokens.tint(context.tokens.border, 0.6)))),
      child: Text(major.toUpperCase(),
          style: AppText.tiny(context).copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
    );

/// Create → Receipt type.
class FinanceMaintenanceTab extends StatelessWidget {
  const FinanceMaintenanceTab({super.key, required this.c, required this.form});

  final FinanceController c;
  final ChargeFormModel form;

  Future<void> _save(BuildContext context) async {
    final title = form.title.text.trim().isEmpty ? '' : form.title.text;
    if (title.isEmpty || form.amount.text.trim().isEmpty) {
      AppFeedback.toast(context, context.tr('Enter title and amount', 'शीर्षक और राशि दर्ज करें'), tone: BadgeTone.alert);
      return;
    }
    String? groupId = form.expenseGroupId.isNotEmpty && form.expenseGroupId != _newSubHead ? form.expenseGroupId : null;
    try {
      if (form.expenseGroupId == _newSubHead) {
        if (form.majorHead.isEmpty) {
          AppFeedback.toast(context, context.tr('Choose a major head for the new payment sub-head', 'नए भुगतान उप-शीर्ष के लिए मुख्य शीर्ष चुनें'),
              tone: BadgeTone.alert);
          return;
        }
        final subName = form.newSubHead.text.trim().isNotEmpty ? form.newSubHead.text.trim() : title.trim();
        groupId = await c.repo.createExpenseGroup(
          societyId: c.societyId,
          name: subName,
          majorHead: form.majorHead,
          createdBy: c.adminName,
        );
      }
      final input = ChargeInput(
        title: title,
        amount: double.tryParse(form.amount.text.trim()) ?? 0,
        frequency: form.frequency,
        dueDay: c.settings.dueDay,
        expenseGroupId: groupId,
      );
      final editing = form.editingId;
      if (editing != null) {
        await c.repo.updateCharge(c.societyId, editing, input);
      } else {
        await c.repo.insertCharge(c.societyId, c.adminName, input);
      }
      await c.invalidateAll();
      if (!context.mounted) return;
      AppFeedback.toast(
        context,
        editing != null ? context.tr('Receipt type updated', 'रसीद प्रकार अपडेट हुआ') : context.tr('Receipt type added', 'रसीद प्रकार जोड़ा गया'),
        tone: BadgeTone.success,
      );
      form
        ..editingId = null
        ..reset()
        ..showForm = false
        ..changed();
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.toast(
        context,
        financeErrorMessage(e, form.editingId != null ? 'Could not update receipt type' : 'Could not add receipt type'),
        tone: BadgeTone.alert,
      );
    }
  }

  void _startEdit(FinanceCharge ch) {
    final g = ch.expenseGroupId != null ? c.derived.paymentGroupById[ch.expenseGroupId] : null;
    form
      ..editingId = ch.id
      ..title.text = ch.title
      ..amount.text = numToInput(ch.amount)
      ..frequency = ch.frequency.isEmpty ? 'monthly' : ch.frequency
      ..majorHead = g != null ? resolveGroupMajorHeadOf(g) : inferMajorHeadFromGroupName(ch.title)
      ..expenseGroupId = ch.expenseGroupId ?? ''
      ..newSubHead.clear()
      ..showForm = true
      ..changed();
  }

  Future<void> _delete(BuildContext context, String id) async {
    final d = c.data;
    if (d.payments.any((p) => p.chargeId == id) || d.ledgerEntries.any((e) => e.chargeId == id)) {
      AppFeedback.toast(
        context,
        context.tr('This receipt type has linked payments or ledger rows. Delete those entries first.',
            'इस रसीद प्रकार से भुगतान या खाता पंक्तियाँ जुड़ी हैं। पहले उन्हें हटाएँ।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete this receipt type?', 'यह रसीद प्रकार हटाएँ?'),
      message: context.tr('This will remove the receipt type definition only.', 'केवल रसीद प्रकार की परिभाषा हटेगी।'),
      confirmLabel: context.fin('fin.delete'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await c.repo.deleteCharge(c.societyId, id);
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) AppFeedback.toast(context, financeErrorMessage(e, 'Could not delete receipt type'), tone: BadgeTone.alert);
      return;
    }
    if (!context.mounted) return;
    AppFeedback.toast(context, context.tr('Receipt type deleted', 'रसीद प्रकार हटाया गया'), tone: BadgeTone.success);
    if (form.editingId == id) {
      form
        ..editingId = null
        ..reset()
        ..showForm = false
        ..changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) {
        final derived = c.derived;
        final subHeads = derived.subHeadsForMajor(form.majorHead);
        final byMajor = derived.chargesByMajorHead;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              icon: Icons.add,
              label: form.showForm && form.editingId == null
                  ? context.tr('Close form', 'फ़ॉर्म बंद करें')
                  : context.tr('Add receipt type', 'रसीद प्रकार जोड़ें'),
              onPressed: () {
                if (form.showForm && form.editingId == null) {
                  form
                    ..showForm = false
                    ..changed();
                  return;
                }
                form
                  ..editingId = null
                  ..reset()
                  ..showForm = true
                  ..changed();
              },
            ),
            const SizedBox(height: 16),
            if (form.showForm)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      form.editingId != null
                          ? context.tr('Edit receipt type', 'रसीद प्रकार संपादित करें')
                          : context.tr('New receipt type', 'नया रसीद प्रकार'),
                      style: AppText.caption(context).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(controller: form.title, hint: context.tr('Title (e.g. Monthly Maintenance)', 'शीर्षक (जैसे मासिक रखरखाव)')),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: form.amount,
                      hint: context.tr('Amount (₹)', 'राशि (₹)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: kAmountFormatters,
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<String>(
                      items: _frequencies,
                      value: form.frequency,
                      labelOf: (f) => context.fin('fin.freq.$f'),
                      onChanged: (v) => form
                        ..frequency = v ?? 'monthly'
                        ..changed(),
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<String>(
                      items: const ['', ...kSocietyPaymentMajorHeads],
                      value: form.majorHead,
                      labelOf: (h) => h.isEmpty ? context.fin('fin.majorHead') : h,
                      onChanged: (v) => form
                        ..majorHead = v ?? ''
                        ..expenseGroupId = ''
                        ..newSubHead.clear()
                        ..changed(),
                    ),
                    if (form.majorHead.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppDropdown<String>(
                        items: ['', ...subHeads.map((g) => g.id), _newSubHead],
                        value: form.expenseGroupId,
                        labelOf: (id) {
                          if (id.isEmpty) return context.tr('Payment sub-head (optional link)', 'भुगतान उप-शीर्ष (वैकल्पिक लिंक)');
                          if (id == _newSubHead) {
                            return context.tr('+ Create new sub-head under ${form.majorHead}', '+ ${form.majorHead} में नया उप-शीर्ष बनाएँ');
                          }
                          return derived.paymentGroupById[id]?.name ?? id;
                        },
                        onChanged: (v) => form
                          ..expenseGroupId = v ?? ''
                          ..newSubHead.clear()
                          ..changed(),
                      ),
                      if (form.expenseGroupId == _newSubHead) ...[
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: form.newSubHead,
                          hint: context.tr('New sub-head name (defaults to receipt title)', 'नए उप-शीर्ष का नाम (डिफ़ॉल्ट रसीद शीर्षक)'),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: form.editingId != null
                                ? context.tr('Update receipt type', 'रसीद प्रकार अपडेट करें')
                                : context.tr('Save receipt type', 'रसीद प्रकार सहेजें'),
                            onPressed: () => _save(context),
                          ),
                        ),
                        if (form.editingId != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton.secondary(
                              label: context.fin('fin.cancelEdit'),
                              onPressed: () => form
                                ..editingId = null
                                ..reset()
                                ..changed(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            for (final major in [...kSocietyPaymentMajorHeads, kUncategorizedHead])
              if ((byMajor[major] ?? const []).isNotEmpty) ...[
                _majorHeading(context, major),
                for (final ch in byMajor[major]!)
                  CardSection(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ch.title, style: AppText.sectionTitle(context)),
                              Text(ch.frequency, style: AppText.caption(context)),
                              if ((ch.expenseGroupId ?? '').isNotEmpty)
                                Text(
                                  '${context.tr('Sub-head', 'उप-शीर्ष')}: ${derived.paymentGroupById[ch.expenseGroupId]?.name ?? context.tr('Linked', 'जुड़ा')}',
                                  style: AppText.tiny(context),
                                ),
                            ],
                          ),
                        ),
                        Text(inrRaw(ch.amount), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.success)),
                        IconButton(
                          tooltip: context.fin('fin.edit'),
                          icon: Icon(Icons.edit_outlined, size: 18, color: t.mutedForeground),
                          onPressed: () => _startEdit(ch),
                        ),
                        if (!derived.chargeIdsWithDependents.contains(ch.id))
                          IconButton(
                            tooltip: context.tr('Delete receipt type', 'रसीद प्रकार हटाएँ'),
                            icon: Icon(Icons.delete_outline, size: 18, color: t.mutedForeground),
                            onPressed: () => _delete(context, ch.id),
                          )
                        else
                          Tooltip(
                            message: context.tr('Remove linked receipt or ledger rows first', 'पहले जुड़ी रसीद या खाता पंक्तियाँ हटाएँ'),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14, left: 4),
                              child: Text(context.fin('fin.inUse'), style: AppText.tiny(context).copyWith(fontSize: 9)),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            if (c.data.charges.isEmpty && !form.showForm)
              EmptyView(message: context.tr('No receipt types yet', 'अभी कोई रसीद प्रकार नहीं')),
          ],
        );
      },
    );
  }
}

/// Create → Payment type.
class FinanceCreatePaymentTab extends StatelessWidget {
  const FinanceCreatePaymentTab({super.key, required this.c, required this.form});

  final FinanceController c;
  final PaymentHeadFormModel form;

  Future<void> _save(BuildContext context) async {
    if (form.majorHead.isEmpty) {
      AppFeedback.toast(context, context.tr('Choose a major head for the payment type', 'भुगतान प्रकार के लिए मुख्य शीर्ष चुनें'),
          tone: BadgeTone.alert);
      return;
    }
    final name = form.name.text.trim();
    if (name.isEmpty) {
      AppFeedback.toast(context, context.tr('Enter a sub-head name', 'उप-शीर्ष का नाम दर्ज करें'), tone: BadgeTone.alert);
      return;
    }
    final desc = form.description.text.trim();
    final editing = form.editingId;
    try {
      if (editing != null) {
        await c.repo.updateExpenseGroup(
          societyId: c.societyId,
          groupId: editing,
          name: name,
          description: desc.isEmpty ? null : desc,
          majorHead: form.majorHead,
        );
      } else {
        await c.repo.createExpenseGroup(
          societyId: c.societyId,
          name: name,
          majorHead: form.majorHead,
          description: desc.isEmpty ? null : desc,
          createdBy: c.adminName,
        );
      }
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) {
        AppFeedback.toast(context, financeErrorMessage(e, editing != null ? 'Could not update payment type' : 'Could not create payment type'),
            tone: BadgeTone.alert);
      }
      return;
    }
    if (!context.mounted) return;
    AppFeedback.toast(
      context,
      editing != null ? context.tr('Payment type updated', 'भुगतान प्रकार अपडेट हुआ') : context.tr('Payment type added', 'भुगतान प्रकार जोड़ा गया'),
      tone: BadgeTone.success,
    );
    form
      ..editingId = null
      ..reset()
      ..showForm = false
      ..changed();
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete this payment type?', 'यह भुगतान प्रकार हटाएँ?'),
      message: context.tr('This removes the payment sub-head definition only.', 'केवल भुगतान उप-शीर्ष की परिभाषा हटेगी।'),
      confirmLabel: context.fin('fin.delete'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await c.repo.deleteExpenseGroup(c.societyId, id);
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) AppFeedback.toast(context, financeErrorMessage(e, 'Could not delete payment type'), tone: BadgeTone.alert);
      return;
    }
    if (!context.mounted) return;
    AppFeedback.toast(context, context.tr('Payment type deleted', 'भुगतान प्रकार हटाया गया'), tone: BadgeTone.success);
    if (form.editingId == id) {
      form
        ..editingId = null
        ..reset()
        ..showForm = false
        ..changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) {
        final derived = c.derived;
        final grouped = derived.paymentGroupsByMajorHeadMap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              icon: Icons.add,
              label: form.showForm && form.editingId == null
                  ? context.tr('Close form', 'फ़ॉर्म बंद करें')
                  : context.tr('Add payment type', 'भुगतान प्रकार जोड़ें'),
              onPressed: () {
                if (form.showForm && form.editingId == null) {
                  form
                    ..showForm = false
                    ..changed();
                  return;
                }
                form
                  ..editingId = null
                  ..reset()
                  ..showForm = true
                  ..changed();
              },
            ),
            const SizedBox(height: 16),
            if (form.showForm)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      form.editingId != null
                          ? context.tr('Edit payment type', 'भुगतान प्रकार संपादित करें')
                          : context.tr('New payment type', 'नया भुगतान प्रकार'),
                      style: AppText.caption(context).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<String>(
                      items: const ['', ...kSocietyPaymentMajorHeads],
                      value: form.majorHead,
                      labelOf: (h) => h.isEmpty ? context.fin('fin.majorHead') : h,
                      onChanged: (v) => form
                        ..majorHead = v ?? ''
                        ..changed(),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: form.name,
                      hint: context.tr('Sub-head name (e.g. Electricity bill, Lift AMC)', 'उप-शीर्ष नाम (जैसे बिजली बिल, लिफ्ट AMC)'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: form.description,
                      caps: false,
                      maxLines: 3,
                      minLines: 2,
                      hint: context.tr('Description (optional)', 'विवरण (वैकल्पिक)'),
                    ),
                    FinHint(context.tr(
                      'Payment types appear under the major head in period reports. Use specific names — e.g. Electricity, Security guards — not generic labels.',
                      'भुगतान प्रकार अवधि रिपोर्ट में मुख्य शीर्ष के अंतर्गत दिखते हैं। विशिष्ट नाम रखें — जैसे बिजली, सुरक्षा गार्ड — सामान्य नाम नहीं।',
                    )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: form.editingId != null
                                ? context.tr('Update payment type', 'भुगतान प्रकार अपडेट करें')
                                : context.tr('Save payment type', 'भुगतान प्रकार सहेजें'),
                            onPressed: () => _save(context),
                          ),
                        ),
                        if (form.editingId != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton.secondary(
                              label: context.fin('fin.cancelEdit'),
                              onPressed: () => form
                                ..editingId = null
                                ..reset()
                                ..changed(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            for (final major in [...kSocietyPaymentMajorHeads, kUncategorizedHead])
              if ((grouped[major] ?? const []).isNotEmpty) ...[
                _majorHeading(context, major),
                for (final g in grouped[major]!)
                  CardSection(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: AppText.sectionTitle(context)),
                              if ((g.description ?? '').isNotEmpty) Text(g.description!, style: AppText.caption(context)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.fin('fin.edit'),
                          icon: Icon(Icons.edit_outlined, size: 18, color: t.mutedForeground),
                          onPressed: () => form
                            ..editingId = g.id
                            ..name.text = g.name
                            ..description.text = g.description ?? ''
                            ..majorHead = resolveGroupMajorHeadOf(g)
                            ..showForm = true
                            ..changed(),
                        ),
                        if (!derived.groupIdsInUse.contains(g.id))
                          IconButton(
                            tooltip: context.tr('Delete payment type', 'भुगतान प्रकार हटाएँ'),
                            icon: Icon(Icons.delete_outline, size: 18, color: t.mutedForeground),
                            onPressed: () => _delete(context, g.id),
                          )
                        else
                          Tooltip(
                            message: context.tr('Remove linked receipts or recorded payments first', 'पहले जुड़ी रसीदें या दर्ज भुगतान हटाएँ'),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14, left: 4),
                              child: Text(context.fin('fin.inUse'), style: AppText.tiny(context).copyWith(fontSize: 9)),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            if (c.data.paymentExpenseGroups.isEmpty && !form.showForm)
              EmptyView(message: context.tr('No payment types yet', 'अभी कोई भुगतान प्रकार नहीं')),
          ],
        );
      },
    );
  }
}
