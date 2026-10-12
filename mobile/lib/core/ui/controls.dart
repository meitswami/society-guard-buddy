import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';
import '../theme/app_tokens.dart';
import 'layout.dart';

enum AppButtonVariant { primary, secondary, accent, destructive, success, ghost }

/// Web `.btn-primary` / `.btn-secondary` and the accent / destructive variants.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.dense = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.dense = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.dense = false,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (t.primary, t.primaryForeground, null),
      AppButtonVariant.secondary => (t.secondary, t.secondaryForeground, t.border),
      AppButtonVariant.accent => (t.accent, t.accentForeground, null),
      AppButtonVariant.destructive => (t.destructive, t.destructiveForeground, null),
      AppButtonVariant.success => (t.success, t.successForeground, null),
      AppButtonVariant.ghost => (Colors.transparent, t.primary, null),
    };
    final disabled = onPressed == null || loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 16, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 12 : 14,
              fontWeight: variant == AppButtonVariant.secondary ? FontWeight.w500 : FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
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
            padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 8 : 13),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Selectable pill (web purpose / filter buttons: `bg-primary` when active, `bg-secondary` otherwise).
class PillChoice extends StatelessWidget {
  const PillChoice({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primary : t.secondary,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? t.primaryForeground : t.secondaryForeground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? t.primaryForeground : t.secondaryForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrap of [PillChoice]s for single selection.
class PillChoiceGroup<T> extends StatelessWidget {
  const PillChoiceGroup({super.key, required this.options, required this.value, required this.onChanged, required this.labelOf});

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options) PillChoice(label: labelOf(o), selected: o == value, onTap: () => onChanged(o)),
      ],
    );
  }
}

/// Segmented control used for Today / Yesterday style toggles and tab switches.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({super.key, required this.options, required this.value, required this.onChanged, required this.labelOf});

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: t.secondary, borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: o == value ? t.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labelOf(o),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: o == value ? t.primaryForeground : t.secondaryForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Web `.input-field` with the uppercase label above it.
/// Respects the "CAPS entry" setting for plain text fields (like web `normalizeEntryValue`).
class AppTextField extends ConsumerWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.obscure = false,
    this.required = false,
    this.caps = true,
    this.mono = false,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool obscure;
  final bool required;
  /// Upper-case input when the CAPS entry setting is on (ignored for numbers, phones, emails, passwords).
  final bool caps;
  final bool mono;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;

  bool get _capsExemptType {
    final k = keyboardType;
    return obscure ||
        k == TextInputType.number ||
        k == TextInputType.phone ||
        k == TextInputType.emailAddress ||
        k == TextInputType.url ||
        k == TextInputType.datetime ||
        (k != null && k.index == TextInputType.number.index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final capsOn = caps && !_capsExemptType && ref.watch(entryCapsProvider);
    final formatters = <TextInputFormatter>[
      if (capsOn) const _UpperCaseFormatter(),
      ...?inputFormatters,
    ];
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      obscureText: obscure,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      autofocus: autofocus,
      focusNode: focusNode,
      textCapitalization: capsOn ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: formatters,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: mono ? AppText.mono(context, size: 14) : TextStyle(fontSize: 14, color: t.foreground),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18, color: t.mutedForeground),
        suffixIcon: suffix,
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [FieldLabel(label!, required: required), field],
    );
  }
}

/// Web `<select class="input-field">`.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.label,
    this.hint,
    this.required = false,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String Function(T) labelOf;
  final String? label;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = DropdownButtonFormField<T>(
      // Keyed on the value so the field stays controlled by the parent.
      key: ValueKey<Object?>(value),
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      onChanged: onChanged,
      hint: hint == null ? null : Text(hint!, style: TextStyle(color: t.mutedForeground, fontSize: 14)),
      dropdownColor: t.card,
      style: TextStyle(fontSize: 14, color: t.foreground),
      items: [
        for (final i in items)
          DropdownMenuItem<T>(value: i, child: Text(labelOf(i), overflow: TextOverflow.ellipsis)),
      ],
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [FieldLabel(label!, required: required), field],
    );
  }
}

/// Web toggle row: `w-10 h-6` pill switch + label.
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.label, required this.value, required this.onChanged, this.subtitle});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body(context)),
                  if (subtitle != null) Text(subtitle!, style: AppText.tiny(context)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

enum BadgeTone { inside, exited, alert, warning, info, neutral, success }

/// Web `.status-badge` (`status-inside`, `status-exited`, `status-alert`, …).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (tone) {
      BadgeTone.inside || BadgeTone.success => (AppTokens.tint(t.success, 0.2), t.success),
      BadgeTone.exited || BadgeTone.neutral => (t.muted, t.mutedForeground),
      BadgeTone.alert => (AppTokens.tint(t.destructive, 0.2), t.destructive),
      BadgeTone.warning => (AppTokens.tint(t.warning, 0.2), t.warning),
      BadgeTone.info => (AppTokens.tint(t.primary, 0.15), t.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Coloured alert box (web `card-section border-destructive/50` / warning banners).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, this.tone = BadgeTone.warning, this.icon, this.action});

  final String message;
  final BadgeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = switch (tone) {
      BadgeTone.alert => t.destructive,
      BadgeTone.success || BadgeTone.inside => t.success,
      BadgeTone.info => t.primary,
      BadgeTone.warning => t.warning,
      _ => t.mutedForeground,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.tint(c, 0.06),
        border: Border.all(color: AppTokens.tint(c, 0.4)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.warning_amber_rounded, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c))),
          if (action != null) action!,
        ],
      ),
    );
  }
}
