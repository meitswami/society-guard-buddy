import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/report_models.dart';
import '../logic/flat_report.dart';
import '../logic/metric_copy.dart';
import '../logic/report_formatters.dart';
import 'report_ui.dart';

/// Port of `FinanceFlatReportTab` (Reports → Financial → Flat wise Financial Report).
class FlatReportView extends StatelessWidget {
  const FlatReportView({
    super.key,
    required this.from,
    required this.to,
    required this.selectedFlat,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSelectedFlatChanged,
    required this.flats,
    required this.primaryByFlatId,
    required this.isLoading,
    required this.rows,
  });

  final String from;
  final String to;
  final String selectedFlat;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final ValueChanged<String> onSelectedFlatChanged;
  final List<ReportFlat> flats;
  final Map<String, String> primaryByFlatId;
  final bool isLoading;
  final List<FlatReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    double sum(double Function(FlatReportRow) f) =>
        rows.fold(0, (s, r) => s + f(r));
    final flatOptions = ['all', for (final f in flats) f.flatNumber];
    String flatLabel(String v) {
      if (v == 'all') return context.tr('All flats', 'सभी फ्लैट');
      final f = flats.firstWhere((x) => x.flatNumber == v);
      final name = primaryByFlatId[f.id] ??
          ((f.ownerName ?? '').isNotEmpty
              ? f.ownerName!
              : context.tr('Vacant', 'खाली'));
      return '${f.flatNumber} — $name';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppTokens.tint(t.accent, 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.currency_rupee, size: 20, color: t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => AppFeedback.info(
                      context,
                      title: context.tr('Flat-wise Financial Report',
                          'फ्लैट-वार वित्तीय प्रतिवेदन'),
                      description: context.tr(
                        'Per-flat breakdown of maintenance receipts and society payment splits for reporting & visibility — not for accounting.',
                        'रिपोर्टिंग व पारदर्शिता हेतु प्रति फ्लैट रखरखाव रसीदों और सोसाइटी भुगतान विभाजन का ब्योरा — लेखांकन के लिए नहीं।',
                      ),
                    ),
                    child: Text(
                        context.tr('Flat-wise Financial Report',
                            'फ्लैट-वार वित्तीय प्रतिवेदन'),
                        style: AppText.sectionTitle(context)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: ReportDateField(
                        label: context.tr('From', 'से'),
                        value: from,
                        onChanged: onFromChanged)),
                const SizedBox(width: 8),
                Expanded(
                    child: ReportDateField(
                        label: context.tr('To', 'तक'),
                        value: to,
                        onChanged: onToChanged)),
              ]),
              const SizedBox(height: 10),
              AppDropdown<String>(
                label: context.tr('Flat', 'फ्लैट'),
                items: flatOptions,
                value:
                    flatOptions.contains(selectedFlat) ? selectedFlat : 'all',
                labelOf: flatLabel,
                onChanged: (v) => onSelectedFlatChanged(v ?? 'all'),
              ),
              if (from.compareTo(to) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr('End date must be on or after the start date.',
                        'अंतिम तारीख प्रारंभ तारीख के बराबर या बाद की होनी चाहिए।'),
                    style: TextStyle(fontSize: 12, color: t.destructive),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          LoadingView(
              message: context.tr('Loading flat report data…',
                  'फ्लैट प्रतिवेदन डेटा लोड हो रहा है…'))
        else if (rows.isEmpty)
          EmptyView(
            message: context.tr(
              'No financial activity found for the selected period${selectedFlat != 'all' ? ' (Flat $selectedFlat)' : ''}.',
              'चुनी अवधि में कोई वित्तीय गतिविधि नहीं मिली${selectedFlat != 'all' ? ' (फ्लैट $selectedFlat)' : ''}।',
            ),
          )
        else ...[
          StatGrid(spacing: 8, children: [
            _stat(context, ReportMetrics.flatTotalReceipts,
                rupees(sum((r) => r.maintenancePaid)), t.success),
            _stat(context, ReportMetrics.flatExpenseShare,
                rupees(sum((r) => r.expenseShare)), t.destructive),
            _stat(context, ReportMetrics.flatSettled,
                rupees(sum((r) => r.settledAmount)), t.primary),
            _stat(context, ReportMetrics.flatUnsettled,
                rupees(sum((r) => r.unsettledAmount)), t.warning),
          ]),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FlatRowCard(row: row)),
        ],
      ],
    );
  }

  Widget _stat(BuildContext context, MetricCopy m, String value, Color color) =>
      ReportStatCard(metric: m, value: value, valueColor: color, compact: true);
}

class _FlatRowCard extends StatelessWidget {
  const _FlatRowCard({required this.row});

  final FlatReportRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final net = row.netPosition;
    return CardSection(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text('${context.tr('Flat', 'फ्लैट')} ${row.flatNumber}',
              style: AppText.sectionTitle(context)),
          subtitle: Text(row.residentName,
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
                          '${context.tr('Paid', 'भुगतान')} ${rupees(row.maintenancePaid)}',
                      style: TextStyle(
                          color: t.success, fontWeight: FontWeight.w500),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text:
                          '${context.tr('Share', 'हिस्सा')} ${rupees(row.expenseShare)}',
                      style: TextStyle(
                          color: t.destructive, fontWeight: FontWeight.w500),
                    ),
                  ]),
                  style: TextStyle(fontSize: 11, color: t.foreground)),
              Text(
                '${context.tr('Net', 'नेट')}: ${net >= 0 ? '+' : ''}${rupees(net)}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: net >= 0 ? t.success : t.destructive),
              ),
            ],
          ),
          children: [
            Wrap(spacing: 14, runSpacing: 4, children: [
              _kv(
                  context,
                  context.tr('Maintenance receipts:', 'रखरखाव रसीदें:'),
                  '${row.maintenanceCount}'),
              _kv(context, context.tr('Expense splits:', 'खर्च विभाजन:'),
                  '${row.expenseCount}'),
              _kv(context, context.tr('Settled:', 'निपटाया:'),
                  rupees(row.settledAmount),
                  color: t.primary),
              _kv(context, context.tr('Unsettled:', 'बकाया:'),
                  rupees(row.unsettledAmount),
                  color: t.warning),
            ]),
            if (row.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 44,
                  horizontalMargin: 8,
                  columnSpacing: 14,
                  headingTextStyle: AppText.caption(context).copyWith(
                      fontWeight: FontWeight.w600, color: t.foreground),
                  dataTextStyle: AppText.body(context).copyWith(fontSize: 12),
                  columns: [
                    DataColumn(label: Text(context.tr('Type', 'प्रकार'))),
                    DataColumn(label: Text(context.tr('Description', 'विवरण'))),
                    DataColumn(
                        label: Text(context.tr('Amount', 'राशि')),
                        numeric: true),
                    DataColumn(label: Text(context.tr('Date', 'तारीख'))),
                    DataColumn(label: Text(context.tr('Method', 'विधि'))),
                    DataColumn(label: Text(context.tr('Status', 'स्थिति'))),
                  ],
                  rows: [
                    for (final d in row.details)
                      DataRow(cells: [
                        DataCell(MiniStatusChip(
                          d.type == 'maintenance'
                              ? context.tr('Receipt', 'रसीद')
                              : context.tr('Expense', 'खर्च'),
                          color:
                              d.type == 'maintenance' ? t.success : t.warning,
                          capitalize: false,
                        )),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text.rich(
                            TextSpan(children: [
                              if ((d.groupName ?? '').isNotEmpty)
                                TextSpan(
                                    text: '[${d.groupName}] ',
                                    style: TextStyle(color: t.mutedForeground)),
                              TextSpan(text: d.title),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(rupees(d.amount),
                            style: AppText.mono(context,
                                size: 12, weight: FontWeight.w500))),
                        DataCell(Text(fmtIsoDateToDisplay(d.date),
                            style: AppText.caption(context))),
                        DataCell(Text(
                            capitalizeWords(d.method.replaceAll('_', ' ')))),
                        DataCell(MiniStatusChip(
                          d.status,
                          color: (d.status == 'paid' ||
                                  d.status == 'verified' ||
                                  d.status == 'settled')
                              ? t.success
                              : t.warning,
                          capitalize: false,
                        )),
                      ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Color? color}) =>
      Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$k ',
              style: TextStyle(color: context.tokens.mutedForeground)),
          TextSpan(
              text: v,
              style: TextStyle(fontWeight: FontWeight.w500, color: color)),
        ]),
        style: const TextStyle(fontSize: 11),
      );
}
