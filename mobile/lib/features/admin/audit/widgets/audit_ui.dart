import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../logic/js_compat.dart';

/// Small building blocks shared by the audit panels (web Tailwind snippets).

extension AuditCtxX on BuildContext {
  bool get isHi => lang == AppLang.hi;

  /// Web key (society overrides / extra strings) with an inline fallback until the key is registered.
  String tk(String key, String en, String hi) {
    final v = t(key);
    return v == key ? tr(en, hi) : v;
  }
}

enum Tone { primary, info, warning, success, destructive, neutral }

Color toneColor(BuildContext c, Tone tone) {
  final t = c.tokens;
  return switch (tone) {
    Tone.primary => t.primary,
    Tone.info => t.accent,
    Tone.warning => t.warning,
    Tone.success => t.success,
    Tone.destructive => t.destructive,
    Tone.neutral => t.mutedForeground,
  };
}

/// `card-section border-x/40 bg-x/5`.
class ToneCard extends StatelessWidget {
  const ToneCard({super.key, required this.tone, required this.child, this.padding = const EdgeInsets.all(12), this.onTap, this.faded = false});

  final Tone tone;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final c = toneColor(context, tone);
    final card = CardSection(
      padding: padding,
      onTap: onTap,
      borderColor: AppTokens.tint(c, 0.4),
      color: Color.alphaBlend(AppTokens.tint(c, 0.05), context.tokens.card),
      child: child,
    );
    return faded ? Opacity(opacity: 0.6, child: card) : card;
  }
}

/// `bg-background border border-border rounded-lg p-3` inner row box.
class InnerBox extends StatelessWidget {
  const InnerBox({super.key, required this.child, this.borderColor, this.padding = const EdgeInsets.all(12), this.color});

  final Widget child;
  final Color? borderColor;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.background,
        border: Border.all(color: borderColor ?? t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: child,
    );
  }
}

/// Panel heading: 32px tinted icon square + `text-sm font-semibold` title + 10px subtitle.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.icon, required this.title, this.subtitle, this.tone = Tone.primary, this.trailing, this.titleColor});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Tone tone;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final c = toneColor(context, tone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppTokens.tint(c, 0.1), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Icon(icon, size: 16, color: c),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sectionTitle(context).copyWith(color: titleColor)),
              if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: AppText.tiny(context)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

enum SmallBtnStyle { primary, outline, destructive, success, warning, secondary }

/// `text-[10px]/text-xs px-2 py-1.5 rounded-lg` action buttons.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, required this.onPressed, this.icon, this.style = SmallBtnStyle.outline, this.busy = false, this.expand = false, this.fontSize = 11});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SmallBtnStyle style;
  final bool busy;
  final bool expand;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (Color bg, Color fg, Color? border) = switch (style) {
      SmallBtnStyle.primary => (t.primary, t.primaryForeground, null),
      SmallBtnStyle.outline => (Colors.transparent, t.foreground, t.border),
      SmallBtnStyle.destructive => (AppTokens.tint(t.destructive, 0.1), t.destructive, null),
      SmallBtnStyle.success => (t.success, t.successForeground, null),
      SmallBtnStyle.warning => (t.warning, t.warningForeground, null),
      SmallBtnStyle.secondary => (t.secondary, t.secondaryForeground, null),
    };
    final disabled = onPressed == null || busy;
    return Opacity(
      opacity: disabled && !busy ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
                else if (icon != null)
                  Icon(icon, size: 13, color: fg),
                if (busy || icon != null) const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square icon action (`p-2 rounded-lg`).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.onPressed, this.tone, this.tooltip, this.busy = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final Tone? tone;
  final String? tooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = tone == null ? t.secondaryForeground : toneColor(context, tone!);
    final bg = tone == null ? t.secondary : AppTokens.tint(c, 0.1);
    final btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: busy
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6, color: c))
              : Icon(icon, size: 15, color: c),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// `text-[10px] px-1.5 py-0.5 rounded(-full)` chip.
class TinyChip extends StatelessWidget {
  const TinyChip(this.label, {super.key, this.tone = Tone.neutral, this.mono = false, this.icon, this.pill = true, this.bold = false});

  final String label;
  final Tone tone;
  final bool mono;
  final IconData? icon;
  final bool pill;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = toneColor(context, tone);
    final bg = tone == Tone.neutral ? t.muted : AppTokens.tint(c, 0.12);
    final style = mono
        ? AppText.mono(context, size: 10, color: c)
        : TextStyle(fontSize: 10, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(pill ? 999 : 4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10, color: c), const SizedBox(width: 3)],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// `bg-muted/50 rounded-lg p-2 text-[10px] font-mono` key/value block.
class RawDataBox extends StatelessWidget {
  const RawDataBox({super.key, required this.data, this.indent, this.maxHeight});

  final Map<String, Object?> data;
  final String? indent;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in data.entries)
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${e.key}: ', style: AppText.mono(context, size: 10, color: t.mutedForeground)),
              TextSpan(text: jsRawValue(e.value, indent: indent), style: AppText.mono(context, size: 10)),
            ]),
          ),
      ],
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.5), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: maxHeight == null
          ? content
          : ConstrainedBox(constraints: BoxConstraints(maxHeight: maxHeight!), child: SingleChildScrollView(child: content)),
    );
  }
}

/// Uppercase 10px section label with an optional icon.
class TinyLabel extends StatelessWidget {
  const TinyLabel(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.mutedForeground;
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Flexible(
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: c)),
        ),
      ],
    );
  }
}

/// Compact text input used inside panels (`input-field text-sm`).
class PanelInput extends StatelessWidget {
  const PanelInput({super.key, required this.controller, this.hint, this.keyboardType, this.mono = false, this.onChanged, this.prefixIcon, this.maxLength});

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool mono;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hint: hint,
      keyboardType: keyboardType,
      mono: mono,
      caps: false,
      onChanged: onChanged,
      prefixIcon: prefixIcon,
      maxLength: maxLength,
    );
  }
}
