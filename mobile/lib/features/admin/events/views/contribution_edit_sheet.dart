import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_models.dart';
import '../data/events_repository.dart';
import '../data/events_storage.dart';
import '../data/query_helpers.dart';
import '../logic/contribution_rows.dart';
import '../logic/flat_options.dart';
import '../logic/js_compat.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';

/// Port of `src/components/EventContributionEditModal.tsx` as a bottom sheet.
/// Resolves to `true` when the row was saved or deleted.
class ContributionEditSheet extends StatefulWidget {
  const ContributionEditSheet({super.key, required this.contributionId, required this.societyId, required this.adminName});

  final String contributionId;
  final String societyId;
  final String adminName;

  static Future<bool?> show(BuildContext context, {required String contributionId, required String societyId, required String adminName}) {
    return showEvSheet<bool>(
      context,
      builder: (_) => ContributionEditSheet(contributionId: contributionId, societyId: societyId, adminName: adminName),
    );
  }

  @override
  State<ContributionEditSheet> createState() => _ContributionEditSheetState();
}

class _ContributionEditSheetState extends State<ContributionEditSheet> {
  static const _repo = EventsRepository();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  EventContribution? _row;
  SocietyFlatsData _flats = SocietyFlatsData.empty;
  int _v = 0;

  String _amount = '';
  String _method = 'cash';
  String _txn = '';
  String _shot = '';
  String _label = '';
  String _flat = '';
  String _date = '';
  PickedAttachment? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        _repo.getContribution(widget.contributionId),
        _repo.loadFlats(widget.societyId, withMembers: false, withOccupancy: false),
      ]);
      if (!mounted) return;
      final c = results[0] as EventContribution?;
      if (c == null) {
        evToast(context, context.ev('cem.notFound'), tone: BadgeTone.alert);
        Navigator.pop(context);
        return;
      }
      setState(() {
        _row = c;
        _flats = results[1] as SocietyFlatsData;
        _amount = jsNumStr(c.amount);
        _method = c.paymentMethod.isEmpty ? 'cash' : c.paymentMethod;
        _txn = c.transactionId ?? '';
        _shot = c.screenshotUrl ?? '';
        _label = [c.batchLabel, c.outsiderName, c.residentName].firstWhere((x) => (x ?? '').isNotEmpty, orElse: () => '') ?? '';
        _flat = c.flatNumber ?? '';
        _date = (c.verifiedAt ?? '').length >= 10 ? c.verifiedAt!.substring(0, 10) : '';
        _loading = false;
        _v++;
      });
    } catch (e) {
      if (!mounted) return;
      evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      Navigator.pop(context);
    }
  }

  /// Display rule of the modal (slightly wider than the save rule, like the web).
  bool get _isNonFlatView {
    final r = _row;
    if (r == null) return false;
    return r.receiptBasis == 'non_flat' || (!r.hasFlat && ((r.batchLabel ?? '').isNotEmpty || r.receiptBasis != 'flat'));
  }

  Future<void> _save() async {
    final row = _row;
    if (row == null) return;
    final amount = jsNumber(_amount);
    if (!jsPositive(amount)) {
      evToast(context, context.ev('cem.validAmount'), tone: BadgeTone.alert);
      return;
    }
    final isNonFlat = row.receiptBasis == 'non_flat' || !row.hasFlat;
    if (isNonFlat && _label.trim().isEmpty) {
      evToast(context, context.ev('cem.payerRequired'), tone: BadgeTone.alert);
      return;
    }
    if (!isNonFlat && _flat.trim().isEmpty) {
      evToast(context, context.ev('cem.selectFlat'), tone: BadgeTone.alert);
      return;
    }
    String? screenshot = _shot.trim().isEmpty ? null : _shot.trim();
    final file = _file;
    if (file != null) {
      if (!file.isImage && !file.isPdf) {
        evToast(context, context.ev('evm.receiptType'), tone: BadgeTone.alert);
        return;
      }
      setState(() => _uploading = true);
      try {
        screenshot = await EventsStorage.uploadContributionReceipt(file);
      } catch (e) {
        if (mounted) {
          setState(() => _uploading = false);
          evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }
    final flatNumber = _flat.trim();
    FlatLite? flat;
    for (final f in _flats.flats) {
      if (f.flatNumber == flatNumber) {
        flat = f;
        break;
      }
    }
    final label = _label.trim();
    final payload = <String, dynamic>{
      'amount': amount,
      'payment_method': _method,
      'transaction_id': _txn.trim().isEmpty ? null : _txn.trim(),
      'screenshot_url': screenshot,
      'verified_by': widget.adminName,
      'verified_at': _date.isNotEmpty ? '${_date}T12:00:00.000Z' : row.verifiedAt,
    };
    if (isNonFlat) {
      payload['batch_label'] = label;
      payload['resident_name'] = label;
      payload['outsider_name'] = RegExp('outsider|sponsor|vendor|guest', caseSensitive: false).hasMatch(label) ? label : null;
      payload['flat_number'] = null;
      payload['flat_id'] = null;
    } else {
      payload['flat_number'] = flatNumber;
      payload['flat_id'] = flat?.id;
      payload['resident_name'] = flat != null ? residentLabelForFlatRow(flat.id, flat.ownerName, _flats.primaryByFlatId) : flatNumber;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateContribution(row.id, payload);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    AppFeedback.toast(context, context.ev('cem.updated'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    final row = _row;
    if (row == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.ev('cem.deleteTitle'),
      message: context.ev('evc.cannotUndo'),
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteContribution(row.id);
    } catch (e) {
      if (mounted) evToast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      return;
    }
    if (!mounted) return;
    AppFeedback.toast(context, context.ev('cem.deleted'), tone: BadgeTone.success);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final subtitle = _isNonFlatView ? context.ev('cem.nonFlatSub') : context.ev('cem.flatSub');
    final mode = (row?.splitMode ?? '').isNotEmpty ? ' · ${row!.splitMode!.replaceAll('_', ' ')}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvSheetHeader(title: context.ev('cem.title'), subtitle: '$subtitle$mode', onClose: () => Navigator.pop(context)),
        if (_loading)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: EvHint(context.ev('evc.loading'), size: 12)))
        else
          EvColumn(
            spacing: 12,
            children: [
              if (_isNonFlatView)
                AppTextField(
                  key: ValueKey('cem-label-$_v'),
                  hint: context.ev('cem.payer'),
                  initialValue: _label,
                  onChanged: (v) => _label = v,
                )
              else
                AppDropdown<String>(
                  hint: context.ev('cem.selectFlatOpt'),
                  items: [for (final f in _flats.flats) f.flatNumber],
                  value: _flat.isEmpty ? null : _flat,
                  labelOf: (n) => '${context.ev('evc.flat')} $n',
                  onChanged: (v) => setState(() => _flat = v ?? ''),
                ),
              AppTextField(
                key: ValueKey('cem-amount-$_v'),
                hint: context.ev('evc.amountRs'),
                initialValue: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => _amount = v,
              ),
              AppDropdown<String>(
                items: {'cash', 'upi', 'bank_transfer', 'cheque', 'other', _method}.toList(),
                value: _method,
                labelOf: (m) => paymentMethodLabel(context, m),
                onChanged: (v) => setState(() => _method = v ?? 'cash'),
              ),
              AppTextField(
                key: ValueKey('cem-txn-$_v'),
                hint: context.ev('cem.txn'),
                initialValue: _txn,
                caps: false,
                onChanged: (v) => _txn = v,
              ),
              EvDateField(label: context.ev('cem.receiptDate'), value: _date, onChanged: (v) => setState(() => _date = v)),
              EvTinyLabel(context.ev('cem.proof'), upper: false),
              if (_shot.isNotEmpty) EvLink(context.ev('cem.viewCurrent'), onTap: () => openEvUrl(context, _shot)),
              EvAttachmentField(file: _file, kinds: const {AttachKind.image, AttachKind.pdf}, onChanged: (f) => setState(() => _file = f)),
              AppTextField(
                key: ValueKey('cem-shot-$_v'),
                hint: context.ev('evc.pasteUrl'),
                initialValue: _shot,
                keyboardType: TextInputType.url,
                onChanged: (v) => setState(() => _shot = v),
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
                  EvOutlineButton(label: context.t('common.delete'), color: context.tokens.destructive, onTap: _remove),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
