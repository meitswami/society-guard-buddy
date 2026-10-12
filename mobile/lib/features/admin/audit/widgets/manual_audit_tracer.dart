import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/audit_service.dart';
import '../logic/js_compat.dart';
import '../logic/manual_trace_engine.dart';
import 'audit_ui.dart';
import 'month_picker.dart';

/// Port of `ManualAuditTracer.tsx` — trace recording vs reporting mismatches for one month.
class ManualAuditTracer extends StatefulWidget {
  const ManualAuditTracer({super.key, required this.societyId, required this.onNavigate});

  final String societyId;

  /// `(tab, subTab)` — tab is `finance` | `audit` | `report`.
  final void Function(String tab, String? subTab) onNavigate;

  @override
  State<ManualAuditTracer> createState() => _ManualAuditTracerState();
}

class _ManualAuditTracerState extends State<ManualAuditTracer> {
  final _service = const AuditService();
  String _month = ymOfDate(DateTime.now());
  final _expected = TextEditingController();
  TraceSource _source = TraceSource.periodReport;
  bool _running = false;
  TraceResult? _result;
  String? _expanded;

  @override
  void dispose() {
    _expected.dispose();
    super.dispose();
  }

  Future<void> _trace() async {
    if (widget.societyId.isEmpty || _month.isEmpty) return;
    final hi = context.isHi;
    setState(() {
      _running = true;
      _result = null;
    });
    TraceResult r;
    try {
      final d = await _service.fetchTraceInput(widget.societyId);
      r = computeManualTrace(
        charges: d.charges,
        payments: d.payments,
        ledger: d.ledger,
        month: _month,
        expectedAmount: _expected.text,
        source: _source,
        hi: hi,
      );
    } catch (e) {
      r = manualTraceError(auditErrText(e), source: _source, expectedAmount: _expected.text, hi: hi);
    }
    if (!mounted) return;
    setState(() {
      _result = r;
      _running = false;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, initial: _month, min: financeReportingEarliestMonth);
    if (picked != null) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.place_outlined,
          tone: Tone.warning,
          title: context.tr('Manual Discrepancy Tracer', 'मैन्युअल असंगति ट्रेसर'),
          subtitle: context.tr('Pick a month to scan for recording issues — optionally enter an expected amount to compare',
              'दर्ज करने की समस्याएँ जाँचने के लिए माह चुनें — तुलना के लिए चाहें तो अपेक्षित राशि दर्ज करें'),
        ),
        const SizedBox(height: 12),
        CardSection(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      FieldLabel(context.tr('Month', 'माह')),
                      InkWell(
                        onTap: _pickMonth,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        child: InputDecorator(
                          decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_month_outlined, size: 18)),
                          child: Text(fmtIsoMonthToDisplay(_month), style: AppText.body(context)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDropdown<TraceSource>(
                      label: context.tr('Report Source', 'रिपोर्ट स्रोत'),
                      items: TraceSource.values,
                      value: _source,
                      labelOf: (s) => traceSourceOption(s, hi: context.isHi),
                      onChanged: (v) => setState(() => _source = v ?? _source),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: context.tr('Actual / Expected Collection (₹) — optional', 'वास्तविक / अपेक्षित संग्रह (₹) — वैकल्पिक'),
                controller: _expected,
                mono: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                hint: context.tr('Leave blank to scan without money', 'बिना राशि जाँच के लिए खाली छोड़ें'),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('Optional. Enter a bank/manual figure to compare; leave empty to find structural issues only.',
                    'वैकल्पिक। तुलना के लिए बैंक/मैन्युअल आँकड़ा दर्ज करें; केवल संरचनात्मक समस्याएँ खोजने के लिए खाली छोड़ें।'),
                style: TextStyle(fontSize: 9, color: t.mutedForeground),
              ),
              const SizedBox(height: 12),
              SmallButton(
                label: _running ? context.tr('Tracing…', 'ट्रेस हो रहा है…') : context.tr('Trace Discrepancy', 'असंगति ट्रेस करें'),
                icon: Icons.search,
                style: SmallBtnStyle.warning,
                busy: _running,
                expand: true,
                fontSize: 14,
                onPressed: widget.societyId.isEmpty ? null : _trace,
              ),
            ],
          ),
        ),
        if (_result != null) ...[const SizedBox(height: 12), ..._results(_result!)],
      ],
    );
  }

  List<Widget> _results(TraceResult r) {
    final t = context.tokens;
    final hi = context.isHi;
    final src = traceSourceText(r.source, hi: hi);
    const computedTitle = ('System total', 'प्रणाली योग');
    final computedDesc = context.tr('Amount the app calculates from ledger / maintenance data for the month you traced.',
        'ट्रेस किए गए माह के लिए लेजर / रखरखाव डेटा से ऐप द्वारा गणना की गई राशि।');
    final computedHow = context.tr('Built from finance_entries or maintenance_payments per the selected source.',
        'चुने गए स्रोत के अनुसार finance_entries या maintenance_payments से बनाई गई।');
    final summary = <Widget>[];
    if (r.expectedTotal != null && r.difference != null) {
      final match = r.difference!.abs() < 1;
      final c = match ? t.success : t.warning;
      summary.add(StatGrid(columns: 3, spacing: 8, children: [
        DescriptiveStatCard(
          compact: true,
          title: context.tr(computedTitle.$1, computedTitle.$2),
          caption: hi ? 'प्रणाली ($src)' : 'System ($src)',
          description: computedDesc,
          howCalculated: computedHow,
          value: jsInr(r.computedTotal),
          borderColor: AppTokens.tint(c, 0.3),
        ),
        if (match)
          DescriptiveStatCard(
            compact: true,
            title: context.tr('Figures match', 'आँकड़े मेल खाते हैं'),
            caption: context.tr('Match', 'मेल'),
            description: context.tr('The system total equals your expected amount for this month and source.',
                'प्रणाली योग इस माह और स्रोत के लिए आपकी अपेक्षित राशि के बराबर है।'),
            howCalculated: context.tr('No discrepancy when the absolute gap between computed and expected totals is under ₹1.',
                'जब गणना और अपेक्षित योग का अंतर ₹1 से कम हो तो कोई असंगति नहीं।'),
            value: '✓',
            valueColor: t.success,
            borderColor: AppTokens.tint(t.success, 0.3),
          )
        else
          DescriptiveStatCard(
            compact: true,
            title: context.tr('Difference', 'अंतर'),
            caption: r.difference! > 0 ? context.tr('Over-reported', 'अधिक दर्शाया') : context.tr('Under-reported', 'कम दर्शाया'),
            description: context.tr('Gap between system total and your expected amount (when an amount was entered).',
                'प्रणाली योग और आपकी अपेक्षित राशि के बीच का अंतर (जब राशि दर्ज हो)।'),
            howCalculated: context.tr('computedTotal − expectedTotal. Positive = system shows more than expected.',
                'computedTotal − expectedTotal। धनात्मक = प्रणाली अपेक्षा से अधिक दिखाती है।'),
            value: '${r.difference! > 0 ? '+' : ''}${jsInr(r.difference!)}',
            valueColor: r.difference! > 0 ? t.destructive : t.warning,
            borderColor: AppTokens.tint(t.warning, 0.3),
          ),
        DescriptiveStatCard(
          compact: true,
          title: context.tr('Expected total', 'अपेक्षित योग'),
          caption: context.tr('Expected (yours)', 'अपेक्षित (आपका)'),
          description: context.tr('Optional amount you entered as the correct figure to compare against the system.',
              'प्रणाली से तुलना के लिए सही आँकड़े के रूप में दर्ज की गई वैकल्पिक राशि।'),
          howCalculated: context.tr('Your manual expected amount input for this trace. Leave blank to run structural checks only.',
              'इस ट्रेस के लिए आपकी मैन्युअल अपेक्षित राशि। केवल संरचनात्मक जाँच के लिए खाली छोड़ें।'),
          value: jsInr(r.expectedTotal!),
          borderColor: AppTokens.tint(c, 0.3),
        ),
      ]));
    } else {
      summary.add(DescriptiveStatCard(
        compact: true,
        title: context.tr(computedTitle.$1, computedTitle.$2),
        caption: hi ? 'प्रणाली ($src) — संरचनात्मक जाँच' : 'System ($src) — structural scan',
        description: computedDesc,
        howCalculated: computedHow,
        value: jsInr(r.computedTotal),
        borderColor: AppTokens.tint(t.accent, 0.2),
      ));
    }
    return [
      ...summary,
      const SizedBox(height: 12),
      for (final f in r.findings) ...[_findingCard(f), const SizedBox(height: 12)],
    ];
  }

  Widget _findingCard(TraceFinding f) {
    final t = context.tokens;
    final (Tone tone, IconData icon) = switch (f.severity) {
      TraceSeverity.error => (Tone.destructive, Icons.cancel_outlined),
      TraceSeverity.warning => (Tone.warning, Icons.warning_amber_rounded),
      TraceSeverity.info => (Tone.info, Icons.description_outlined),
    };
    final expanded = _expanded == f.id;
    return ToneCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = expanded ? null : f.id),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: toneColor(context, tone))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, style: AppText.sectionTitle(context)),
                  const SizedBox(height: 2),
                  Text(f.description, style: AppText.caption(context)),
                ]),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: t.mutedForeground),
            ]),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 12),
            TinyLabel(context.tr('Mistake Origin', 'गलती का स्रोत'), icon: Icons.place_outlined),
            const SizedBox(height: 4),
            Text(f.origin, style: TextStyle(fontSize: 12, color: t.foreground)),
            if (f.data != null) ...[
              const SizedBox(height: 12),
              TinyLabel(context.tr('Details', 'विवरण')),
              RawDataBox(data: f.data!, indent: ' ', maxHeight: 160),
            ],
            const SizedBox(height: 12),
            SmallButton(
              label: f.navigateLabel,
              icon: Icons.open_in_new,
              style: SmallBtnStyle.primary,
              expand: true,
              fontSize: 12,
              onPressed: () => widget.onNavigate(f.navigateTo, f.navigateSubTab),
            ),
          ],
        ],
      ),
    );
  }
}
