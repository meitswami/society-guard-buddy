import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../utils/member_photo.dart';
import 'directory_models.dart';
import 'person_avatar.dart';

/// Small rectangular tag (`text-[10px] px-1.5 py-0.5 rounded`), e.g. "Wing A", "Vacant", "My Flat".
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.color, this.background, this.fontSize = 10});

  final String label;
  final Color? color;
  final Color? background;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: background ?? t.secondary, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: fontSize, color: color ?? t.secondaryForeground, height: 1.2)),
    );
  }

  /// `bg-warning/20 text-warning`.
  factory TagChip.warning(BuildContext context, String label) {
    final t = context.tokens;
    return TagChip(label, color: t.warning, background: AppTokens.tint(t.warning, 0.2));
  }

  /// `bg-primary/20 text-primary`.
  factory TagChip.primary(BuildContext context, String label, {double fontSize = 9}) {
    final t = context.tokens;
    return TagChip(label, color: t.primary, background: AppTokens.tint(t.primary, 0.2), fontSize: fontSize);
  }
}

/// `text-[10px] uppercase tracking-wider text-muted-foreground font-medium`.
class TinyLabel extends StatelessWidget {
  const TinyLabel(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.mutedForeground;
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: c),
    );
    if (icon == null) return label;
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: c), const SizedBox(width: 5), Flexible(child: label)]);
  }
}

/// "Floor: 1st Floor" pair (`text-xs`, muted label + medium value).
class InfoPair extends StatelessWidget {
  const InfoPair(this.label, this.value, {super.key, this.mono = false, this.valueColor, this.onTap});

  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label: ', style: TextStyle(fontSize: 12, color: t.mutedForeground)),
        TextSpan(
          text: value,
          style: mono
              ? AppText.mono(context, size: 12, weight: FontWeight.w600, color: valueColor)
              : TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor ?? t.foreground),
        ),
      ]),
    );
    if (onTap == null) return text;
    return InkWell(onTap: onTap, child: text);
  }
}

/// Two-column grid of small widgets (`grid grid-cols-2 gap-2 text-xs`).
class TwoColGrid extends StatelessWidget {
  const TwoColGrid({super.key, required this.children, this.fullWidth = const {}, this.spacing = 8});

  final List<Widget> children;

  /// Indexes that span both columns (`col-span-2`).
  final Set<int> fullWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var i = 0;
    while (i < children.length) {
      if (fullWidth.contains(i)) {
        rows.add(children[i]);
        i++;
      } else if (i + 1 < children.length && !fullWidth.contains(i + 1)) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: children[i]), SizedBox(width: spacing), Expanded(child: children[i + 1])],
        ));
        i += 2;
      } else {
        rows.add(Row(children: [Expanded(child: children[i]), SizedBox(width: spacing), const Spacer()]));
        i++;
      }
      if (i < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Matching people (with photos) on a flat row while searching — max 4 + "+N".
class NameHitChips extends StatelessWidget {
  const NameHitChips({super.key, required this.members, this.showOverflow = true});

  final List<PeopleMember> members;
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final m in members.take(4))
            Container(
              padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
              decoration: BoxDecoration(color: AppTokens.tint(t.secondary, 0.7), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PersonAvatar(name: m.name, photo: m.photo, size: PersonAvatarSize.xs),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      m.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.foreground),
                    ),
                  ),
                ],
              ),
            ),
          if (showOverflow && members.length > 4) Text('+${members.length - 4}', style: AppText.tiny(context)),
        ],
      ),
    );
  }
}

/// Vehicle pill (`Car icon · number (type)`).
class VehicleChip extends StatelessWidget {
  const VehicleChip({super.key, required this.number, this.type});

  final String number;
  final String? type;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppTokens.tint(t.secondary, 0.5), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 12, color: t.mutedForeground),
          const SizedBox(width: 4),
          Text(number, style: AppText.mono(context, size: 12, weight: FontWeight.w600)),
          if (type != null && type!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text('(${_cap(type!)})', style: AppText.tiny(context)),
          ],
        ],
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Rounded image thumbnail for http(s) or `data:image` sources (`object-cover rounded border`).
class ImageThumb extends StatelessWidget {
  const ImageThumb({super.key, required this.src, this.width = 56, this.height = 36, this.onTap, this.radius = 4});

  final String src;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = memberPhotoProvider(src);
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.muted,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: provider == null
          ? Icon(Icons.image_not_supported_outlined, size: 16, color: t.mutedForeground)
          : Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, size: 16, color: t.mutedForeground),
            ),
    );
    return GestureDetector(onTap: onTap ?? () => PhotoViewer.show(context, src), child: box);
  }
}

/// Full-screen enlarged photo (web lightbox: black backdrop, close button, pinch-zoom).
/// PDFs open in the external viewer.
abstract final class PhotoViewer {
  static bool _isPdf(String url) =>
      RegExp(r'\.pdf($|\?)', caseSensitive: false).hasMatch(url) || url.toLowerCase().contains('application/pdf');

  static Future<void> show(BuildContext context, String src) async {
    if (_isPdf(src) && !src.startsWith('data:')) {
      await ExportKit.openUrl(src);
      return;
    }
    final provider = memberPhotoProvider(src);
    if (provider == null) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'photo',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (ctx, _, __) => SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image(image: provider, fit: BoxFit.contain)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lazily built page (header widgets + long list) with the `.page-container` look:
/// max width 512, 16px gutters, bottom padding for the nav, pull-to-refresh.
class LazyListPage extends StatelessWidget {
  const LazyListPage({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.onRefresh,
    this.footer = const [],
    this.spacing = 8,
    this.controller,
  });

  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function()? onRefresh;
  final List<Widget> footer;
  final double spacing;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = math.max(16.0, (c.maxWidth - 512) / 2 + 16);
      final view = CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 16, side, 0),
            sliver: SliverList(delegate: SliverChildListDelegate(header)),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: SliverList.separated(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              separatorBuilder: (_, __) => SizedBox(height: spacing),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 96),
            sliver: SliverList(delegate: SliverChildListDelegate(footer)),
          ),
        ],
      );
      if (onRefresh == null) return view;
      return RefreshIndicator(onRefresh: onRefresh!, color: context.tokens.primary, child: view);
    });
  }
}

/// Search box with a leading search icon (web `input-field pl-9`).
class DirectorySearchField extends StatelessWidget {
  const DirectorySearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 14, color: t.foreground),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 16, color: t.mutedForeground),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

/// Square tinted icon button (`p-1` / `p-2 rounded-lg bg-x/10 text-x`).
class TintIconButton extends StatelessWidget {
  const TintIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
    this.size = 16,
    this.padding = 8,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;
  final double padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.primary;
    final btn = Material(
      color: filled ? AppTokens.tint(c, 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onPressed,
        child: Padding(padding: EdgeInsets.all(padding), child: Icon(icon, size: size, color: onPressed == null ? AppTokens.tint(c, 0.4) : c)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
