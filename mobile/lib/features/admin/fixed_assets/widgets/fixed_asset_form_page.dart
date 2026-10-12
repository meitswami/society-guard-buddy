import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../audit/data/audit_service.dart' show auditErrText;
import '../../audit/logic/js_compat.dart';
import '../../audit/widgets/audit_ui.dart';
import '../data/fixed_asset_service.dart';
import '../logic/fixed_asset_types.dart';

/// Web `DateInput`: type dd/MM/yyyy or pick from the calendar; emits `yyyy-MM-dd` ('' when cleared).
class AssetDateField extends StatefulWidget {
  const AssetDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.small = false});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool small;

  @override
  State<AssetDateField> createState() => _AssetDateFieldState();
}

class _AssetDateFieldState extends State<AssetDateField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: fmtIsoDateToDisplay(widget.value));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      final iso = Fmt.displayToIso(_ctrl.text);
      if (_ctrl.text.trim().isEmpty) {
        if (widget.value.isNotEmpty) widget.onChanged('');
      } else if (iso != null) {
        _ctrl.text = fmtIsoDateToDisplay(iso);
        if (iso != widget.value) widget.onChanged(iso);
      } else {
        _ctrl.text = fmtIsoDateToDisplay(widget.value);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AssetDateField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value)
      _ctrl.text = fmtIsoDateToDisplay(widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final initial = DateTime.tryParse(widget.value) ?? DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1980),
        lastDate: DateTime(2100));
    if (d == null) return;
    final iso = Fmt.isoDate(d);
    _ctrl.text = fmtIsoDateToDisplay(iso);
    widget.onChanged(iso);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.small
            ? Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(widget.label, style: AppText.tiny(context)))
            : FieldLabel(widget.label),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.datetime,
          style: TextStyle(
              fontSize: widget.small ? 12 : 14,
              color: context.tokens.foreground),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))
          ],
          onChanged: (v) {
            final iso = Fmt.displayToIso(v);
            if (iso != null && v.length >= 8) widget.onChanged(iso);
          },
          decoration: InputDecoration(
            hintText: 'dd/mm/yyyy',
            isDense: widget.small,
            suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                onPressed: _pick),
          ),
        ),
      ],
    );
  }
}

/// Port of `FixedAssetForm.tsx` (dialog → full-screen page). Pops `true` after a successful save.
class FixedAssetFormPage extends StatefulWidget {
  const FixedAssetFormPage(
      {super.key,
      this.asset,
      required this.expenseGroups,
      required this.onSave});

  final FixedAsset? asset;
  final List<ExpenseGroupOption> expenseGroups;

  /// Saves the payload (throws on error).
  final Future<void> Function(Map<String, Object?> input) onSave;

  @override
  State<FixedAssetFormPage> createState() => _FixedAssetFormPageState();
}

class _FixedAssetFormPageState extends State<FixedAssetFormPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _subHead = TextEditingController();
  final _bill = TextEditingController();
  final _vendor = TextEditingController();
  final _vendorContact = TextEditingController();
  final _tag = TextEditingController();
  final _serial = TextEditingController();
  final _location = TextEditingController();
  final _wMonths = TextEditingController();
  final _aMonths = TextEditingController();
  final _amcVendor = TextEditingController();
  final _notes = TextEditingController();
  String _majorHead = 'FIXED ASSETS';
  String? _groupId;
  String _source = 'manual';
  String _status = 'active';
  String _acq = '', _wStart = '', _wEnd = '', _aStart = '', _aEnd = '';
  String? _templateKey;
  bool _saving = false;

  bool get _isFinance => widget.asset?.sourceType == 'finance_transaction';

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    if (a != null) {
      _name.text = a.assetName;
      _desc.text = a.description ?? '';
      _majorHead = a.majorHead;
      _subHead.text = a.subHead ?? '';
      _groupId = a.expenseGroupId;
      _source = a.sourceType;
      _status = a.status;
      _acq = a.acquisitionDate ?? '';
      _bill.text = a.billValue == null ? '' : jsNumStr(a.billValue!);
      _vendor.text = a.vendorName ?? '';
      _vendorContact.text = a.vendorContact ?? '';
      _tag.text = a.assetTag ?? '';
      _serial.text = a.serialNumber ?? '';
      _location.text = a.location ?? '';
      _wStart = a.warrantyStartDate ?? '';
      _wMonths.text = a.warrantyPeriodMonths?.toString() ?? '';
      _wEnd = a.warrantyEndDate ?? '';
      _aStart = a.amcStartDate ?? '';
      _aMonths.text = a.amcPeriodMonths?.toString() ?? '';
      _aEnd = a.amcEndDate ?? '';
      _amcVendor.text = a.amcVendor ?? '';
      _notes.text = a.notes ?? '';
      _templateKey = a.templateKey;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _desc,
      _subHead,
      _bill,
      _vendor,
      _vendorContact,
      _tag,
      _serial,
      _location,
      _wMonths,
      _aMonths,
      _amcVendor,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _months(TextEditingController c) => int.tryParse(c.text.trim());

  void _recalcWarranty() => setState(() =>
      _wEnd = computeEndDateFromMonths(_wStart, _months(_wMonths)) ?? _wEnd);

  void _recalcAmc() => setState(() =>
      _aEnd = computeEndDateFromMonths(_aStart, _months(_aMonths)) ?? _aEnd);

  String? _trimOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    final payload = <String, Object?>{
      'asset_name': _name.text.trim(),
      'description': _trimOrNull(_desc),
      'major_head': _majorHead,
      'sub_head': _trimOrNull(_subHead),
      if (widget.asset != null || _groupId != null)
        'expense_group_id': _groupId,
      'source_type': _source,
      'status': _isFinance && _status == 'placeholder' ? 'active' : _status,
      'acquisition_date': _acq.isEmpty ? null : _acq,
      'bill_value': double.tryParse(_bill.text.trim()),
      'vendor_name': _trimOrNull(_vendor),
      'vendor_contact': _trimOrNull(_vendorContact),
      'asset_tag': _trimOrNull(_tag),
      'serial_number': _trimOrNull(_serial),
      'location': _trimOrNull(_location),
      'warranty_start_date': _wStart.isEmpty ? null : _wStart,
      'warranty_period_months': _months(_wMonths),
      'warranty_end_date': _wEnd.isEmpty ? null : _wEnd,
      'amc_start_date': _aStart.isEmpty ? null : _aStart,
      'amc_period_months': _months(_aMonths),
      'amc_end_date': _aEnd.isEmpty ? null : _aEnd,
      'amc_vendor': _trimOrNull(_amcVendor),
      'notes': _trimOrNull(_notes),
      if (widget.asset != null) 'template_key': _templateKey,
    };
    setState(() => _saving = true);
    try {
      await widget.onSave(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final msg = auditErrText(e);
        AppFeedback.toast(
            context,
            msg.isEmpty
                ? context.tr(
                    'Could not save asset', 'संपत्ति सहेजी नहीं जा सकी')
                : msg,
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _row(Widget a, Widget b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ]);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = context.isHi;
    final groupIds = ['', ...widget.expenseGroups.map((g) => g.id)];
    if (_groupId != null && !groupIds.contains(_groupId))
      groupIds.add(_groupId!);
    const gap = SizedBox(height: 12);
    final numFmt = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
          title: Text(widget.asset != null
              ? context.tr('Edit fixed asset', 'स्थिर संपत्ति संपादित करें')
              : context.tr('Add fixed asset', 'स्थिर संपत्ति जोड़ें'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_isFinance) ...[
                  InnerBox(
                    color: AppTokens.tint(t.muted, 0.5),
                    borderColor: Colors.transparent,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      context.tr(
                        'Linked to Finance payment. Bill value and vendor sync from the transaction; you can add warranty, AMC and location details here.',
                        'वित्त भुगतान से जुड़ा है। बिल मूल्य और विक्रेता लेन-देन से सिंक होते हैं; आप यहाँ वारंटी, AMC और स्थान का विवरण जोड़ सकते हैं।',
                      ),
                      style: AppText.caption(context),
                    ),
                  ),
                  gap,
                ],
                AppTextField(
                    label: context.tr('Asset name', 'संपत्ति का नाम'),
                    required: true,
                    controller: _name),
                gap,
                AppTextField(
                    label: context.tr('Description', 'विवरण'),
                    controller: _desc,
                    maxLines: 3,
                    minLines: 2),
                gap,
                _row(
                  AppTextField(
                      label: context.tr('Major head', 'मुख्य शीर्ष'),
                      initialValue: _majorHead,
                      readOnly: true,
                      enabled: false),
                  AppTextField(
                      label: context.tr('Sub-head', 'उप-शीर्ष'),
                      controller: _subHead),
                ),
                gap,
                AppDropdown<String>(
                  label: context.tr('Finance expense group (optional)',
                      'वित्त खर्च समूह (वैकल्पिक)'),
                  items: groupIds,
                  value: _groupId ?? '',
                  labelOf: (id) => id.isEmpty
                      ? context.tr('— Select sub-head —', '— उप-शीर्ष चुनें —')
                      : (widget.expenseGroups
                              .where((g) => g.id == id)
                              .firstOrNull
                              ?.name ??
                          id),
                  onChanged: (id) {
                    final g = widget.expenseGroups
                        .where((x) => x.id == id)
                        .firstOrNull;
                    setState(() {
                      _groupId = (id == null || id.isEmpty) ? null : id;
                      if (g != null) _subHead.text = g.name;
                    });
                  },
                ),
                gap,
                _row(
                  AppDropdown<String>(
                    label: context.tr('Source', 'स्रोत'),
                    items: {...fixedAssetSourceTypes, _source}.toList(),
                    value: _source,
                    labelOf: (s) => fixedAssetSourceLabel(s, hi: hi),
                    onChanged: _isFinance
                        ? null
                        : (v) => setState(() => _source = v ?? _source),
                  ),
                  AppDropdown<String>(
                    label: context.tr('Status', 'स्थिति'),
                    items: {...fixedAssetStatuses, _status}.toList(),
                    value: _status,
                    labelOf: (s) => fixedAssetStatusLabel(s, hi: hi),
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
                gap,
                _row(
                  AssetDateField(
                    label: context.tr('Acquisition / creation date',
                        'प्राप्ति / निर्माण तिथि'),
                    value: _acq,
                    onChanged: (v) => setState(() => _acq = v),
                  ),
                  AppTextField(
                    label: context.tr('Bill value (₹)', 'बिल मूल्य (₹)'),
                    controller: _bill,
                    enabled: !_isFinance,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                  ),
                ),
                gap,
                _row(
                  AppTextField(
                      label: context.tr('Vendor', 'विक्रेता'),
                      controller: _vendor),
                  AppTextField(
                      label: context.tr('Vendor contact', 'विक्रेता संपर्क'),
                      controller: _vendorContact,
                      caps: false),
                ),
                gap,
                _row(
                  AppTextField(
                      label: context.tr('Asset tag / ID', 'संपत्ति टैग / ID'),
                      controller: _tag),
                  AppTextField(
                      label: context.tr('Serial number', 'सीरियल नंबर'),
                      controller: _serial),
                ),
                gap,
                AppTextField(
                    label: context.tr('Location', 'स्थान'),
                    controller: _location,
                    hint: context.tr(
                        'e.g. Basement pump room', 'जैसे बेसमेंट पंप रूम')),
                const SizedBox(height: 16),
                Divider(height: 1, color: t.border),
                const SizedBox(height: 12),
                Text(context.tr('Warranty', 'वारंटी'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _triple(
                  AssetDateField(
                      small: true,
                      label: context.tr('Start', 'आरंभ'),
                      value: _wStart,
                      onChanged: (v) {
                        _wStart = v;
                        _recalcWarranty();
                      }),
                  _monthsField(_wMonths, numFmt, _recalcWarranty),
                  AssetDateField(
                      small: true,
                      label: context.tr('End', 'समाप्ति'),
                      value: _wEnd,
                      onChanged: (v) => setState(() => _wEnd = v)),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: t.border),
                const SizedBox(height: 12),
                Text(
                    context.tr('AMC (Annual Maintenance Contract)',
                        'AMC (वार्षिक रखरखाव अनुबंध)'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _triple(
                  AssetDateField(
                      small: true,
                      label: context.tr('Start', 'आरंभ'),
                      value: _aStart,
                      onChanged: (v) {
                        _aStart = v;
                        _recalcAmc();
                      }),
                  _monthsField(_aMonths, numFmt, _recalcAmc),
                  AssetDateField(
                      small: true,
                      label: context.tr('End', 'समाप्ति'),
                      value: _aEnd,
                      onChanged: (v) => setState(() => _aEnd = v)),
                ),
                const SizedBox(height: 8),
                AppTextField(
                    label: context.tr('AMC vendor', 'AMC विक्रेता'),
                    controller: _amcVendor),
                gap,
                AppTextField(
                    label: context.tr('Notes', 'टिप्पणी'),
                    controller: _notes,
                    maxLines: 3,
                    minLines: 2),
                const SizedBox(height: 16),
                AppButton(
                  label: _saving
                      ? context.tr('Saving…', 'सहेजा जा रहा है…')
                      : widget.asset != null
                          ? context.tr('Update asset', 'संपत्ति अपडेट करें')
                          : context.tr('Add asset', 'संपत्ति जोड़ें'),
                  loading: _saving,
                  onPressed: _name.text.trim().isEmpty ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _triple(Widget a, Widget b, Widget c) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: a),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: b),
        const SizedBox(width: 6),
        Expanded(flex: 5, child: c),
      ]);

  Widget _monthsField(TextEditingController c, List<TextInputFormatter> fmt,
          VoidCallback onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(context.tr('Months', 'माह'),
                  style: AppText.tiny(context))),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: fmt,
            style: TextStyle(fontSize: 12, color: context.tokens.foreground),
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => onChanged(),
          ),
        ],
      );
}
