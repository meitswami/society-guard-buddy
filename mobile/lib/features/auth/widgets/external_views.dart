import 'package:flutter/widgets.dart';

import '../../comms/tour/tour_guide_hub_view.dart';

/// Cross-module views used by the login screens, kept in one place so a missing sibling
/// module only affects this file. Guard tour = COMMS `TourGuideHubView` (web `TourGuideHub
/// role="guard"` opened from the guard login preview; no user yet, so `userId` is empty).
Widget buildGuardPreviewTour() => const TourGuideHubView(role: 'guard', userId: '');
