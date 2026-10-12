import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import 'ev_i18n.dart';

/// Small building blocks that mirror the Tailwind snippets used by the web events screens.

/// `rounded-lg border border-border bg-muted/20 p-2` panel.
class EvPanel extends StatelessWidget {
  const EvPanel({super.key, required this.children, this.padding = const EdgeInsets.all(8), this.color, this.borderColor, this.spacing = 8});

  final List<Widget> children;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTokens.tint(t.muted, t.isDark ? 0.35 : 0.5),
        border: Border.all(color: borderColor ?? t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _gap(children, spacing),
      ),
    );
  }
}

List<Widget> _gap(List<Widget> children, double spacing) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0 && spacing > 0) out.add(SizedBox(height: spacing));
    out.add(children[i]);
  }
  return out;
}

/// Vertical list with fixed gaps (web `flex flex-col gap-2`).
class EvColumn extends StatelessWidget {
  const EvColumn({super.key, required this.children, this.spacing = 8});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _gap(children, spacing),
      );
}

/// `text-[10px] font-medium text-muted-foreground uppercase`.
class EvTinyLabel extends StatelessWidget {
  const EvTinyLabel(this.text, {super.key, this.icon, this.bold = false, this.upper = true});

  final String text;
  final IconData? icon;
  final bool bold;
  final bool upper;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TextStyle(
      fontSize: 10,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: upper ? 0.4 : 0,
      color: t.mutedForeground,
    );
    final label = Text(upper ? text.toUpperCase() : text, style: style);
    if (icon == null) return label;
    return Row(children: [Icon(icon, size: 12, color: t.mutedForeground), const SizedBox(width: 4), Flexible(child: label)]);
  }
}

/// `text-[10px]/[11px] text-muted-foreground leading-snug` hint.
class EvHint extends StatelessWidget {
  const EvHint(this.text, {super.key, this.size = 10, this.color, this.italic = false, this.align});

  final String text;
  final double size;
  final Color? color;
  final bool italic;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: size,
          height: 1.35,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color ?? context.tokens.mutedForeground,
        ),
      );
}

/// Rich hint with **bold** segments: `'Open an event and tap **Record contribution receipt**.'`.
class EvRichHint extends StatelessWidget {
  const EvRichHint(this.text, {super.key, this.size = 11, this.onLinkTap, this.leading});

  final String text;
  final double size;

  /// Called for segments written as `[[link text]]`.
  final VoidCallback? onLinkTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(fontSize: size, height: 1.4, color: t.mutedForeground);
    final spans = <InlineSpan>[];
    if (leading != null) spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: leading!));
    final re = RegExp(r'\*\*(.+?)\*\*|\[\[(.+?)\]\]');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: TextStyle(fontWeight: FontWeight.w600, color: t.foreground)));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onLinkTap,
              child: Text(
                m.group(2)!,
                style: base.copyWith(
                  color: onLinkTap == null ? t.foreground : t.primary,
                  fontWeight: FontWeight.w600,
                  decoration: onLinkTap == null ? null : TextDecoration.underline,
                  decorationColor: t.primary,
                ),
              ),
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Radio option row (custom indicator, no deprecated Radio API).
class EvRadioRow extends StatelessWidget {
  const EvRadioRow({super.key, required this.label, required this.selected, required this.onTap, this.subtitle});

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? t.primary : t.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(label, style: TextStyle(fontSize: 12, height: 1.3, color: t.foreground)),
                  ),
                  if (subtitle != null) EvHint(subtitle!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Underlined primary link (`text-[10px] text-primary underline`).
class EvLink extends StatelessWidget {
  const EvLink(this.text, {super.key, required this.onTap, this.size = 10, this.icon, this.color});

  final String text;
  final VoidCallback? onTap;
  final double size;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: size + 2, color: c), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size, color: c, decoration: TextDecoration.underline, decorationColor: c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens an attachment / receipt URL in the browser.
Future<void> openEvUrl(BuildContext context, String url) async {
  final ok = await ExportKit.openUrl(url).catchError((_) => false);
  if (!ok && context.mounted) AppFeedback.toast(context, context.ev('evc.openFailed'), tone: BadgeTone.alert);
}

/// `bg-x/10 text-x rounded-lg text-xs` action button.
class EvTintButton extends StatelessWidget {
  const EvTintButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.loading = false,
    this.expand = false,
    this.fontSize = 12,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool loading;
  final bool expand;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return Material(
      color: AppTokens.tint(c, 0.12),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: c))
              else if (icon != null)
                Icon(icon, size: 13, color: c),
              if (loading || icon != null) const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `text-xs px-2.5 py-1.5 rounded-lg border border-border` button.
class EvOutlineButton extends StatelessWidget {
  const EvOutlineButton({super.key, required this.label, required this.onTap, this.icon, this.color, this.fontSize = 12});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.foreground;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        side: BorderSide(color: color ?? t.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
              Flexible(child: Text(label, style: TextStyle(fontSize: fontSize, color: fg, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny `Edit` pill (`text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary`).
class EvMiniChip extends StatelessWidget {
  const EvMiniChip({super.key, required this.label, required this.onTap, this.icon, this.color});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return Material(
      color: AppTokens.tint(c, 0.12),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 3)],
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded status pill (`text-[10px] px-2 py-0.5 rounded-full`).
class EvPill extends StatelessWidget {
  const EvPill(this.text, {super.key, this.color, this.filled = true, this.upper = false, this.fontSize = 10});

  final String text;
  final Color? color;
  final bool filled;
  final bool upper;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c == null ? t.muted : AppTokens.tint(c, 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        upper ? text.toUpperCase() : text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: c ?? t.mutedForeground),
      ),
    );
  }
}

/// `text-xs bg-muted/50 rounded p-2` list row container.
class EvMutedBox extends StatelessWidget {
  const EvMutedBox({super.key, required this.child, this.color, this.dashed = false, this.padding = const EdgeInsets.all(8)});

  final Widget child;
  final Color? color;
  final bool dashed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTokens.tint(t.muted, t.isDark ? 0.6 : 0.7),
        borderRadius: BorderRadius.circular(6),
        border: dashed ? Border.all(color: t.border) : null,
      ),
      child: child,
    );
  }
}

/// Coloured callout (`rounded-lg border border-x/30 bg-x/5 p-2.5`).
class EvCallout extends StatelessWidget {
  const EvCallout({super.key, required this.color, required this.child, this.icon, this.action});

  final Color color;
  final Widget child;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTokens.tint(color, 0.06),
        border: Border.all(color: AppTokens.tint(color, 0.3)),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
          ],
          Expanded(child: child),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Two equal columns (`grid grid-cols-2 gap-2`).
class EvTwoCol extends StatelessWidget {
  const EvTwoCol({super.key, required this.left, required this.right, this.gap = 8});

  final Widget left;
  final Widget right;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: left), SizedBox(width: gap), Expanded(child: right)],
      );
}

/// Web `DescriptiveStatSummary`: one muted line; tap for description / how calculated.
class EvSummaryLine extends StatelessWidget {
  const EvSummaryLine({super.key, required this.label, required this.title, required this.description, this.howCalculated});

  final String label;
  final String title;
  final String description;
  final String? howCalculated;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () => AppFeedback.info(context, title: title, description: description, howCalculated: howCalculated),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 12, color: AppTokens.tint(t.mutedForeground, 0.7)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(fontSize: 10.5, height: 1.4, color: t.mutedForeground))),
          ],
        ),
      ),
    );
  }
}

/// Web `DescriptiveValueButton`: bold value + info icon, tap → description sheet.
class EvValueButton extends StatelessWidget {
  const EvValueButton({
    super.key,
    required this.value,
    required this.title,
    required this.description,
    this.howCalculated,
    this.color,
    this.fontSize = 10,
    this.mono = false,
    this.bold = true,
  });

  final String value;
  final String title;
  final String description;
  final String? howCalculated;
  final Color? color;
  final double fontSize;
  final bool mono;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => AppFeedback.info(context, title: title, description: description, howCalculated: howCalculated),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: mono
                    ? AppText.mono(context, size: fontSize, weight: bold ? FontWeight.w600 : FontWeight.w400, color: color)
                    : TextStyle(
                        fontSize: fontSize,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: color ?? t.foreground,
                      ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.info_outline, size: fontSize + 1, color: AppTokens.tint(t.mutedForeground, 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Section heading used inside the Events module (`text-sm font-semibold` + coloured icon).
class EvSectionHeading extends StatelessWidget {
  const EvSectionHeading({super.key, required this.icon, required this.color, required this.title});

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppText.sectionTitle(context))),
          ],
        ),
      );
}

/// Toast that also shows above modal bottom sheets (sonner-style, root overlay).
void evToast(BuildContext context, String message, {BadgeTone tone = BadgeTone.neutral}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    AppFeedback.toast(context, message, tone: tone);
    return;
  }
  final t = context.tokens;
  final color = switch (tone) {
    BadgeTone.alert => t.destructive,
    BadgeTone.success || BadgeTone.inside => t.success,
    BadgeTone.warning => t.warning,
    _ => t.primary,
  };
  final icon = switch (tone) {
    BadgeTone.alert => Icons.error_outline,
    BadgeTone.success || BadgeTone.inside => Icons.check_circle_outline,
    BadgeTone.warning => Icons.warning_amber,
    _ => Icons.info_outline,
  };
  final top = MediaQuery.paddingOf(context).top + 12;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: t.card,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            side: BorderSide(color: AppTokens.tint(color, 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: t.foreground))),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(milliseconds: 3200), () {
    if (entry.mounted) entry.remove();
  });
}

/// Modal bottom sheet used for the web dialogs (edit modals).
Future<T?> showEvSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tokens.card,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

/// Sheet header: title + optional subtitle + close button.
class EvSheetHeader extends StatelessWidget {
  const EvSheetHeader({super.key, required this.title, this.subtitle, this.onClose});

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sectionTitle(context)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[const SizedBox(height: 2), EvHint(subtitle!)],
              ],
            ),
          ),
          if (onClose != null) EvOutlineButton(label: context.ev('evc.close'), onTap: onClose),
        ],
      ),
    );
  }
}
