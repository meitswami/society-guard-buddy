import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/session_models.dart';
import '../../../providers/session_provider.dart';
import '../../../services/admin_permissions.dart';
import 'tour_guide.dart';
import 'tour_guide_overlay.dart';

/// Port of web `TourGuideFirstLogin`: the short first-time tour shown once per
/// role + user id (finishing or skipping marks it done, like `persistOnSkip`).
///
/// Call from a role shell after its first frame:
/// `WidgetsBinding.instance.addPostFrameCallback((_) => TourGuideFirstLogin.maybeShow(context, role: 'guard', userId: id));`
abstract final class TourGuideFirstLogin {
  static final Set<String> _showing = {};

  static Future<void> maybeShow(BuildContext context,
      {required String role, required String userId}) async {
    if (userId.isEmpty) return;
    final key = tourStorageKey(role, userId);
    if (_showing.contains(key)) return;
    if (await TourGuideStore.isCompleted(role, userId)) return;
    if (!context.mounted) return;
    _showing.add(key);
    try {
      var perms = AdminPanelPermissions.full;
      try {
        final s = ProviderScope.containerOf(context, listen: false)
            .read(sessionProvider)
            .valueOrNull;
        if (s is SessionAdmin) perms = s.admin.permissions;
      } catch (_) {}
      final persist = await TourGuideOverlay.show(context,
          steps: getFirstLoginSteps(role, perms), persistOnSkip: true);
      if (persist) await TourGuideStore.markCompleted(role, userId);
    } finally {
      _showing.remove(key);
    }
  }
}
