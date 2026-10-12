import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_models.dart';
import '../data/events_storage.dart';
import '../data/expense_repository.dart';
import '../data/query_helpers.dart';
import '../logic/expense_balances.dart';
import '../logic/expense_heads.dart';
import '../logic/finance_dates.dart';
import '../logic/js_compat.dart';
import '../logic/split_math.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';

/// "Edit expense group / head" modal of `ExpenseSplitter` (true when saved).
class GroupEditSheet extends StatefulWidget {
  const GroupEditSheet({super.key, required this.group, required this.societyId, required this.payment, required this.events});

  final ExpenseGroup group;
  final String societyId;
  final bool payment;
  final List<EventRow> events;

  static Future<bool?> show(
    BuildContext context, {
    required ExpenseGroup group,
    required String societyId,
    required bool payment,
    required List<EventRow> events,
  }) =>
      showEvSheet<bool>(context, builder: (_) => GroupEditSheet(group: group, societyId: societyId, payment: payment, events: events));

  @override
  State<GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends State<GroupEditSheet> {
  static const _repo = ExpenseRepository();

  late String _name = widget.group.name;
  late String _description = widget.group.description ?? '';
  late String _eventId = widget.group.eventId ?? '';
  late String _majorHead = widget.payment ? resolveGroupMajorHead(name: widget.group.name, majorHead: widget.group.majorHead) : '';
  late String _adult = jsNumStr(widget.group.adultWeight ?? 1);
  late String _child = jsNumStr(widget.group.childWeight ?? 0.5);
  bool _saving = false;

  Future<void> _save() async {
    final name = _name.trim();
    if (name.isEmpty) {
      evToast(context, context.ev('spl.groupNameRequired'), tone: BadgeTone.alert);
      return;
    }
    if (widget.payment && _majorHead.isEmpty) {
      evToast(context, context.ev('spl.majorHeadRequired'), tone: BadgeTone.alert);
      return;
    }
    final payload = widget.payment
        ? {
            'name': name,
            'description': _description.trim().isEmpty ? null : _description.trim(),
            'major_head': _majorHead,
            'event_id': null,
          }
        : {
            'name': name,
            'description': _description.trim().isEmpty ? null : _description.trim(),
            'event_id': _eventId.isEmpty ? null : _eventId,
            'adult_weight': jsNumberOr(_adult, 1),
            'child_weight': jsNumberOr(_child, 0.5),
          };
    setState(() => _saving = true);
    try {
      await _repo.updateGroup(widget.group.id, widget.societyId, payload);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    AppFeedback.toast(context, context.ev('spl.groupUpdated'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final eventIds = ['', for (final e in widget.events) e.id];
    if (_eventId.isNotEmpty && !eventIds.contains(_eventId)) eventIds.add(_eventId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvSheetHeader(title: context.ev(widget.payment ? 'spl.editHead' : 'spl.editGroupTitle')),
        EvColumn(
          spacing: 12,
          children: [
            if (widget.payment)
              AppDropdown<String>(
                label: context.ev('spl.majorHead'),
                hint: context.ev('spl.chooseMajor'),
                items: kSocietyPaymentMajorHeads,
                value: _majorHead.isEmpty ? null : _majorHead,
                labelOf: (h) => h,
                onChanged: (v) => setState(() => _majorHead = v ?? ''),
              ),
            AppTextField(
              label: widget.payment ? context.ev('spl.subHeadName') : null,
              hint: widget.payment ? context.ev('spl.subHeadEditHint') : context.ev('spl.groupNamePh'),
              initialValue: _name,
              onChanged: (v) => _name = v,
            ),
            AppTextField(
              hint: context.ev('evc.descriptionOptional'),
              initialValue: _description,
              maxLines: 3,
              minLines: 2,
              onChanged: (v) => _description = v,
            ),
            if (!widget.payment) ...[
              AppDropdown<String>(
                items: eventIds,
                value: _eventId,
                labelOf: (id) {
                  if (id.isEmpty) return context.ev('spl.noLinkedEvent');
                  for (final e in widget.events) {
                    if (e.id == id) return '${e.title} (${e.eventDate})';
                  }
                  return context.ev('spl.calendarEvent');
                },
                onChanged: (v) => setState(() => _eventId = v ?? ''),
              ),
              EvTwoCol(
                left: AppTextField(
                  label: context.ev('evc.adultWeight'),
                  initialValue: _adult,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _adult = v,
                ),
                right: AppTextField(
                  label: context.ev('evc.childWeight'),
                  initialValue: _child,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _child = v,
                ),
              ),
              EvHint(context.ev('spl.weightsEditHint')),
            ],
            Row(
              children: [
                Expanded(child: AppButton(label: context.t('common.save'), loading: _saving, onPressed: _save)),
                const SizedBox(width: 8),
                Expanded(child: AppButton.secondary(label: context.t('common.cancel'), onPressed: () => Navigator.pop(context))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// "Edit expense" modal of `ExpenseSplitter` (rescale splits, attachments, ledger sync).
class ExpenseEditSheet extends StatefulWidget {
  const ExpenseEditSheet({
    super.key,
    required this.expense,
    required this.splits,
    required this.societyId,
    required this.adminName,
    required this.groupName,
    required this.food,
    required this.counterpartyPrefix,
    required this.eventTitle,
    required this.flats,
  });

  final ExpenseRow expense;
  final List<ExpenseSplit> splits;
  final String societyId;
  final String adminName;
  final String groupName;
  final bool food;
  final String counterpartyPrefix;
  final String? eventTitle;
  final List<({String id, String flatNumber})> flats;

  static Future<bool?> show(
    BuildContext context, {
    required ExpenseRow expense,
    required List<ExpenseSplit> splits,
    required String societyId,
    required String adminName,
    required String groupName,
    required bool food,
    required String counterpartyPrefix,
    required String? eventTitle,
    required List<({String id, String flatNumber})> flats,
  }) =>
      showEvSheet<bool>(
        context,
        builder: (_) => ExpenseEditSheet(
          expense: expense,
          splits: splits,
          societyId: societyId,
          adminName: adminName,
          groupName: groupName,
          food: food,
          counterpartyPrefix: counterpartyPrefix,
          eventTitle: eventTitle,
          flats: flats,
        ),
      );

  @override
  State<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<ExpenseEditSheet> {
  static const _repo = ExpenseRepository();

  late String _title;
  late String _total;
  late String _vendor;
  late String _serviceKind;
  late String _expenseDate;
  late String _recordingDate;
  late String _method;
  late String _notes;
  late String _status;
  late List<String> _attachments;
  List<PickedAttachment> _newFiles = [];
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final exp = widget.expense;
    final existing = exp.attachmentUrls;
    final bill = exp.billScreenshotUrl;
    final legacy = (bill != null && bill.isNotEmpty && !existing.contains(bill)) ? [bill] : const <String>[];
    String s10(String? s) => (s ?? '').length > 10 ? s!.substring(0, 10) : (s ?? '');
    _title = exp.title;
    _total = jsNumStr(exp.totalAmount);
    _vendor = exp.vendorOrService ?? '';
    _serviceKind = (exp.serviceKind ?? '').isEmpty ? 'one_time' : exp.serviceKind!;
    _expenseDate = s10(exp.expenseDate);
    _recordingDate = s10((exp.recordingDate ?? '').isNotEmpty ? exp.recordingDate : exp.createdAt);
    _method = exp.paymentMethod.isEmpty ? 'cash' : exp.paymentMethod;
    _notes = exp.notes ?? '';
    _status = (exp.recordStatus ?? '').isEmpty ? 'active' : exp.recordStatus!;
    _attachments = [...legacy, ...existing];
  }

  Future<void> _save() async {
    final old = widget.expense;
    final newTotal = jsNumber(_total);
    if (!jsPositive(newTotal)) {
      evToast(context, context.ev('spl.validTotal'), tone: BadgeTone.alert);
      return;
    }
    final all = [..._attachments];
    if (_newFiles.isNotEmpty) {
      setState(() => _uploading = true);
      for (final f in _newFiles) {
        if (f.size > EventsStorage.maxBytes) {
          evToast(context, context.ev('evc.fileTooLarge', {'name': f.name}), tone: BadgeTone.alert);
          setState(() => _uploading = false);
          return;
        }
        try {
          all.add(await EventsStorage.uploadExpenseBill(old.groupId ?? '', f));
        } catch (e) {
          if (mounted) {
            setState(() => _uploading = false);
            evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
          }
          return;
        }
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }
    setState(() => _saving = true);
    try {
      final oldTotal = old.totalAmount;
      if (old.splitType != 'society_fund' && widget.splits.isNotEmpty && (newTotal - oldTotal).abs() > 0.01) {
        final ratio = newTotal / oldTotal;
        final scaled = adjustSplitRemainder(newTotal, [for (final s in widget.splits) round2(s.amount * ratio)]);
        for (var i = 0; i < widget.splits.length; i++) {
          await _repo.updateSplitAmount(widget.splits[i].id, scaled[i]);
        }
      }
      await _repo.updateExpense(old.id, {
        'title': _title.trim(),
        'total_amount': newTotal,
        'vendor_or_service': _vendor.trim().isEmpty ? null : _vendor.trim(),
        'service_kind': _serviceKind,
        'expense_date': _expenseDate,
        'recording_date': _recordingDate,
        'payment_method': _method,
        'notes': _notes.trim().isEmpty ? null : _notes.trim(),
        'record_status': _status,
        'attachment_urls': all,
        'bill_screenshot_url': all.isEmpty ? null : all.first,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }

    final editCategory = old.expenseCategory == 'food' || widget.food ? 'food' : 'payment';
    String? syncErr;
    if (editCategory != 'food') {
      try {
        final allocation = old.splitType == 'society_fund'
            ? [LedgerAllocation('SOCIETY', newTotal)]
            : await _repo.splitAllocationsOf(old.id);
        final paidBy = paidByFlatsOf(old);
        final relation = old.splitType == 'society_fund'
            ? 'Society fund (no per-flat split)'
            : paidBy.isNotEmpty
                ? 'Advanced by flat(s): ${paidBy.join(', ')}'
                : 'Event / function expense';
        syncErr = await _repo.syncFinanceLedgerFromGroupExpenseEdit(
          societyId: widget.societyId,
          adminName: widget.adminName,
          groupName: widget.groupName,
          expenseId: old.id,
          title: _title.trim(),
          total: newTotal,
          expenseDate: _expenseDate,
          paymentMethod: _method,
          screenshotUrl: _attachments.isEmpty ? null : _attachments.first,
          notes: _notes.trim().isEmpty ? null : _notes.trim(),
          vendorOrService: _vendor.trim().isEmpty ? null : _vendor.trim(),
          flats: widget.flats,
          allocationSplits: allocation,
          counterpartyName: '${widget.counterpartyPrefix}: ${widget.groupName}',
          counterpartyRelation: relation,
          expenseCategory: editCategory,
        );
      } catch (e) {
        syncErr = supabaseErrorMessage(e);
      }
    }
    if (!mounted) return;
    if (syncErr != null) AppFeedback.toast(context, context.ev('spl.ledgerSyncFailed', {'err': syncErr}), tone: BadgeTone.alert);
    AppFeedback.toast(context, context.ev('spl.expenseUpdated'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvSheetHeader(title: context.ev('spl.editExpense'), subtitle: context.ev('spl.editExpenseHint')),
        EvColumn(
          spacing: 12,
          children: [
            AppTextField(hint: context.ev('spl.titlePh'), initialValue: _title, onChanged: (v) => _title = v),
            AppTextField(
              hint: context.ev('evc.totalRs'),
              initialValue: _total,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _total = v,
            ),
            AppTextField(hint: context.ev('spl.vendor.general'), initialValue: _vendor, onChanged: (v) => _vendor = v),
            EvTwoCol(
              left: AppDropdown<String>(
                items: {'one_time', 'recurring', 'temporary', _serviceKind}.toList(),
                value: _serviceKind,
                labelOf: (k) => serviceKindLabel(context, k),
                onChanged: (v) => setState(() => _serviceKind = v ?? 'one_time'),
              ),
              right: EvDateField(label: context.ev('spl.billingDate'), value: _expenseDate, onChanged: (v) => setState(() => _expenseDate = v)),
            ),
            EvHint(context.ev('evc.recordedOn', {'date': _recordingDate.isNotEmpty ? fmtIsoDateToDisplay(_recordingDate) : '—'})),
            AppDropdown<String>(
              items: {'cash', 'upi', 'bank_transfer', 'cheque', 'other', _method}.toList(),
              value: _method,
              labelOf: (m) => paymentMethodLabel(context, m),
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            AppTextField(hint: context.ev('spl.notesPh'), initialValue: _notes, maxLines: 4, minLines: 3, onChanged: (v) => _notes = v),
            EvTinyLabel(context.ev('spl.attachments'), icon: Icons.attach_file),
            for (var i = 0; i < _attachments.length; i++)
              EvMutedBox(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: EvLink(attachmentFileName(_attachments[i]), size: 11, onTap: () => openEvUrl(context, _attachments[i]))),
                    InkWell(
                      onTap: () => setState(() => _attachments = [..._attachments]..removeAt(i)),
                      child: Icon(Icons.close, size: 16, color: t.destructive),
                    ),
                  ],
                ),
              ),
            if (_newFiles.isNotEmpty) ...[
              EvHint(context.ev('spl.newFiles')),
              for (var i = 0; i < _newFiles.length; i++)
                EvMutedBox(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_newFiles[i].name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                      EvHint('${(_newFiles[i].size / 1024).toStringAsFixed(0)} KB'),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _newFiles = [..._newFiles]..removeAt(i)),
                        child: Icon(Icons.close, size: 16, color: t.destructive),
                      ),
                    ],
                  ),
                ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: EvOutlineButton(
                icon: Icons.upload_file,
                label: context.ev('att.chooseMany'),
                onTap: () async {
                  final picked = await pickAttachments(
                    context,
                    kinds: const {AttachKind.image, AttachKind.pdf, AttachKind.docs, AttachKind.audio},
                    multiple: true,
                  );
                  if (picked.isNotEmpty) setState(() => _newFiles = [..._newFiles, ...picked]);
                },
              ),
            ),
            EvHint(context.ev('spl.maxFileHint')),
            AppDropdown<String>(
              items: {'active', 'archived', _status}.toList(),
              value: _status,
              labelOf: (s) => context.ev('spl.rs.$s') == 'spl.rs.$s' ? s : context.ev('spl.rs.$s'),
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _uploading ? context.ev('evc.uploading') : context.ev('evc.saveChanges'),
                    loading: _uploading || _saving,
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: AppButton.secondary(label: context.t('common.cancel'), onPressed: () => Navigator.pop(context))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
