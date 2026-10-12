import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../../providers/session_provider.dart';
import '../../../services/admin_permissions.dart';
import 'tour_guide.dart';
import 'tour_guide_overlay.dart';

/// Port of web `TourGuideHub`: hero card + one card per chapter; tapping a chapter steps
/// through it in [TourGuideOverlay]. Admin chapters follow the admin's role permissions.
class TourGuideHubView extends ConsumerWidget {
  const TourGuideHubView({super.key, required this.role, required this.userId});

  /// `guard` | `resident` | `admin` | `superadmin`
  final String role;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final session = ref.watch(sessionProvider).valueOrNull;
    final perms = session is SessionAdmin
        ? session.admin.permissions
        : AdminPanelPermissions.full;
    final chapters = getTourChapters(role, perms);
    return PageContainer(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(color: AppTokens.tint(t.primary, 0.2)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(AppTokens.tint(t.primary, 0.12), t.card),
                t.card,
                Color.alphaBlend(AppTokens.tint(t.accent, 0.10), t.card)
              ],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                  right: 12,
                  top: 12,
                  child: Icon(Icons.auto_awesome,
                      size: 64, color: AppTokens.tint(t.primary, 0.15))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('tour.badge').toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: t.primary)),
                    const SizedBox(height: 4),
                    Text(context.t('tour.hubTitle'),
                        style: AppText.pageTitle(context)),
                    const SizedBox(height: 8),
                    Text(context.t('tour.hubSubtitle'),
                        style: AppText.body(context)
                            .copyWith(color: t.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(context.t('tour.pickTopic').toUpperCase(),
              style: AppText.fieldLabel(context)),
        ),
        for (final ch in chapters)
          CardSection(
            margin: const EdgeInsets.only(bottom: 12),
            onTap: () => TourGuideOverlay.show(context, steps: ch.steps),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTokens.tint(t.primary, 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        border:
                            Border.all(color: AppTokens.tint(t.primary, 0.15)),
                      ),
                      child: Icon(Icons.menu_book_outlined,
                          size: 16, color: t.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: t.muted,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '${ch.steps.length} ${ch.steps.length == 1 ? context.t('tour.step') : context.t('tour.steps')}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: t.mutedForeground),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(context.t(ch.titleKey),
                    style: AppText.sectionTitle(context)),
                const SizedBox(height: 2),
                Text(context.t('tour.tapToView'),
                    style: AppText.caption(context)),
              ],
            ),
          ),
      ],
    );
  }
}
