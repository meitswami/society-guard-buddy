import 'dart:convert';

import '../../../core/prefs/app_prefs.dart';
import '../logic/kiosk_settings.dart';

/// Device-local kiosk settings (web `readKioskSettings` / `writeKioskSettings`, same
/// `kiosk-settings-v1` JSON key as the web localStorage entry).
abstract final class KioskSettingsStore {
  static KioskSettings read() {
    try {
      final raw = AppPrefs.instance.getString(kKioskSettingsKey);
      if (raw == null || raw.isEmpty) return kDefaultKioskSettings;
      return KioskSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return kDefaultKioskSettings;
    }
  }

  static Future<void> write(KioskSettings s) async {
    try {
      await AppPrefs.instance.setString(kKioskSettingsKey, jsonEncode(s.toJson()));
    } catch (_) {
      // Storage unavailable — settings stay for this session only (as on the web).
    }
  }
}
