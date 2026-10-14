import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/committee_repository.dart';
import '../data/gov_backend.dart';
import '../logic/committee_logic.dart';
import '../widgets/gov_widgets.dart';

/// Port of web `CommitteeDutiesChart.tsx` (admin edit / resident read-only).
class CommitteeDutiesChart extends StatefulWidget {
  const CommitteeDutiesChart(
      {super.key, required this.societyId, required this.isResident});

  final String societyId;
  final bool isResident;

  @override
  State<CommitteeDutiesChart> createState() => _CommitteeDutiesChartState();
}

class _DutyEditor {
  _DutyEditor({this.id, String label = '', String names = ''})
      : label = TextEditingController(text: label),
        names = TextEditingController(text: names);

  final String? id;
  final TextEditingController label;
  final TextEditingController names;

  void dispose() {
    label.dispose();
    names.dispose();
  }
}

class _CommitteeDutiesChartState extends State<CommitteeDutiesChart> {
  late final CommitteeRepository _repo = CommitteeRepository(widget.societyId);
  CommitteeDutiesChartRow? _chart;
  List<CommitteeDutyRow> _rows = const [];
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String _periodFrom = '';
  String _periodTo = '';
  final List<_DutyEditor> _forms = [];

  bool get _hi => context.lang == AppLang.hi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.loadDuties();
      if (!mounted) return;
      setState(() {
        _chart = res.chart;
        _rows = res.rows;
      });
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForms() {
    for (final f in _forms) {
      f.dispose();
    }
    _forms.clear();
  }

  void _startEdit() {
    _clearForms();
    final chart = _chart;
    if (chart != null) {
      _periodFrom = chart.periodFrom.length >= 10
          ? chart.periodFrom.substring(0, 10)
          : chart.periodFrom;
      final to = chart.periodTo ?? '';
      _periodTo = to.length >= 10 ? to.substring(0, 10) : to;
      if (_rows.isEmpty) {
        _forms.add(_DutyEditor());
      } else {
        for (final r in _rows) {
          _forms.add(_DutyEditor(
              id: r.id,
              label: r.dutyLabel,
              names: formatSupervisorNames(r.supervisorNames)));
        }
      }
    } else {
      _periodFrom = '';
      _periodTo = '';
      _forms.add(_DutyEditor());
    }
    setState(() => _editing = true);
  }

  void _cancel() {
    _clearForms();
    setState(() => _editing = false);
  }

  void _addPreset(String label) {
    if (_forms
        .any((f) => f.label.text.trim().toLowerCase() == label.toLowerCase())) {
      GovToast.info(
          context,
          context.tr(
              '$label is already in the chart', '$label पहले से चार्ट में है'));
      return;
    }
    setState(() => _forms.add(_DutyEditor(label: label)));
  }

  Future<void> _save() async {
    final res = validateDutyRows(
      periodFrom: _periodFrom,
      periodTo: _periodTo,
      forms: [
        for (var i = 0; i < _forms.length; i++)
          DutyFormRow(
              id: _forms[i].id,
              dutyLabel: _forms[i].label.text,
              supervisorNames: _forms[i].names.text,
              sortOrder: i),
      ],
    );
    if (res.error != null) {
      GovToast.error(context, _hi ? res.error!.$2 : res.error!.$1);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.saveDuties(
          chartId: _chart?.id,
          periodFrom: _periodFrom,
          periodTo: _periodTo,
          rows: res.rows);
      if (!mounted) return;
      GovToast.ok(
          context, context.tr('Duties chart saved', 'कर्तव्य चार्ट सहेजा गया'));
      _clearForms();
      setState(() => _editing = false);
      await _load();
    } catch (e) {
      if (mounted) {
        final msg = GovBackend.errorText(e);
        GovToast.error(
            context,
            msg.isEmpty
                ? context.tr('Failed to save duties chart',
                    'कर्तव्य चार्ट सहेजा नहीं गया')
                : msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeChart() async {
    final chart = _chart;
    if (chart == null) return;
    final ok = await govConfirm(
      context,
      title: context.tr('Remove duties chart?', 'कर्तव्य चार्ट हटाएँ?'),
      message: context.tr(
          'The standard duties chart will be hidden from residents until you create a new one.',
          'नया चार्ट बनाने तक मानक कर्तव्य चार्ट निवासियों से छिपा रहेगा।'),
      confirmLabel: context.tr('Remove', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.removeDutiesChart(chart.id);
      if (!mounted) return;
      GovToast.ok(context,
          context.tr('Duties chart removed', 'कर्तव्य चार्ट हटाया गया'));
      setState(() => _editing = false);
      await _load();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Widget _editor() {
    final t = context.tokens;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GovDateField(
                  label: context.tr('Period from', 'अवधि से'),
                  required: true,
                  value: _periodFrom,
                  onChanged: (v) => setState(() => _periodFrom = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GovDateField(
                  label: context.tr('Period to', 'अवधि तक'),
                  value: _periodTo,
                  helper: context.tr(
                      'Leave blank if ongoing', 'जारी हो तो खाली छोड़ें'),
                  onChanged: (v) => setState(() => _periodTo = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
              context.tr(
                  'QUICK ADD STANDARD DUTIES', 'मानक कर्तव्य जल्दी जोड़ें'),
              style: AppText.fieldLabel(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in standardDutyPresets)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('+ ${dutyPresetLabel(p, hi: _hi)}',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTokens.tint(t.secondary, 0.5),
                  side: BorderSide(color: t.border),
                  onPressed: () => _addPreset(p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(context.tr('DUTY ASSIGNMENTS', 'कर्तव्य आवंटन'),
              style: AppText.fieldLabel(context)),
          const SizedBox(height: 8),
          for (var i = 0; i < _forms.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.tint(t.muted, 0.2),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                border: Border.all(color: t.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.tr('Duty', 'कर्तव्य'),
                            style: AppText.tiny(context)),
                        const SizedBox(height: 2),
                        AppTextField(
                          controller: _forms[i].label,
                          hint: context.tr(
                              'e.g. Security & Gate', 'जैसे सुरक्षा एवं गेट'),
                          caps: false,
                        ),
                        const SizedBox(height: 8),
                        Text(context.tr('Supervisor name(s)', 'पर्यवेक्षक नाम'),
                            style: AppText.tiny(context)),
                        const SizedBox(height: 2),
                        AppTextField(
                          controller: _forms[i].names,
                          hint: context.tr('Comma-separated for multiple',
                              'एक से अधिक हों तो अल्पविराम से अलग करें'),
                          caps: false,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove duty', 'कर्तव्य हटाएँ'),
                    onPressed: _forms.length <= 1
                        ? null
                        : () => setState(() {
                              _forms.removeAt(i).dispose();
                            }),
                    icon: Icon(Icons.close, size: 16, color: t.destructive),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _forms.add(_DutyEditor())),
              icon: const Icon(Icons.add, size: 14),
              label: Text(context.tr('Add duty row', 'कर्तव्य पंक्ति जोड़ें'),
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
          Divider(color: t.border),
          Row(
            children: [
              Expanded(
                  child: AppButton.secondary(
                      label: context.tr('Cancel', 'रद्द करें'),
                      onPressed: _saving ? null : _cancel)),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: _saving
                      ? context.tr('Saving…', 'सहेजा जा रहा है…')
                      : context.tr('Save chart', 'चार्ट सहेजें'),
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table() {
    final t = context.tokens;
    final chart = _chart!;
    String d(String? iso) => iso == null || iso.isEmpty
        ? ''
        : Fmt.isoToDisplay(
            iso.substring(0, iso.length >= 10 ? 10 : iso.length));
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${context.tr('Period', 'अवधि')}: '),
              TextSpan(
                text:
                    '${d(chart.periodFrom)} → ${chart.periodTo != null ? d(chart.periodTo) : context.tr('Ongoing', 'जारी')}',
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: t.foreground),
              ),
            ]),
            style: AppText.caption(context),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border))),
            child: Row(
              children: [
                Expanded(
                    child: Text(context.tr('DUTY', 'कर्तव्य'),
                        style: AppText.tiny(context))),
                Expanded(
                    flex: 1,
                    child: Text(context.tr('SUPERVISOR(S)', 'पर्यवेक्षक'),
                        style: AppText.tiny(context))),
              ],
            ),
          ),
          for (final (i, r) in _rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: i == _rows.length - 1
                    ? null
                    : Border(
                        bottom:
                            BorderSide(color: AppTokens.tint(t.border, 0.6))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Text(r.dutyLabel,
                          style: AppText.bodyMedium(context))),
                  Expanded(
                    child: Text(formatSupervisorNames(r.supervisorNames),
                        style: AppText.body(context)
                            .copyWith(color: t.mutedForeground)),
                  ),
                ],
              ),
            ),
          if (!widget.isResident)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${dutiesPeriodLabel(periodFrom: chart.periodFrom, periodTo: chart.periodTo, hi: _hi)} · ${context.tr('visible to residents', 'निवासियों को दिखता है')}',
                style: AppText.tiny(context),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasChart = _chart != null && _rows.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
                    Row(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 16, color: t.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                              context.tr('Standard Duties Chart',
                                  'मानक कर्तव्य चार्ट'),
                              style: AppText.sectionTitle(context).copyWith(
                                  fontSize: widget.isResident ? 14 : 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isResident
                          ? context.tr(
                              'Who supervises each operational duty for the current period.',
                              'वर्तमान अवधि में प्रत्येक कार्य का पर्यवेक्षण कौन करता है।')
                          : context.tr(
                              'Assign supervisors to standard duties for a date period; residents see this read-only.',
                              'एक अवधि के लिए मानक कर्तव्यों पर पर्यवेक्षक नियुक्त करें; निवासी इसे केवल देख सकते हैं।'),
                      style: AppText.caption(context),
                    ),
                  ],
                ),
              ),
              if (!widget.isResident && !_editing) ...[
                if (hasChart)
                  IconPillButton(
                    icon: Icons.delete_outline,
                    tooltip: context.tr('Remove chart', 'चार्ट हटाएँ'),
                    color: t.destructive,
                    background: AppTokens.tint(t.destructive, 0.1),
                    onPressed: _removeChart,
                  ),
                const SizedBox(width: 6),
                MiniButton(
                  label: hasChart
                      ? context.tr('Edit', 'संपादित')
                      : context.tr('Create', 'बनाएँ'),
                  icon: Icons.edit_outlined,
                  variant: MiniVariant.secondary,
                  onPressed: _startEdit,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Text(
                context.tr(
                    'Loading duties chart…', 'कर्तव्य चार्ट लोड हो रहा है…'),
                style: AppText.caption(context))
          else if (_editing && !widget.isResident)
            _editor()
          else if (hasChart)
            _table()
          else
            CardSection(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 32, color: AppTokens.tint(t.mutedForeground, 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    widget.isResident
                        ? context.tr('No duties chart published yet.',
                            'अभी कोई कर्तव्य चार्ट प्रकाशित नहीं।')
                        : context.tr(
                            'Create a standard duties chart for residents to see.',
                            'निवासियों के लिए मानक कर्तव्य चार्ट बनाएँ।'),
                    textAlign: TextAlign.center,
                    style: AppText.body(context)
                        .copyWith(color: t.mutedForeground),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
