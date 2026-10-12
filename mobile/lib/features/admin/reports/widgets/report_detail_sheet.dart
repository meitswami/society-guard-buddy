import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../shared/pdf/report_pdf_actions.dart';
import '../export/report_detail_pdf.dart';
import '../logic/report_detail_row.dart';
import '../logic/report_formatters.dart';
import '../logic/report_query_filter.dart';
import '../logic/statement_amount_totals.dart';
import 'report_ui.dart';

export '../logic/report_detail_row.dart';

/// One screen of the drill-down sheet (web `ReportDetailModal` props / CashFlow `ModalLayer`).
class ReportDetailLayer {
  const ReportDetailLayer({
    required this.title,
    this.subtitle,
    this.totalAmount,
    required this.rows,
    this.onRowTap,
    this.searchable = true,
  });

  final String title;
  final String? subtitle;
  final double? totalAmount;
  final List<ReportDetailRow> rows;

  /// When set, rows are drillable; returning a layer pushes it (back button appears).
  final ReportDetailLayer? Function(ReportDetailRow row)? onRowTap;
  final bool searchable;
}

/// Bottom-sheet port of `ReportDetailModal` (search, monthly totals, transaction
/// total, WhatsApp PDF share, nested drill-down with back).
class ReportDetailSheet extends StatefulWidget {
  const ReportDetailSheet({super.key, required this.root, this.initialSearchQuery = '', this.societyName});

  final ReportDetailLayer root;
  final String initialSearchQuery;
  final String? societyName;

  static Future<void> show(
    BuildContext context,
    ReportDetailLayer layer, {
    String initialSearchQuery = '',
    String? societyName,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.tokens.background,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl))),
        builder: (_) => ReportDetailSheet(root: layer, initialSearchQuery: initialSearchQuery, societyName: societyName),
      );

  @override
  State<ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<ReportDetailSheet> {
  late final List<ReportDetailLayer> _stack = [widget.root];
  late final TextEditingController _search = TextEditingController(text: widget.initialSearchQuery);

  ReportDetailLayer get _layer => _stack.last;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _push(ReportDetailLayer next) => setState(() {
        _stack.add(next);
        _search.text = '';
      });

  void _back() => setState(() {
        _stack.removeLast();
        _search.text = '';
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final layer = _layer;
    final q = _search.text;
    final filtered = filterReportDetailRows(layer.rows, q);
    final withAmounts = filtered.where((r) => r.amount != null).toList();
    final transactionTotal = sumAmountRows(withAmounts.map((r) => r.amount));
    final monthly = monthlyAmountTotals(withAmounts.map((r) => AmountRow(amount: r.amount, dateIso: r.dateIso, date: r.date)));
    final hasAmounts = withAmounts.isNotEmpty;
    final canDrill = layer.onRowTap != null;
    final showSearch = layer.searchable && layer.rows.isNotEmpty;
    final records = filtered.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                if (_stack.length > 1) IconButton(onPressed: _back, icon: const Icon(Icons.chevron_left), tooltip: 'Back'),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(layer.title, style: AppText.sectionTitle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if ((layer.subtitle ?? '').isNotEmpty)
                        Text(layer.subtitle!, style: AppText.tiny(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (layer.totalAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(rupees(layer.totalAmount!), style: AppText.mono(context, size: 14, weight: FontWeight.w600, color: t.primary)),
                  ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: context.t('mobile.close')),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
                      hintText: context.tr('Search in this list…', 'इस सूची में खोजें…'),
                    ),
                  ),
                  if (q.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        context.tr('${filtered.length} of ${layer.rows.length} match', '${layer.rows.length} में से ${filtered.length} मेल'),
                        style: AppText.tiny(context),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: layer.rows.isEmpty
                ? EmptyView(message: context.tr('No data available', 'कोई डेटा उपलब्ध नहीं'))
                : filtered.isEmpty
                    ? EmptyView(message: context.tr('No matches for your search', 'आपकी खोज से कोई मेल नहीं'))
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, i) => _RowTile(
                          row: filtered[i],
                          onTap: canDrill
                              ? () {
                                  final next = layer.onRowTap!(filtered[i]);
                                  if (next != null) _push(next);
                                }
                              : null,
                        ),
                      ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(children: [
                      SharePdfWhatsAppButton(
                        label: context.tr('Share on WhatsApp', 'व्हाट्सऐप पर साझा करें'),
                        filename: reportDetailPdfFilename(layer.title),
                        message: [widget.societyName, layer.title, layer.subtitle]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' — '),
                        getBytes: () => buildReportDetailPdf(
                          societyName: widget.societyName,
                          title: layer.title,
                          subtitle: layer.subtitle,
                          totalAmount: layer.totalAmount,
                          rows: filtered,
                        ),
                      ),
                    ]),
                  ),
                if (hasAmounts && monthly.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTokens.tint(t.muted, 0.5),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      border: Border.all(color: AppTokens.tint(t.border, 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('MONTHLY TOTALS', 'मासिक योग'), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        for (final m in monthly)
                          Row(
                            children: [
                              Expanded(child: Text('${m.label} (${m.count})', style: AppText.caption(context).copyWith(fontSize: 11))),
                              Text(
                                fmtSignedRupees(m.total),
                                style: AppText.mono(context, size: 11, weight: FontWeight.w600, color: m.total < 0 ? t.destructive : null),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (hasAmounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${context.tr('Transaction total', 'लेनदेन योग')}: '),
                        TextSpan(
                          text: fmtSignedRupees(transactionTotal),
                          style: AppText.mono(context, size: 12, weight: FontWeight.w700, color: transactionTotal < 0 ? t.destructive : t.primary),
                        ),
                      ]),
                      textAlign: TextAlign.center,
                      style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(
                  [
                    context.tr('$records record${records != 1 ? 's' : ''}', '$records अभिलेख'),
                    if (q.trim().isNotEmpty && records != layer.rows.length) context.tr(' (of ${layer.rows.length})', ' (${layer.rows.length} में से)'),
                    if (canDrill) context.tr(' · Tap a row for entry detail', ' · विवरण के लिए पंक्ति पर टैप करें'),
                  ].join(),
                  textAlign: TextAlign.center,
                  style: AppText.tiny(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, this.onTap});

  final ReportDetailRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final amount = row.amount;
    return Material(
      color: AppTokens.tint(t.card, 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        side: BorderSide(color: AppTokens.tint(t.border, 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label, style: AppText.bodyMedium(context).copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((row.sublabel ?? '').isNotEmpty)
                      Text(row.sublabel!, style: AppText.tiny(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((row.date ?? '').isNotEmpty) Text(row.date!, style: AppText.tiny(context)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (amount != null)
                    Text(
                      fmtSignedRupees(amount),
                      style: AppText.mono(context, size: 12, weight: FontWeight.w600, color: amount < 0 ? t.destructive : null),
                    ),
                  if ((row.status ?? '').isNotEmpty) MiniStatusChip(row.status!, color: reportStatusColor(context, row.status)),
                  if ((row.extra ?? '').isNotEmpty) Text(row.extra!, style: AppText.tiny(context)),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: t.mutedForeground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
