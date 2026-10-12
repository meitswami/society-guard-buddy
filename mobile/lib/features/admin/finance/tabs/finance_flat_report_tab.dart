// Port of `src/components/finance/FinanceFlatReportTab.tsx` (used by Reports → Flat-wise).
// `FinanceFlatReportTab` takes the same inputs as web; `FinanceFlatReportPanel` loads its own data.

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/finance_repository.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_flat_report.dart';
import '../logic/finance_format.dart';
import '../logic/finance_models.dart';
import '../logic/finance_period_report.dart';
import '../widgets/fin_kit.dart';
import '../widgets/finance_metric_copy.dart';

class FinanceFlatReportTab extends StatelessWidget {
  const FinanceFlatReportTab({
    super.key,
    required this.from,
    required this.to,
    required this.selectedFlat,
    required this.onFromChange,
    required this.onToChange,
    required this.onSelectedFlatChange,
    required this.flats,
    required this.primaryByFlatId,
    required this.isLoading,
    required this.rows,
  });

  final String from;
  final String to;
  final String selectedFlat;
  final ValueChanged<String> onFromChange;
  final ValueChanged<String> onToChange;
  final ValueChanged<String> onSelectedFlatChange;
  final List<SocietyFlatRow> flats;
  final Map<String, String> primaryByFlatId;
  final bool isLoading;
  final List<FlatReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = FinMetrics.of(context);
    double sum(double Function(FlatReportRow) f) =>
        rows.fold(0.0, (s, r) => s + f(r));
    Widget stat(FinCopy copy, double v, Color color) => DescriptiveStatCard(
          compact: true,
          title: copy.$1,
          description: copy.$2,
          howCalculated: copy.$3,
          value: inrLocale(v),
          valueColor: color,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardSection(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => AppFeedback.info(
                  context,
                  title: context.tr('Flat-wise Financial Report',
                      'फ्लैट-वार वित्तीय रिपोर्ट'),
                  description: context.tr(
                    'Per-flat breakdown of maintenance receipts and society payment splits for reporting & visibility — not for accounting.',
                    'रिपोर्टिंग व पारदर्शिता हेतु प्रति फ्लैट रखरखाव रसीदों और सोसाइटी भुगतान बँटवारे का विवरण — लेखांकन हेतु नहीं।',
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppTokens.tint(t.accent, 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          Icon(Icons.currency_rupee, size: 20, color: t.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            context.tr('Flat-wise Financial Report',
                                'फ्लैट-वार वित्तीय रिपोर्ट'),
                            style: AppText.sectionTitle(context))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: FinDateField(
                          label: context.tr('From', 'से'),
                          value: from,
                          onChanged: onFromChange)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: FinDateField(
                          label: context.tr('To', 'तक'),
                          value: to,
                          onChanged: onToChange)),
                ],
              ),
              const SizedBox(height: 8),
              AppDropdown<String>(
                label: context.tr('Flat', 'फ्लैट'),
                items: ['all', ...flats.map((f) => f.flatNumber)],
                value: selectedFlat,
                labelOf: (fn) {
                  if (fn == 'all') return context.tr('All flats', 'सभी फ्लैट');
                  final f = flats.firstWhere((x) => x.flatNumber == fn);
                  final who = primaryByFlatId[f.id] ??
                      ((f.ownerName ?? '').isNotEmpty
                          ? f.ownerName!
                          : context.tr('Vacant', 'खाली'));
                  return '$fn — $who';
                },
                onChanged: (v) => onSelectedFlatChange(v ?? 'all'),
              ),
              if (from.compareTo(to) > 0)
                FinHint(
                    context.tr('End date must be on or after the start date.',
                        'अंतिम तिथि आरंभ तिथि के बाद हो।'),
                    color: t.destructive),
            ],
          ),
        ),
        if (isLoading)
          LoadingView(
              message: context.tr('Loading flat report data…',
                  'फ्लैट रिपोर्ट डेटा लोड हो रहा है…'))
        else if (rows.isEmpty)
          EmptyView(
            message: context.tr(
              'No financial activity found for the selected period${selectedFlat != 'all' ? ' (Flat $selectedFlat)' : ''}.',
              'चुनी अवधि में कोई वित्तीय गतिविधि नहीं मिली${selectedFlat != 'all' ? ' (फ्लैट $selectedFlat)' : ''}।',
            ),
          )
        else ...[
          StatGrid(
            spacing: 8,
            children: [
              stat(m.flatTotalReceipts, sum((r) => r.maintenancePaid),
                  t.success),
              stat(m.flatExpenseShare, sum((r) => r.expenseShare),
                  t.destructive),
              stat(m.flatSettled, sum((r) => r.settledAmount), t.accent),
              stat(m.flatUnsettled, sum((r) => r.unsettledAmount), t.warning),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in rows) _FlatRowCard(row: r),
        ],
      ],
    );
  }
}

class _FlatRowCard extends StatelessWidget {
  const _FlatRowCard({required this.row});

  final FlatReportRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = row;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text('${context.tr('Flat', 'फ्लैट')} ${r.flatNumber}',
              style: AppText.sectionTitle(context)),
          subtitle: Text(r.residentName,
              style: AppText.tiny(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text:
                            '${context.tr('Paid', 'दिया')} ${inrLocale(r.maintenancePaid)}',
                        style: TextStyle(color: t.success)),
                    const TextSpan(text: ' · '),
                    TextSpan(
                        text:
                            '${context.tr('Share', 'हिस्सा')} ${inrLocale(r.expenseShare)}',
                        style: TextStyle(color: t.destructive)),
                  ]),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
              Text(
                '${context.tr('Net', 'शुद्ध')}: ${r.netPosition >= 0 ? '+' : ''}${inrLocale(r.netPosition)}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: r.netPosition >= 0 ? t.success : t.destructive),
              ),
            ],
          ),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                    '${context.tr('Maintenance receipts', 'रखरखाव रसीदें')}: ${r.maintenanceCount}',
                    style: AppText.caption(context)),
                Text(
                    '${context.tr('Expense splits', 'व्यय बँटवारे')}: ${r.expenseCount}',
                    style: AppText.caption(context)),
                Text(
                    '${context.tr('Settled', 'निपटाया')}: ${inrLocale(r.settledAmount)}',
                    style: AppText.caption(context).copyWith(color: t.accent)),
                Text(
                    '${context.tr('Unsettled', 'बकाया')}: ${inrLocale(r.unsettledAmount)}',
                    style: AppText.caption(context).copyWith(color: t.warning)),
              ],
            ),
            if (r.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              FinTable(
                columns: [
                  FinCol(context.tr('Type', 'प्रकार'), width: 70),
                  FinCol(context.tr('Description', 'विवरण'), width: 170),
                  FinCol(context.tr('Amount', 'राशि'), width: 80, right: true),
                  FinCol(context.tr('Date', 'तिथि'), width: 80),
                  FinCol(context.tr('Method', 'माध्यम'), width: 90),
                  FinCol(context.tr('Status', 'स्थिति'), width: 76),
                ],
                rows: [
                  for (final dt in r.details)
                    [
                      FinStatusPill(
                          status:
                              dt.type == 'maintenance' ? 'receipt' : 'expense'),
                      finCell(
                          context,
                          dt.groupName != null
                              ? '[${dt.groupName}] ${dt.title}'
                              : dt.title),
                      finCell(context, inrLocale(dt.amount),
                          mono: true, bold: true),
                      finCell(context, isoDateToDisplay(dt.date),
                          color: t.mutedForeground),
                      finCell(context, dt.method.replaceAll('_', ' ')),
                      FinStatusPill(status: dt.status),
                    ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Self-loading flat-wise report (core finance data + flat report expenses / splits).
class FinanceFlatReportPanel extends StatefulWidget {
  const FinanceFlatReportPanel(
      {super.key, required this.societyId, this.repository});

  final String societyId;
  final FinanceRepository? repository;

  @override
  State<FinanceFlatReportPanel> createState() => _FinanceFlatReportPanelState();
}

class _FinanceFlatReportPanelState extends State<FinanceFlatReportPanel> {
  late final FinanceRepository _repo =
      widget.repository ?? SupabaseFinanceRepository();
  FinanceCoreData? _core;
  FinanceFlatReportData? _report;
  bool _loading = true;
  String _from = defaultFinancePeriodFrom();
  String _to = defaultFinancePeriodTo();
  String _flat = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.fetchCore(widget.societyId, 'Report'),
        _repo.fetchFlatReport(widget.societyId)
      ]);
      if (!mounted) return;
      setState(() {
        _core = results[0] as FinanceCoreData;
        _report = results[1] as FinanceFlatReportData;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final core = _core ?? const FinanceCoreData();
    final rep = _report ?? const FinanceFlatReportData();
    final rows = _from.compareTo(_to) > 0
        ? const <FlatReportRow>[]
        : buildFlatReportRows(
            from: _from,
            to: _to,
            selectedFlat: _flat,
            payments: core.payments,
            ledgerEntries: core.ledgerEntries,
            flatReportExpenses: rep.expenses,
            flatReportSplits: rep.splits,
            flats: core.flats,
            primaryByFlatId: core.primaryByFlatId,
            charges: core.charges,
          );
    return FinanceFlatReportTab(
      from: _from,
      to: _to,
      selectedFlat: _flat,
      onFromChange: (v) => setState(() => _from = v),
      onToChange: (v) => setState(() => _to = v),
      onSelectedFlatChange: (v) => setState(() => _flat = v),
      flats: core.flats,
      primaryByFlatId: core.primaryByFlatId,
      isLoading: _loading,
      rows: rows,
    );
  }
}
