import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'feedback.dart';
import 'layout.dart';

/// Web `DescriptiveStatCard`: value + caption; tap opens the description sheet,
/// optional "navigate" action (e.g. filter a list).
class DescriptiveStatCard extends StatelessWidget {
  const DescriptiveStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    this.caption,
    this.howCalculated,
    this.icon,
    this.iconColor,
    this.valueColor,
    this.onNavigate,
    this.navigateLabel,
    this.highlighted = false,
    this.borderColor,
    this.compact = false,
  });

  final String title;
  final String value;
  final String description;
  final String? caption;
  final String? howCalculated;
  final IconData? icon;
  final Color? iconColor;
  final Color? valueColor;
  final VoidCallback? onNavigate;
  final String? navigateLabel;
  /// Web `ring-2 ring-primary` when the card's filter is active.
  final bool highlighted;
  final Color? borderColor;
  /// `variant="stat"`: smaller mono value with an uppercase caption above.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radius + 2),
              border: Border.all(color: t.primary, width: 2),
            )
          : null,
      child: CardSection(
        borderColor: borderColor,
        padding: EdgeInsets.all(compact ? 12 : 16),
        onTap: () => AppFeedback.info(
          context,
          title: title,
          description: description,
          howCalculated: howCalculated,
          navigateLabel: navigateLabel,
          onNavigate: onNavigate,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 16, color: iconColor ?? t.mutedForeground),
                const Spacer(),
                Icon(Icons.info_outline, size: 14, color: t.mutedForeground),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),
            if (compact) ...[
              Text((caption ?? title).toUpperCase(), style: AppText.tiny(context)),
              Text(value, style: AppText.mono(context, size: 17, weight: FontWeight.w700, color: valueColor)),
            ] else ...[
              Text(value, style: AppText.statValue(context, color: valueColor)),
              Text(caption ?? title, style: AppText.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of stat cards (web `grid grid-cols-2 gap-3`).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.columns = 2, this.spacing = 12});

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final idx = i + j;
        cells.add(Expanded(child: idx < children.length ? children[idx] : const SizedBox()));
        if (j < columns - 1) cells.add(SizedBox(width: spacing));
      }
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
      if (i + columns < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}

/// Simple label/value row used in detail cards and summaries.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.valueStyle, this.mono = false});

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: AppText.caption(context))),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: valueStyle ?? (mono ? AppText.mono(context, size: 13) : AppText.bodyMedium(context)),
            ),
          ),
        ],
      ),
    );
  }
}
