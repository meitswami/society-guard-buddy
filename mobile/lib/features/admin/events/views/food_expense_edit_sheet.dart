import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_storage.dart';
import '../data/expense_repository.dart';
import '../data/query_helpers.dart';
import '../logic/expense_balances.dart';
import '../logic/finance_dates.dart';
import '../logic/js_compat.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';

/// Port of `src/components/FoodExpenseEditModal.tsx` as a bottom sheet (true when saved / deleted).
class FoodExpenseEditSheet extends StatefulWidget {
  const FoodExpenseEditSheet({super.key, required this.expenseId});

  final String expenseId;

  static Future<bool?> show(BuildContext context, {required String expenseId}) =>
      showEvSheet<bool>(context, builder: (_) => FoodExpenseEditSheet(expenseId: expenseId));

  @override
  State<FoodExpenseEditSheet> createState() => _FoodExpenseEditSheetState();
}

class _FoodExpenseEditSheetState extends State<FoodExpenseEditSheet> {
  static const _repo = ExpenseRepository();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  int _v = 0;
  String _groupId = '';
  String _splitType = '';
  String _title = '';
  String _total = '';
  String _vendor = '';
  String _expenseDate = '';
  String _recordingDate = '';
  String _method = 'cash';
  String _notes = '';
  List<String> _attachments = [];
  List<PickedAttachment> _newFiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final exp = await _repo.getExpense(widget.expenseId);
      if (!mounted) return;
      if (exp == null) {
        evToast(context, context.ev('fem.notFound'), tone: BadgeTone.alert);
        Navigator.pop(context);
        return;
      }
      final existing = exp.attachmentUrls;
      final bill = exp.billScreenshotUrl;
      final legacy = (bill != null && bill.isNotEmpty && !existing.contains(bill)) ? [bill] : const <String>[];
      String slice10(String? s) => (s ?? '').length > 10 ? s!.substring(0, 10) : (s ?? '');
      setState(() {
        _groupId = exp.groupId ?? '';
        _splitType = exp.splitType;
        _title = exp.title;
        _total = jsNumStr(exp.totalAmount);
        _vendor = exp.vendorOrService ?? '';
        _expenseDate = slice10(exp.expenseDate);
        _recordingDate = slice10((exp.recordingDate ?? '').isNotEmpty ? exp.recordingDate : exp.createdAt);
        _method = exp.paymentMethod.isEmpty ? 'cash' : exp.paymentMethod;
        _notes = exp.notes ?? '';
        _attachments = [...legacy, ...existing];
        _newFiles = [];
        _loading = false;
        _v++;
      });
    } catch (e) {
      if (!mounted) return;
      evToast(context, context.ev('fem.notFound'), tone: BadgeTone.alert);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final newTotal = jsNumber(_total);
    if (_title.trim().isEmpty || !jsPositive(newTotal)) {
      evToast(context, context.ev('fem.titleAmount'), tone: BadgeTone.alert);
      return;
    }
    final all = [..._attachments];
    if (_newFiles.isNotEmpty) {
      for (final f in _newFiles) {
        if (f.size > EventsStorage.maxBytes) {
          evToast(context, context.ev('evc.fileTooLarge', {'name': f.name}), tone: BadgeTone.alert);
          return;
        }
      }
      setState(() => _uploading = true);
      for (final f in _newFiles) {
        try {
          all.add(await EventsStorage.uploadExpenseBill(_groupId, f));
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
    try {
      final old = await _repo.getExpense(widget.expenseId);
      final oldTotal = old?.totalAmount ?? 0;
      if (old?.splitType != 'society_fund' && (newTotal - oldTotal).abs() > 0.01) {
        final splits = await _repo.splitsOf(widget.expenseId);
        if (splits.isNotEmpty) {
          final ratio = newTotal / oldTotal;
          for (final s in splits) {
            await _repo.updateSplitAmount(s.id, round2(s.amount * ratio));
          }
        }
      }
      if (!mounted) return;
      setState(() => _saving = true);
      await _repo.updateExpense(widget.expenseId, {
        'title': _title.trim(),
        'total_amount': newTotal,
        'vendor_or_service': _vendor.trim().isEmpty ? null : _vendor.trim(),
        'expense_date': _expenseDate,
        'payment_method': _method,
        'notes': _notes.trim().isEmpty ? null : _notes.trim(),
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
    if (!mounted) return;
    AppFeedback.toast(context, context.ev('fem.updated'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('fem.deleteTitle'),
      message: context.ev('fem.deleteText'),
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteSplitsOf(widget.expenseId);
      await _repo.deleteExpense(widget.expenseId);
    } catch (e) {
      if (mounted) evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      return;
    }
    if (!mounted) return;
    AppFeedback.toast(context, context.ev('fem.deleted'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvSheetHeader(
          title: context.ev('fem.title'),
          subtitle: _splitType.isNotEmpty && _splitType != 'society_fund' ? context.ev('fem.rescaleHint') : null,
          onClose: () => Navigator.pop(context),
        ),
        if (_loading)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: EvHint(context.ev('evc.loading'), size: 12)))
        else
          EvColumn(
            spacing: 12,
            children: [
              AppTextField(
                  key: ValueKey('fem-title-$_v'), hint: context.ev('fem.billTitle'), initialValue: _title, onChanged: (v) => _title = v),
              AppTextField(
                key: ValueKey('fem-total-$_v'),
                hint: context.ev('evc.totalRs'),
                initialValue: _total,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => _total = v,
              ),
              AppTextField(
                  key: ValueKey('fem-vendor-$_v'),
                  hint: context.ev('spl.vendor.food'),
                  initialValue: _vendor,
                  onChanged: (v) => _vendor = v),
              EvDateField(label: context.ev('fem.billDate'), value: _expenseDate, onChanged: (v) => setState(() => _expenseDate = v)),
              EvHint(context.ev('evc.recordedOn', {'date': _recordingDate.isNotEmpty ? fmtIsoDateToDisplay(_recordingDate) : '—'})),
              AppDropdown<String>(
                items: {'cash', 'upi', 'bank_transfer', 'cheque', 'other', _method}.toList(),
                value: _method,
                labelOf: (m) => paymentMethodLabel(context, m),
                onChanged: (v) => setState(() => _method = v ?? 'cash'),
              ),
              AppTextField(
                key: ValueKey('fem-notes-$_v'),
                hint: context.ev('fem.notes'),
                initialValue: _notes,
                maxLines: 4,
                minLines: 2,
                onChanged: (v) => _notes = v,
              ),
              EvTinyLabel(context.ev('fem.attachments'), icon: Icons.attach_file),
              for (var i = 0; i < _attachments.length; i++)
                EvMutedBox(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: EvLink(attachmentFileName(_attachments[i]), size: 11, onTap: () => openEvUrl(context, _attachments[i]))),
                      InkWell(
                        onTap: () => setState(() => _attachments = [..._attachments]..removeAt(i)),
                        child: Icon(Icons.close, size: 16, color: t.destructive),
                      ),
                    ],
                  ),
                ),
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
              Align(
                alignment: Alignment.centerLeft,
                child: EvOutlineButton(
                  icon: Icons.upload_file,
                  label: context.ev('att.chooseMany'),
                  onTap: () async {
                    final picked = await pickAttachments(context, kinds: const {AttachKind.image, AttachKind.pdf}, multiple: true);
                    // Web replaces the pending file list on every pick.
                    if (picked.isNotEmpty) setState(() => _newFiles = picked);
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _saving || _uploading ? context.ev('evc.saving') : context.ev('evc.saveChanges'),
                      loading: _saving || _uploading,
                      onPressed: _save,
                    ),
                  ),
                  const SizedBox(width: 8),
                  EvOutlineButton(label: context.t('common.delete'), color: t.destructive, onTap: _remove),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
