import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/platform_branding.dart';

class BrandingService {
  Future<PlatformBranding> fetchPlatformBranding() async {
    if (!Env.isConfigured) return PlatformBranding.defaults();

    try {
      final row = await SupabaseBootstrap.client
          .from('platform_branding')
          .select(
            'app_name, tagline, logo_url, primary_color, primary_dark_color, background_color',
          )
          .eq('id', 'default')
          .maybeSingle();

      if (row == null) return PlatformBranding.defaults();
      return PlatformBranding.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return PlatformBranding.defaults();
    }
  }
}
