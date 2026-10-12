// Ports of UnpaidFlatGridTable, FlatMultiSelect, RecordingDateBanner and ReportDetailModal.

import 'package:flutter/material.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../export/finance_exports.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_derived.dart';
import '../logic/finance_format.dart';
import '../logic/flat_sort.dart';
import '../logic/statement_amount_totals.dart';
import '../logic/transactions_view.dart';
import 'fin_kit.dart';

/// Web `UnpaidFlatGridTable`.
class UnpaidFlatGridTable extends StatelessWidget {
  const UnpaidFlatGridTable({super.key, required this.rows, required this.emptyMessage, this.showChargeColumn = true});

  final List<UnpaidFlatGridRow> rows;
  final String emptyMessage;
  final bool showChargeColumn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (rows.isEmpty) return EmptyView(message: emptyMessage);
    final totalDue = rows.fold<double>(0, (s, r) => s + (r.dueAmount ?? 0));
    final hasDue = showChargeColumn && rows.any((r) => r.dueAmount != null);
    Widget pill(String label, Color c, {bool muted = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: muted ? t.muted : AppTokens.tint(c, 0.18), borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: muted ? t.mutedForeground : c)),
        );
    final cols = [
      const FinCol('#', width: 34),
      FinCol(context.tr('Flat', 'फ्लैट'), width: 64),
      FinCol(context.tr('Resident', 'निवासी'), width: 130),
      FinCol(context.tr('Occupancy', 'अधिभोग'), width: 76),
      if (showChargeColumn) FinCol(context.tr('Charge', 'शुल्क'), width: 130),
      if (hasDue) FinCol(context.tr('Due amount', 'देय राशि'), width: 84, right: true),
      FinCol(context.tr('Status', 'स्थिति'), width: 76),
    ];
    return FinTable(
      columns: cols,
      rows: [
        for (var i = 0; i < rows.length; i++)
          [
            finCell(context, '${i + 1}', color: t.mutedForeground),
            finCell(context, rows[i].flatNumber, mono: true, bold: true),
            finCell(context, rows[i].primaryName.isEmpty ? context.tr('Primary member not found', 'मुख्य सदस्य नहीं मिला') : rows[i].primaryName),
            rows[i].isOccupied == true
                ? pill(context.tr('Occupied', 'आबाद'), t.success)
                : pill(context.tr('Vacant', 'खाली'), t.mutedForeground, muted: true),
            if (showChargeColumn) finCell(context, rows[i].chargeTitle ?? '—', color: t.mutedForeground),
            if (hasDue) finCell(context, rows[i].dueAmount != null ? inrLocale(rows[i].dueAmount!) : '—', mono: true, bold: true),
            switch (rows[i].pendingPayment) {
              'pending' => pill(context.tr('Pending', 'लंबित'), t.warning),
              'rejected' => pill(context.tr('Rejected', 'अस्वीकृत'), t.mutedForeground, muted: true),
              _ => pill(context.fin('fin.status.unpaid'), t.destructive),
            },
          ],
      ],
      footer: [
        finCell(context, ''),
        finCell(
          context,
          rows.length == 1
              ? context.tr('1 unpaid flat', '1 अदत्त फ्लैट')
              : context.tr('${rows.length} unpaid flats', '${rows.length} अदत्त फ्लैट'),
          bold: true,
          maxLines: 1,
        ),
        finCell(context, ''),
        finCell(context, ''),
        if (showChargeColumn) finCell(context, ''),
        if (hasDue) finCell(context, inrLocale(totalDue), mono: true, bold: true),
        finCell(context, ''),
      ],
    );
  }
}

/// Web `FlatMultiSelect`: search + "All visible / Clear visible" + tile grid.
class FlatMultiSelect extends StatefulWidget {
  const FlatMultiSelect({super.key, required this.flats, required this.selected, required this.onChanged, this.label});

  final List<FlatOption> flats;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? label;

  @override
  State<FlatMultiSelect> createState() => _FlatMultiSelectState();
}

class _FlatMultiSelectState extends State<FlatMultiSelect> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _q.trim().toLowerCase();
    final filtered = s.isEmpty
        ? widget.flats
        : widget.flats
            .where((f) => f.flatNumber.toLowerCase().contains(s) || (f.subtitle ?? '').toLowerCase().contains(s))
            .toList();
    final sel = widget.selected.toSet();
    void toggle(String num) {
      widget.onChanged(sel.contains(num) ? widget.selected.where((x) => x != num).toList() : [...widget.selected, num]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.label ?? context.tr('Flats', 'फ्लैट')} (${context.tr('${widget.selected.length} selected', '${widget.selected.length} चयनित')})',
                style: AppText.caption(context).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (filtered.isNotEmpty) ...[
              InkWell(
                onTap: () => widget.onChanged({...widget.selected, ...filtered.map((f) => f.flatNumber)}.toList()),
                child: Text(context.tr('All visible', 'सभी दिखने वाले'),
                    style: TextStyle(fontSize: 11, color: t.primary, decoration: TextDecoration.underline)),
              ),
              Text(' · ', style: AppText.tiny(context)),
              InkWell(
                onTap: () {
                  final nums = filtered.map((f) => f.flatNumber).toSet();
                  widget.onChanged(widget.selected.where((x) => !nums.contains(x)).toList());
                },
                child: Text(context.tr('Clear visible', 'दिखने वाले हटाएँ'),
                    style: TextStyle(fontSize: 11, color: t.mutedForeground, decoration: TextDecoration.underline)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: context.tr('Search flat or resident…', 'फ्लैट या निवासी खोजें…'),
            prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.tr('No flats match your search.', 'खोज से कोई फ्लैट नहीं मिला।'), style: AppText.caption(context)),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: 56,
                  ),
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    final on = sel.contains(f.flatNumber);
                    return Material(
                      color: on ? t.primary : t.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        side: BorderSide(color: on ? t.primary : t.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        onTap: () => toggle(f.flatNumber),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(f.flatNumber,
                                  style: AppText.mono(context, size: 12, weight: FontWeight.w600, color: on ? t.primaryForeground : t.foreground)),
                              if (f.subtitle != null)
                                Text(
                                  f.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, height: 1.15, color: on ? t.primaryForeground : t.mutedForeground),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Web `RecordingDateBanner`.
class RecordingDateBanner extends StatelessWidget {
  const RecordingDateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () => AppFeedback.info(
        context,
        title: context.tr('Recording date', 'दर्ज करने की तिथि'),
        description: context.tr(
          'System entry date when you save (defaults to today). For receipts and payments, set the billing / transaction date in the form — that date drives period reports.',
          'सहेजते समय सिस्टम में प्रविष्टि की तिथि (डिफ़ॉल्ट आज)। रसीदों और भुगतानों के लिए फ़ॉर्म में बिलिंग / लेन-देन तिथि चुनें — अवधि रिपोर्ट उसी तिथि से बनती हैं।',
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.primary, 0.05),
          border: Border.all(color: AppTokens.tint(t.primary, 0.25)),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinMicroLabel(context.tr('Recording date', 'दर्ज करने की तिथि'), padding: EdgeInsets.zero),
                  Text(isoDateToDisplay(todayRecordingDate()),
                      style: AppText.bodyMedium(context).copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            Icon(Icons.info_outline, size: 14, color: t.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// One layer of the head-wise drill-down sheet (web `TransactionHeadModalLayer`).
class FinReportLayer {
  const FinReportLayer({required this.title, this.subtitle, this.total, required this.rows, this.drillable = false});

  final String title;
  final String? subtitle;
  final double? total;
  final List<FinReportRow> rows;
  final bool drillable;
}

/// Web `ReportDetailModal` with back-stack drill-down, search, monthly totals and WhatsApp share.
Future<void> showFinReportSheet(
  BuildContext context, {
  required FinReportLayer initial,
  required String societyName,
  FinReportLayer? Function(BuildContext, FinReportRow)? onDrill,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FinReportSheet(initial: initial, societyName: societyName, onDrill: onDrill),
  );
}

class _FinReportSheet extends StatefulWidget {
  const _FinReportSheet({required this.initial, required this.societyName, this.onDrill});

  final FinReportLayer initial;
  final String societyName;
  final FinReportLayer? Function(BuildContext, FinReportRow)? onDrill;

  @override
  State<_FinReportSheet> createState() => _FinReportSheetState();
}

class _FinReportSheetState extends State<_FinReportSheet> {
  late final List<FinReportLayer> _stack = [widget.initial];
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FinReportRow> _filter(List<FinReportRow> rows) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) {
      final hay = [r.label, r.sublabel ?? '', r.date ?? '', r.status ?? '', r.extra ?? '', r.amount != null ? numToText(r.amount!) : '']
          .join(' ')
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  static String numToText(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _push(FinReportLayer l) => setState(() {
        _stack.add(l);
        _search = '';
        _searchCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final layer = _stack.last;
    final rows = _filter(layer.rows);
    final withAmounts = rows.where((r) => r.amount != null).toList();
    final amountRows = withAmounts.map((r) => AmountRow(amount: r.amount, dateIso: r.dateIso, date: r.date));
    final txTotal = sumAmountRows(amountRows);
    final monthly = monthlyAmountTotals(amountRows);
    final canDrill = layer.drillable && widget.onDrill != null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  if (_stack.length > 1)
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _stack.removeLast())),
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
                  if (layer.total != null)
                    Text(inrLocale(layer.total!), style: AppText.mono(context, size: 13, weight: FontWeight.w700, color: t.primary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (layer.rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
                    hintText: context.tr('Search in this list…', 'इस सूची में खोजें…'),
                  ),
                ),
              ),
            if (_search.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.tr('${rows.length} of ${layer.rows.length} match', '${layer.rows.length} में से ${rows.length} मिले'),
                    style: AppText.tiny(context)),
              ),
            Divider(height: 1, color: t.border),
            Flexible(
              child: layer.rows.isEmpty
                  ? EmptyView(message: context.tr('No data available', 'कोई डेटा उपलब्ध नहीं'))
                  : rows.isEmpty
                      ? EmptyView(message: context.tr('No matches for your search', 'खोज से कुछ नहीं मिला'))
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (ctx, i) {
                            final r = rows[i];
                            return Material(
                              color: AppTokens.tint(t.card, 0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                side: BorderSide(color: AppTokens.tint(t.border, 0.6)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                onTap: canDrill
                                    ? () {
                                        final next = widget.onDrill!(context, r);
                                        if (next != null) _push(next);
                                      }
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.label, style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                                            if ((r.sublabel ?? '').isNotEmpty) Text(r.sublabel!, style: AppText.tiny(context)),
                                            if ((r.date ?? '').isNotEmpty) Text(r.date!, style: AppText.tiny(context)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (r.amount != null)
                                            Text(inrSigned(r.amount!),
                                                style: AppText.mono(context,
                                                    size: 12, weight: FontWeight.w700, color: r.amount! < 0 ? t.destructive : null)),
                                          if ((r.status ?? '').isNotEmpty) FinStatusPill(status: r.status!),
                                          if ((r.extra ?? '').isNotEmpty) Text(r.extra!, style: AppText.tiny(context)),
                                        ],
                                      ),
                                      if (canDrill) Icon(Icons.chevron_right, size: 16, color: t.mutedForeground),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rows.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FinShareButton(
                        label: context.fin('fin.shareWhatsApp'),
                        onShare: () async {
                          final bytes = await buildReportDetailPdf(
                            societyName: widget.societyName,
                            title: layer.title,
                            subtitle: layer.subtitle,
                            totalAmount: layer.total,
                            rows: rows,
                          );
                          await ExportKit.sharePdf(
                            bytes,
                            reportDetailPdfFilename(layer.title),
                            text: [widget.societyName, layer.title, layer.subtitle]
                                .where((v) => (v ?? '').isNotEmpty)
                                .join(' — '),
                          );
                        },
                      ),
                    ),
                  if (withAmounts.isNotEmpty && monthly.isNotEmpty)
                    FinTintBox(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FinMicroLabel(context.tr('Monthly totals', 'मासिक योग')),
                          for (final m in monthly)
                            Row(
                              children: [
                                Expanded(child: Text('${m.label} (${m.count})', style: AppText.caption(context))),
                                Text(inrSigned(m.total),
                                    style: AppText.mono(context, size: 11, weight: FontWeight.w600, color: m.total < 0 ? t.destructive : null)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (withAmounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${context.tr('Transaction total', 'लेन-देन कुल')}: '),
                          TextSpan(
                            text: inrSigned(txTotal),
                            style: AppText.mono(context, size: 12, weight: FontWeight.w700, color: txTotal < 0 ? t.destructive : t.primary),
                          ),
                        ]),
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${context.tr('${rows.length} record(s)', '${rows.length} रिकॉर्ड')}'
                      '${_search.trim().isNotEmpty && rows.length != layer.rows.length ? ' (${context.tr('of', 'में से')} ${layer.rows.length})' : ''}'
                      '${canDrill ? ' · ${context.tr('Tap a row for entry detail', 'विवरण के लिए पंक्ति टैप करें')}' : ''}',
                      textAlign: TextAlign.center,
                      style: AppText.tiny(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
