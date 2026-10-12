import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// `members.photo` / roster photos: data URLs or http(s) URLs.
ImageProvider? govPhotoProvider(String? photo) {
  final p = photo?.trim() ?? '';
  if (p.isEmpty) return null;
  if (p.startsWith('data:image')) {
    final comma = p.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(p.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  if (p.startsWith('http://') || p.startsWith('https://')) {
    return CachedNetworkImageProvider(p);
  }
  return null;
}

/// Data URL for an image (`data:image/jpeg;base64,…`), like the web FileReader result.
String imageDataUrl(Uint8List bytes, {String mime = 'image/jpeg'}) =>
    'data:$mime;base64,${base64Encode(bytes)}';

enum AvatarSize { xs, sm, md, lg, xl }

double _avatarPx(AvatarSize s) => switch (s) {
      AvatarSize.xs => 28,
      AvatarSize.sm => 36,
      AvatarSize.md => 40,
      AvatarSize.lg => 56,
      AvatarSize.xl => 64,
    };

/// Web `PersonAvatar`: circular face photo with an initial fallback.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(
      {super.key, required this.name, this.photo, this.size = AvatarSize.md});

  final String name;
  final String? photo;
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final px = _avatarPx(size);
    final provider = govPhotoProvider(photo);
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: px,
      height: px,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.tint(t.primary, 0.10),
        border: Border.all(color: AppTokens.tint(t.border, 0.9)),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: provider == null
          ? Text(initial,
              style: TextStyle(
                  color: t.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: px * 0.36))
          : null,
    );
  }
}

/// Web `PersonPhotoSide`: photo seated beside a name/detail block.
class PersonPhotoSide extends StatelessWidget {
  const PersonPhotoSide(
      {super.key,
      required this.name,
      this.photo,
      this.size = AvatarSize.md,
      required this.child});

  final String name;
  final String? photo;
  final AvatarSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonAvatar(name: name, photo: photo, size: size),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// Rounded, tinted, bordered box (web `rounded-lg border border-x/30 bg-x/5 p-3`).
class TintBox extends StatelessWidget {
  const TintBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(12),
    this.fill = 0.05,
    this.border = 0.3,
    this.radius = AppTokens.radiusSm,
    this.margin,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double fill;
  final double border;
  final double radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTokens.tint(c, fill),
        border: Border.all(color: AppTokens.tint(c, border)),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Bordered section block with an uppercase caption (web `border border-border rounded-lg p-3`).
class SectionBox extends StatelessWidget {
  const SectionBox({
    super.key,
    this.title,
    this.icon,
    required this.children,
    this.dashed = false,
    this.trailing,
    this.background,
  });

  final String? title;
  final IconData? icon;
  final List<Widget> children;
  final bool dashed;
  final Widget? trailing;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: t.mutedForeground),
                  const SizedBox(width: 4)
                ],
                Expanded(
                    child: Text(title!.toUpperCase(),
                        style: AppText.fieldLabel(context))),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ...children,
      ],
    );
    final decoration = BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      border: dashed ? null : Border.all(color: t.border),
    );
    final box = Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration,
        child: content);
    if (!dashed) return box;
    return CustomPaint(
        painter:
            _DashedRectPainter(color: t.border, radius: AppTokens.radiusSm),
        child: box);
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}

enum MiniVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  success,
  accent,
  warning
}

/// Small dense button (web `Button size="sm"` / `h-7 text-[10px]`).
class MiniButton extends StatelessWidget {
  const MiniButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = MiniVariant.outline,
    this.busy = false,
    this.fontSize = 12,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MiniVariant variant;
  final bool busy;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      MiniVariant.primary => (t.primary, t.primaryForeground, null),
      MiniVariant.secondary => (t.secondary, t.secondaryForeground, null),
      MiniVariant.outline => (t.card, t.foreground, t.border),
      MiniVariant.ghost => (Colors.transparent, t.foreground, null),
      MiniVariant.destructive => (t.destructive, t.destructiveForeground, null),
      MiniVariant.success => (t.success, t.successForeground, null),
      MiniVariant.accent => (t.accent, t.accentForeground, null),
      MiniVariant.warning => (t.warning, t.warningForeground, null),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: fg))
                else if (icon != null)
                  Icon(icon, size: fontSize + 2, color: fg),
                if (busy || icon != null) const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlined text link (web `text-xs text-primary underline`).
class LinkText extends StatelessWidget {
  const LinkText(this.text,
      {super.key, required this.onTap, this.color, this.fontSize = 12});

  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: onTap == null ? AppTokens.tint(c, 0.5) : c,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: c,
          ),
        ),
      ),
    );
  }
}

/// Checkbox + label row (web `<label><input type="checkbox"/> …</label>`).
class CheckRow extends StatelessWidget {
  const CheckRow(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label,
      this.subtitle,
      this.dense = true});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 2 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: value,
                onChanged:
                    onChanged == null ? null : (v) => onChanged!(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13, color: context.tokens.foreground)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable field that opens a picker (date / time / date-time).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.text,
    required this.onTap,
    this.onClear,
    this.icon = Icons.calendar_today_outlined,
    this.hint,
    this.helper,
    this.required = false,
  });

  final String? label;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData icon;
  final String? hint;
  final String? helper;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = Material(
      color: t.input,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: t.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isEmpty ? (hint ?? '') : text,
                  style: TextStyle(
                      fontSize: 14,
                      color: text.isEmpty ? t.mutedForeground : t.foreground),
                ),
              ),
              if (onClear != null && text.isNotEmpty)
                InkWell(
                    onTap: onClear,
                    child:
                        Icon(Icons.close, size: 16, color: t.mutedForeground)),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FieldLabel(label!, required: required),
        field,
        if (helper != null)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(helper!, style: AppText.tiny(context))),
      ],
    );
  }
}

/// Date input — shows `dd/MM/yyyy`, emits `yyyy-MM-dd` (web `DateInput`).
class GovDateField extends StatelessWidget {
  const GovDateField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.helper,
    this.clearable = true,
  });

  final String? label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool required;
  final String? helper;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      text: value.isEmpty ? '' : Fmt.isoToDisplay(value),
      hint: 'dd/mm/yyyy',
      helper: helper,
      required: required,
      onClear: clearable ? () => onChanged('') : null,
      onTap: () async {
        final current = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(1990),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(Fmt.isoDate(picked));
      },
    );
  }
}

/// Time input — emits `HH:mm`.
class GovTimeField extends StatelessWidget {
  const GovTimeField(
      {super.key,
      this.label,
      required this.value,
      required this.onChanged,
      this.required = false});

  final String? label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final tod = parts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 9, minute: 0);
    return _PickerField(
      label: label,
      text: value.isEmpty ? '' : tod.format(context),
      hint: '--:--',
      icon: Icons.schedule,
      required: required,
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: tod);
        if (picked != null) {
          onChanged(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
    );
  }
}

/// Date + time input (web `datetime-local`); null when empty.
class GovDateTimeField extends StatelessWidget {
  const GovDateTimeField(
      {super.key, this.label, required this.value, required this.onChanged});

  final String? label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      text: value == null ? '' : Fmt.dateTime(value),
      hint: 'dd/mm/yyyy --:--',
      icon: Icons.event,
      onClear: () => onChanged(null),
      onTap: () async {
        final base = value ?? DateTime.now();
        final day = await showDatePicker(
          context: context,
          initialDate: base,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (day == null || !context.mounted) return;
        final time = await showTimePicker(
            context: context, initialTime: TimeOfDay.fromDateTime(base));
        if (time == null) return;
        onChanged(
            DateTime(day.year, day.month, day.day, time.hour, time.minute));
      },
    );
  }
}

/// Small rounded badge (web `text-[10px] uppercase px-1.5 py-0.5 rounded`).
class TinyTag extends StatelessWidget {
  const TinyTag(this.text,
      {super.key, this.color, this.filled = true, this.uppercase = true});

  final String text;
  final Color? color;
  final bool filled;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? AppTokens.tint(c, color == null ? 0.12 : 0.15) : null,
        borderRadius: BorderRadius.circular(4),
        border: filled ? null : Border.all(color: t.border),
      ),
      child: Text(
        uppercase ? text.toUpperCase() : text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: c),
      ),
    );
  }
}

/// Bottom sheet scaffold used for web dialogs (title, description, body, footer).
Future<T?> showGovSheet<T>(
  BuildContext context, {
  required String title,
  String? description,
  required Widget Function(BuildContext sheetContext, StateSetter setSheetState)
      builder,
  List<Widget> Function(BuildContext sheetContext, StateSetter setSheetState)?
      footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.tokens.card,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppText.pageTitle(ctx)
                                    .copyWith(fontSize: 17)),
                            if (description != null) ...[
                              const SizedBox(height: 4),
                              Text(description, style: AppText.caption(ctx)),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close,
                            color: ctx.tokens.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: builder(ctx, setSheetState),
                  ),
                ),
                if (footer != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    decoration: BoxDecoration(
                        border:
                            Border(top: BorderSide(color: ctx.tokens.border))),
                    child: Row(
                      children: [
                        for (final (i, w)
                            in footer(ctx, setSheetState).indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: w),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Toast helpers matching web sonner calls.
abstract final class GovToast {
  static void ok(BuildContext context, String message) =>
      AppFeedback.toast(context, message, tone: BadgeTone.success);

  static void error(BuildContext context, String message) =>
      AppFeedback.toast(context, message, tone: BadgeTone.alert);

  static void info(BuildContext context, String message) =>
      AppFeedback.toast(context, message);
}

/// Web `confirmAction(title, text, confirm, cancel)`.
Future<bool> govConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) =>
    AppFeedback.confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: context.tr('Cancel', 'रद्द करें'),
      destructive: destructive,
    );
