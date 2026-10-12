import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/ui/ui.dart';

/// Page heading with the web bell square + unread counter (`NotificationCenter` header).
class BadgedPageHeader extends StatelessWidget {
  const BadgedPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.badge = 0,
    this.iconColor,
    this.trailing,
    this.iconSize = 40,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final int badge;
  final Color? iconColor;
  final Widget? trailing;
  final double iconSize;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = iconColor ?? t.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(color: AppTokens.tint(color, 0.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: iconSize / 2, color: color),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.destructive, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(fontSize: 10, color: t.destructiveForeground, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.pageTitle(context).copyWith(color: titleColor)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: AppText.caption(context))),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Web `rounded-lg border border-border bg-muted/30 p-3`.
class MutedBox extends StatelessWidget {
  const MutedBox({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.color, this.borderColor});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTokens.tint(t.muted, 0.5),
        border: Border.all(color: borderColor ?? t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: child,
    );
  }
}

/// Small bordered pill button (web file `<label>` buttons / underline links).
class OutlinePill extends StatelessWidget {
  const OutlinePill({super.key, required this.label, required this.onTap, this.icon, this.color, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.foreground;
    return Material(
      color: AppTokens.tint(t.muted, 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm), side: BorderSide(color: t.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (busy || icon != null) const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text link (web `text-xs underline`).
class LinkText extends StatelessWidget {
  const LinkText(this.label, {super.key, required this.onTap, this.color, this.icon});

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
            Text(label,
                style: TextStyle(fontSize: 12, color: c, decoration: TextDecoration.underline, decorationColor: c)),
          ],
        ),
      ),
    );
  }
}

/// Removable chip for a pending file (web `rounded-full bg-primary/10 text-primary`).
class FileChip extends StatelessWidget {
  const FileChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: t.primary)),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 12, color: t.primary)),
          ),
        ],
      ),
    );
  }
}

/// Copies text to the clipboard; false when the platform refused.
Future<bool> copyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}

Uint8List _compress(({Uint8List bytes, int maxSide, int quality}) a) {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) return a.bytes;
  final ratio = [a.maxSide / decoded.width, a.maxSide / decoded.height, 1.0].reduce((x, y) => x < y ? x : y);
  final resized = ratio < 1
      ? img.copyResize(decoded, width: (decoded.width * ratio).round(), height: (decoded.height * ratio).round())
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: a.quality));
}

/// Web `PhotoCapture` `compressImage`: max 800 px, JPEG quality 0.7 (off the UI thread).
Future<Uint8List> compressPhoto(Uint8List bytes, {int maxSide = 800, int quality = 70}) =>
    compute(_compress, (bytes: bytes, maxSide: maxSide, quality: quality));

/// Upper-cases input (web `e.target.value.toUpperCase()` on IFSC).
class UpperCaseInputFormatter extends TextInputFormatter {
  const UpperCaseInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Standard sheet scaffold for web dialogs: handle-less, padded, keyboard aware.
Future<T?> showCommsSheet<T>(BuildContext context, {required WidgetBuilder builder, bool fullHeight = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: !fullHeight,
    backgroundColor: context.tokens.card,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: fullHeight
          ? SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.92, child: builder(ctx))
          : builder(ctx),
    ),
  );
}
