import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../resident/data/resident_models.dart';
import '../resident/data/resident_repository.dart';

/// Resident landing content — web `society_dashboard_banners` popup shown once per app
/// session after login (zoom 100–300 %, pinch, previous / next, title, `n/N`).
abstract final class ResidentLoginBanners {
  /// Web `sessionStorage['sgb_seen_banner_<society>']` — per app process here.
  static final Set<String> _seen = {};

  static Future<void> maybeShow(BuildContext context, String societyId) async {
    if (societyId.isEmpty || _seen.contains(societyId)) return;
    List<DashboardBanner> banners;
    try {
      banners = await const ResidentRepository().fetchDashboardBanners(societyId);
    } catch (_) {
      return;
    }
    if (banners.isEmpty || !context.mounted) return;
    _seen.add(societyId);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _BannerDialog(banners: banners),
    );
  }
}

class _BannerDialog extends StatefulWidget {
  const _BannerDialog({required this.banners});

  final List<DashboardBanner> banners;

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  final _zoom = TransformationController();
  int _idx = 0;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final s = _zoom.value.getMaxScaleOnAxis();
      if ((s - _scale).abs() > 0.01 && mounted) setState(() => _scale = s);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _setScale(double s) {
    final v = s.clamp(1.0, 3.0);
    _zoom.value = Matrix4.diagonal3Values(v, v, 1);
  }

  void _go(int delta) {
    setState(() => _idx = (_idx + delta + widget.banners.length) % widget.banners.length);
    _setScale(1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = widget.banners[_idx];
    final many = widget.banners.length > 1;
    final overlay = Colors.black.withValues(alpha: 0.4);
    const onOverlay = Colors.white;
    Widget chip(Widget child) => Container(
          decoration: BoxDecoration(color: overlay, borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: child,
        );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      backgroundColor: t.card,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Stack(children: [
            Container(
              color: t.muted,
              width: double.infinity,
              child: InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: 3,
                child: CachedNetworkImage(
                  imageUrl: b.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(height: 240, child: LoadingView()),
                  errorWidget: (_, __, ___) => SizedBox(height: 200, child: Icon(Icons.broken_image_outlined, color: t.mutedForeground)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: chip(TextButton(
                style: TextButton.styleFrom(foregroundColor: onOverlay, visualDensity: VisualDensity.compact),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t('mobile.close'), style: const TextStyle(fontSize: 12)),
              )),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: chip(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 16, color: onOverlay),
                  onPressed: () => _setScale(((_scale - 0.25) * 100).round() / 100),
                ),
                Text('${(_scale * 100).round()}%', style: const TextStyle(fontSize: 10, color: onOverlay)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 16, color: onOverlay),
                  onPressed: () => _setScale(((_scale + 0.25) * 100).round() / 100),
                ),
              ])),
            ),
            if (many) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CircleAvatar(
                    backgroundColor: overlay,
                    child: IconButton(icon: const Icon(Icons.chevron_left, color: onOverlay), onPressed: () => _go(-1)),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CircleAvatar(
                    backgroundColor: overlay,
                    child: IconButton(icon: const Icon(Icons.chevron_right, color: onOverlay), onPressed: () => _go(1)),
                  ),
                ),
              ),
            ],
          ]),
        ),
        if ((b.title ?? '').isNotEmpty || many)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text(b.title ?? ' ', style: AppText.bodyMedium(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (many) Text('${_idx + 1}/${widget.banners.length}', style: AppText.tiny(context)),
            ]),
          ),
      ]),
    );
  }
}
