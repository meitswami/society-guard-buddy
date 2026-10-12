import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import 'external_views.dart';

enum GuardPreviewVariant { inline, fullscreen }

/// Port of web `GuardLoginPreview`: guard desk tiles (sign-in required) + Tour.
class GuardLoginPreview extends StatelessWidget {
  const GuardLoginPreview({super.key, this.variant = GuardPreviewVariant.inline, this.onClose});

  final GuardPreviewVariant variant;
  final VoidCallback? onClose;

  static const _tiles = <(String, IconData)>[
    ('nav.home', Icons.dashboard_outlined),
    ('nav.quick', Icons.bolt_outlined),
    ('nav.visitor', Icons.person_add_alt_1_outlined),
    ('nav.delivery', Icons.local_shipping_outlined),
    ('nav.vehicles', Icons.directions_car_outlined),
    ('nav.directory', Icons.contact_page_outlined),
  ];

  /// Full-screen preview (web `variant="fullscreen"`).
  static Future<void> openFullscreen(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => GuardLoginPreview(variant: GuardPreviewVariant.fullscreen, onClose: () => Navigator.pop(ctx)),
        ),
      );

  static Future<void> _openTour(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(ctx.t('guard.preview.tourTitle'), style: AppText.sectionTitle(ctx)),
              shape: Border(bottom: BorderSide(color: ctx.tokens.border)),
              actions: [
                IconButton(
                  tooltip: ctx.t('guard.preview.close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            body: buildGuardPreviewTour(),
          ),
        ),
      );

  Widget _grid(BuildContext context) {
    final t = context.tokens;
    Widget tile({required IconData icon, required String label, required VoidCallback onTap, bool tour = false}) => CardSection(
          padding: const EdgeInsets.all(10),
          borderColor: tour ? AppTokens.tint(t.primary, 0.3) : null,
          color: tour ? Color.alphaBlend(AppTokens.tint(t.primary, 0.05), t.card) : null,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: t.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: tour ? FontWeight.w500 : FontWeight.w400,
                    color: tour ? t.primary : t.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('guard.preview.title'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground)),
        const SizedBox(height: 2),
        Text(context.t('guard.preview.hint'), style: AppText.tiny(context).copyWith(height: 1.35)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (key, icon) in _tiles)
              tile(icon: icon, label: context.t(key), onTap: () => AppFeedback.toast(context, context.t('guard.preview.signInToUse'))),
            tile(icon: Icons.auto_awesome, label: context.t('nav.tour'), tour: true, onTap: () => _openTour(context)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (variant == GuardPreviewVariant.fullscreen) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.t('guard.preview.title'), style: AppText.sectionTitle(context)),
          shape: Border(bottom: BorderSide(color: context.tokens.border)),
          actions: [
            if (onClose != null)
              IconButton(tooltip: context.t('guard.preview.close'), icon: const Icon(Icons.close), onPressed: onClose),
          ],
        ),
        body: PageContainer(children: [_grid(context)]),
      );
    }
    return CardSection(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      child: _grid(context),
    );
  }
}
