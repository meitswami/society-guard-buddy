import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_branding.dart';
import '../services/branding_service.dart';

final brandingServiceProvider = Provider<BrandingService>((ref) {
  return BrandingService();
});

final platformBrandingProvider =
    AsyncNotifierProvider<PlatformBrandingNotifier, PlatformBranding>(
  PlatformBrandingNotifier.new,
);

class PlatformBrandingNotifier extends AsyncNotifier<PlatformBranding> {
  @override
  Future<PlatformBranding> build() async {
    return ref.read(brandingServiceProvider).fetchPlatformBranding();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(brandingServiceProvider).fetchPlatformBranding(),
    );
  }
}
