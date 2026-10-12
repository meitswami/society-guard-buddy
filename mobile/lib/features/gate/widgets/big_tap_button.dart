import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/guard_duty_types.dart';

/// (border, fill, foreground) of a duty tone — web `BigTapButton` variants / `statusColor`.
({Color border, Color fill, Color fg}) dutyToneColors(
    BuildContext context, DutyTone tone,
    {double fillOpacity = 0.15}) {
  final t = context.tokens;
  return switch (tone) {
    DutyTone.success => (
        border: t.success,
        fill: AppTokens.tint(t.success, fillOpacity),
        fg: t.success
      ),
    DutyTone.warning => (
        border: t.warning,
        fill: AppTokens.tint(t.warning, fillOpacity),
        fg: t.warning
      ),
    DutyTone.danger => (
        border: t.destructive,
        fill: AppTokens.tint(t.destructive, fillOpacity),
        fg: t.destructive
      ),
    DutyTone.muted => (
        border: t.border,
        fill: AppTokens.tint(t.muted, 0.4),
        fg: t.mutedForeground
      ),
    DutyTone.primary => (
        border: t.primary,
        fill: AppTokens.tint(t.primary, fillOpacity),
        fg: t.primary
      ),
    DutyTone.none => (border: t.border, fill: t.card, fg: t.foreground),
  };
}

/// Large touch target with emoji + label (web `src/components/guardDuty/BigTapButton.tsx`).
class BigTapButton extends StatelessWidget {
  const BigTapButton({
    super.key,
    required this.label,
    this.subLabel,
    this.icon,
    required this.selected,
    this.tone = DutyTone.primary,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final String? subLabel;

  /// Emoji shown above the label.
  final String? icon;
  final bool selected;
  final DutyTone tone;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = dutyToneColors(context, selected ? tone : DutyTone.none);
    final radius = BorderRadius.circular(AppTokens.radius);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: c.fill,
        shape: RoundedRectangleBorder(
            borderRadius: radius, side: BorderSide(color: c.border, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Text(icon!,
                        style: const TextStyle(fontSize: 22, height: 1)),
                  if (icon != null) const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: c.fg),
                  ),
                  if (subLabel != null)
                    Text(subLabel!,
                        textAlign: TextAlign.center,
                        style: AppText.tiny(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preset chip used in the duty dialogs (`border-primary bg-primary/15` when picked).
class PresetChip extends StatelessWidget {
  const PresetChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.mono = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(AppTokens.radiusSm);
    return Material(
      color: selected ? AppTokens.tint(t.primary, 0.15) : t.card,
      shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? t.primary : t.border)),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            label,
            style: mono
                ? AppText.mono(context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? t.primary : t.foreground)
                : TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? t.primary : t.foreground),
          ),
        ),
      ),
    );
  }
}

/// Equal-width grid of [children] (web `grid grid-cols-N gap-2`).
class TapGrid extends StatelessWidget {
  const TapGrid(
      {super.key,
      required this.columns,
      required this.children,
      this.spacing = 8});

  final int columns;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final idx = i + j;
        cells.add(Expanded(
            child: idx < children.length ? children[idx] : const SizedBox()));
        if (j < columns - 1) cells.add(SizedBox(width: spacing));
      }
      rows.add(IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells)));
      if (i + columns < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
