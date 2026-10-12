import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import 'tour_guide.dart';

/// Web localStorage `sgb.tour.v1.done:*` → SharedPreferences (same key).
abstract final class TourGuideStore {
  static Future<bool> isCompleted(AppTourRole role, String userId) async {
    if (userId.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tourStorageKey(role, userId)) == '1';
    } catch (_) {
      return true;
    }
  }

  static Future<void> markCompleted(AppTourRole role, String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tourStorageKey(role, userId), '1');
    } catch (_) {}
  }
}

/// Lucide → Material icons for the tour (web `ICON_MAP`).
IconData tourIconData(TourIcon i) => switch (i) {
      TourIcon.sparkles => Icons.auto_awesome,
      TourIcon.layoutDashboard => Icons.dashboard_outlined,
      TourIcon.zap => Icons.bolt,
      TourIcon.userPlus => Icons.person_add_alt_1_outlined,
      TourIcon.truck => Icons.local_shipping_outlined,
      TourIcon.car => Icons.directions_car_outlined,
      TourIcon.shieldAlert => Icons.gpp_maybe_outlined,
      TourIcon.bookUser => Icons.contacts_outlined,
      TourIcon.settings => Icons.settings_outlined,
      TourIcon.home => Icons.home_outlined,
      TourIcon.bell => Icons.notifications_none,
      TourIcon.keyRound => Icons.key_outlined,
      TourIcon.users => Icons.groups_outlined,
      TourIcon.dollar => Icons.currency_rupee,
      TourIcon.vote => Icons.how_to_vote_outlined,
      TourIcon.user => Icons.person_outline,
      TourIcon.shield => Icons.shield_outlined,
      TourIcon.mapPin => Icons.location_on_outlined,
      TourIcon.fingerprint => Icons.fingerprint,
      TourIcon.clipboard => Icons.assignment_outlined,
      TourIcon.barChart => Icons.bar_chart,
      TourIcon.fileText => Icons.description_outlined,
      TourIcon.crown => Icons.workspace_premium_outlined,
      TourIcon.building => Icons.apartment_outlined,
      TourIcon.tag => Icons.sell_outlined,
      TourIcon.database => Icons.storage_outlined,
      TourIcon.heart => Icons.favorite_border,
      TourIcon.calendar => Icons.calendar_month_outlined,
      TourIcon.parking => Icons.local_parking_outlined,
      TourIcon.split => Icons.call_split,
    };

/// Port of web `TourGuideOverlay`: blurred full-screen card, step counter, icon, title,
/// body, progress dots, Skip / Next / Done. Tapping outside (or back) counts as Skip.
abstract final class TourGuideOverlay {
  /// Resolves to true when the tour should be marked done (finished, or skipped with
  /// [persistOnSkip]) — web `onFinished`.
  static Future<bool> show(
    BuildContext context, {
    required List<TourStepSpec> steps,
    int initialIndex = 0,
    bool persistOnSkip = false,
  }) async {
    if (steps.isEmpty) return false;
    final finished = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: context.ct('comms.tour.close'),
      barrierColor: AppTokens.tint(context.tokens.background, 0.75),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => _TourCard(
          steps: steps,
          initialIndex: clampTourIndex(initialIndex, steps.length)),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.0).animate(anim), child: child),
      ),
    );
    // null = closed with the back button → treated like Skip.
    return tourShouldPersist(
        skipped: finished != true, persistOnSkip: persistOnSkip);
  }
}

class _TourCard extends StatefulWidget {
  const _TourCard({required this.steps, required this.initialIndex});

  final List<TourStepSpec> steps;
  final int initialIndex;

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard> {
  late int _index = widget.initialIndex;

  void _finish(bool skipped) => Navigator.of(context).pop(!skipped);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final step = widget.steps[_index];
    final last = widget.steps.length - 1;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _finish(true),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.expand()),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Material(
                color: t.card,
                elevation: 12,
                shadowColor: AppTokens.tint(t.primary, 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                  side: BorderSide(color: AppTokens.tint(t.primary, 0.25)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      right: -64,
                      top: -64,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTokens.tint(t.primary, 0.12)),
                      ),
                    ),
                    Positioned(
                      left: -40,
                      bottom: -48,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTokens.tint(t.accent, 0.10)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppTokens.tint(t.primary, 0.1),
                                    borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                    context.t('tour.badge').toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: t.primary)),
                              ),
                              const Spacer(),
                              Text('${_index + 1} / ${widget.steps.length}',
                                  style: AppText.caption(context).copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  AppTokens.tint(t.primary, 0.2),
                                  AppTokens.tint(t.accent, 0.1)
                                ]),
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusXl),
                                border: Border.all(
                                    color: AppTokens.tint(t.primary, 0.2)),
                              ),
                              child: Icon(tourIconData(step.icon),
                                  size: 40, color: t.primary),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(context.t(step.titleKey),
                              textAlign: TextAlign.center,
                              style: AppText.pageTitle(context).copyWith(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(context.t(step.bodyKey),
                              textAlign: TextAlign.center,
                              style: AppText.body(context).copyWith(
                                  color: t.mutedForeground, height: 1.5)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < widget.steps.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  height: 6,
                                  width: i == _index ? 24 : 6,
                                  decoration: BoxDecoration(
                                    color: i == _index
                                        ? t.primary
                                        : AppTokens.tint(
                                            t.mutedForeground, 0.3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(height: 1, color: t.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _finish(true),
                                child: Text(context.t('tour.skip'),
                                    style: TextStyle(color: t.mutedForeground)),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                expand: false,
                                label: _index < last
                                    ? context.t('tour.next')
                                    : context.t('tour.done'),
                                onPressed: () => _index < last
                                    ? setState(() => _index++)
                                    : _finish(false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
