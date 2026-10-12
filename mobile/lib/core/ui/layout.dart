import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Web `.page-container`: centred column, max width 512 (`max-w-lg`), 16px gutters,
/// extra bottom padding so content clears the bottom navigation.
class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 96),
    this.onRefresh,
    this.controller,
    this.maxWidth = 512,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: context.tokens.primary, child: list);
  }
}

/// Web page heading: tinted rounded icon square + `.page-title` + muted subtitle, optional actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions = const [],
    this.onBack,
    this.bottomSpacing = 20,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = iconColor ?? t.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconPillButton(icon: Icons.arrow_back, onPressed: onBack!),
            const SizedBox(width: 10),
          ],
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTokens.tint(color, 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.pageTitle(context)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: AppText.caption(context)),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Web `.card-section`: card background, 12px radius, 1px border, 16px padding.
class CardSection extends StatelessWidget {
  const CardSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(AppTokens.radius);
    final box = Material(
      color: color ?? t.card,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor ?? t.border)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return margin == null ? box : Padding(padding: margin!, child: box);
  }
}

/// Section heading inside a page (`text-sm font-semibold`).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon, this.iconColor, this.trailing, this.padding = const EdgeInsets.only(bottom: 8)});

  final String text;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: iconColor ?? t.primary), const SizedBox(width: 6)],
          Expanded(child: Text(text, style: AppText.sectionTitle(context))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small uppercase field label used above inputs on the web.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('${text.toUpperCase()}${required ? ' *' : ''}', style: AppText.fieldLabel(context)),
    );
  }
}

/// Square icon button on a `bg-secondary` pill (web header buttons, e.g. logout).
class IconPillButton extends StatelessWidget {
  const IconPillButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.color, this.background});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final btn = Material(
      color: background ?? t.secondary,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onPressed,
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 16, color: color ?? t.mutedForeground)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Text styles matching the web Tailwind classes.
abstract final class AppText {
  /// `.page-title` (text-xl font-bold tracking-tight)
  static TextStyle pageTitle(BuildContext c) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.tokens.foreground);

  /// `text-sm font-semibold`
  static TextStyle sectionTitle(BuildContext c) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.tokens.foreground);

  /// `text-sm`
  static TextStyle body(BuildContext c) => TextStyle(fontSize: 14, color: c.tokens.foreground);

  /// `text-sm font-medium`
  static TextStyle bodyMedium(BuildContext c) => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.tokens.foreground);

  /// `text-xs text-muted-foreground`
  static TextStyle caption(BuildContext c) => TextStyle(fontSize: 12, color: c.tokens.mutedForeground);

  /// `text-[10px] text-muted-foreground`
  static TextStyle tiny(BuildContext c) => TextStyle(fontSize: 10, color: c.tokens.mutedForeground);

  /// `text-xs font-medium text-muted-foreground uppercase tracking-wider`
  static TextStyle fieldLabel(BuildContext c) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: c.tokens.mutedForeground);

  /// `font-mono`
  static TextStyle mono(BuildContext c, {double size = 13, FontWeight weight = FontWeight.w400, Color? color}) =>
      TextStyle(fontFamily: 'JetBrainsMono', fontSize: size, fontWeight: weight, color: color ?? c.tokens.foreground);

  /// Big numbers on stat cards (`text-2xl font-bold tabular-nums`).
  static TextStyle statValue(BuildContext c, {Color? color}) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? c.tokens.foreground,
      );
}
