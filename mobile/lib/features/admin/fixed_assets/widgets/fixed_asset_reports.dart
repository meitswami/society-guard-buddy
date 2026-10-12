import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../audit/data/audit_service.dart' show auditErrText;
import '../../audit/widgets/audit_ui.dart';
import '../export/fixed_asset_export.dart';
import '../logic/fixed_asset_types.dart';

/// Port of `FixedAssetReports.tsx`: summary cards, by-sub-head / by-source tables, export menu.
class FixedAssetReports extends StatefulWidget {
  const FixedAssetReports(
      {super.key,
      required this.societyId,
      required this.societyName,
      required this.assets});

  final String societyId;
  final String societyName;
  final List<FixedAsset> assets;

  @override
  State<FixedAssetReports> createState() => _FixedAssetReportsState();
}

class _FixedAssetReportsState extends State<FixedAssetReports> {
  bool _exporting = false;

  Future<void> _export(ExportFormat f) async {
    setState(() => _exporting = true);
    try {
      await exportFixedAssetReport(
          societyId: widget.societyId,
          societyName: widget.societyName,
          assets: widget.assets,
          format: f);
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, auditErrText(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = computeFixedAssetReport(widget.assets);
    final hi = context.isHi;
    final disabled = widget.assets.isEmpty || _exporting;

    Widget card(String title, String hiTitle, String value, String desc,
            String hiDesc, String cap, String hiCap) =>
        DescriptiveStatCard(
          title: context.tr(title, hiTitle),
          value: value,
          description: context.tr(desc, hiDesc),
          caption: context.tr(cap, hiCap),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.bar_chart, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  context.tr('Fixed assets report', 'स्थिर संपत्ति रिपोर्ट'),
                  style: AppText.sectionTitle(context))),
          PopupMenuButton<ExportFormat>(
            enabled: !disabled,
            onSelected: _export,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: ExportFormat.pdf,
                  child: _menuRow(Icons.description_outlined, 'PDF')),
              PopupMenuItem(
                  value: ExportFormat.excel,
                  child: _menuRow(Icons.grid_on_outlined, 'Excel (.xlsx)')),
              PopupMenuItem(
                  value: ExportFormat.word,
                  child: _menuRow(Icons.article_outlined, 'Word (.doc)')),
              PopupMenuItem(
                  value: ExportFormat.csv,
                  child: _menuRow(Icons.download_outlined, 'CSV')),
            ],
            child: IgnorePointer(
              child: SmallButton(
                label: context.tr('Export', 'निर्यात'),
                icon: Icons.download_outlined,
                style: SmallBtnStyle.secondary,
                busy: _exporting,
                fontSize: 12,
                onPressed: disabled ? null : () {},
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        StatGrid(spacing: 8, children: [
          card(
              'Total assets',
              'कुल संपत्तियाँ',
              '${s.totalAssets}',
              'All items in the fixed assets register.',
              'स्थिर संपत्ति रजिस्टर की सभी मदें।',
              'All registered items',
              'सभी पंजीकृत मदें'),
          card(
              'Active',
              'सक्रिय',
              '${s.activeCount}',
              'Assets currently in use or under repair.',
              'वर्तमान में उपयोग में या मरम्मत में संपत्तियाँ।',
              'In use or under repair',
              'उपयोग में या मरम्मत में'),
          card(
              'Total value',
              'कुल मूल्य',
              moneyInr(s.totalBillValue),
              'Sum of bill values for non-disposed assets.',
              'न निपटाई गई संपत्तियों के बिल मूल्यों का योग।',
              'Bill value of active assets',
              'सक्रिय संपत्तियों का बिल मूल्य'),
          card(
              'Not acquired',
              'प्राप्त नहीं',
              '${s.placeholderCount}',
              'Standard templates awaiting builder handover details.',
              'बिल्डर हस्तांतरण विवरण की प्रतीक्षा में मानक टेम्पलेट।',
              'Builder templates pending',
              'बिल्डर टेम्पलेट लंबित'),
          card(
              'Warranty alert',
              'वारंटी अलर्ट',
              '${s.warrantyExpiringSoon}',
              'Assets whose warranty ends within the next 60 days.',
              'जिन संपत्तियों की वारंटी अगले 60 दिनों में समाप्त होगी।',
              'Expiring within 60 days',
              '60 दिनों में समाप्त'),
          card(
              'AMC alert',
              'AMC अलर्ट',
              '${s.amcExpiringSoon}',
              'Assets whose AMC contract ends within the next 60 days.',
              'जिन संपत्तियों का AMC अनुबंध अगले 60 दिनों में समाप्त होगा।',
              'Expiring within 60 days',
              '60 दिनों में समाप्त'),
        ]),
        if (s.bySubHead.isNotEmpty) ...[
          const SizedBox(height: 16),
          FieldLabel(context.tr('By sub-head', 'उप-शीर्ष अनुसार')),
          _table(context.tr('Sub-head', 'उप-शीर्ष'),
              [for (final r in s.bySubHead) (r.subHead, r.count, r.value)]),
        ],
        if (s.bySource.isNotEmpty) ...[
          const SizedBox(height: 16),
          FieldLabel(context.tr('By source', 'स्रोत अनुसार')),
          _table(context.tr('Source', 'स्रोत'), [
            for (final r in s.bySource)
              (
                hi ? fixedAssetSourceLabel(r.key, hi: true) : r.source,
                r.count,
                r.value
              )
          ]),
        ],
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13))
      ]);

  Widget _table(String firstHeader, List<(String, int, double)> rows) {
    final t = context.tokens;
    TextStyle head = const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    Widget cell(String s,
            {bool right = false, bool mono = false, TextStyle? style}) =>
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(s,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: style ??
                  (mono
                      ? AppText.mono(context, size: 12)
                      : const TextStyle(fontSize: 12))),
        );
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(2)
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
                color: AppTokens.tint(t.muted, 0.5),
                border: Border(bottom: BorderSide(color: t.border))),
            children: [
              cell(firstHeader, style: head),
              cell(context.tr('Count', 'संख्या'), right: true, style: head),
              cell(context.tr('Value', 'मूल्य'), right: true, style: head),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: i == rows.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: AppTokens.tint(t.border, 0.6)))),
              children: [
                cell(rows[i].$1),
                cell('${rows[i].$2}', right: true),
                cell(moneyInr(rows[i].$3), right: true, mono: true)
              ],
            ),
        ],
      ),
    );
  }
}
