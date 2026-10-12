/// Kiosk options chosen by the guard — port of web `src/lib/kiosk/kioskSettings.ts`.
/// Stored as JSON under the same key as the web localStorage entry (`kiosk-settings-v1`).
library;

import 'kiosk_copy.dart';

/// Storage key (same as the web `localStorage` key).
const String kKioskSettingsKey = 'kiosk-settings-v1';

class KioskSettings {
  const KioskSettings({
    this.defaultLang = KioskLang.hi,
    this.requireApproval = true,
    this.useCloudAi = true,
    this.capturePhoto = true,
    this.askVehicle = true,
    this.exitPin = '',
  });

  final KioskLang defaultLang;

  /// Ask the flat's resident to approve before saving the entry.
  final bool requireApproval;

  /// Use the `kiosk-assistant` Edge Function (Claude) when local parsing is unsure.
  final bool useCloudAi;

  /// Save a camera snapshot with the entry.
  final bool capturePhoto;

  /// Ask about vehicles.
  final bool askVehicle;

  /// When set, leaving the kiosk asks for this PIN.
  final String exitPin;

  KioskSettings copyWith({
    KioskLang? defaultLang,
    bool? requireApproval,
    bool? useCloudAi,
    bool? capturePhoto,
    bool? askVehicle,
    String? exitPin,
  }) =>
      KioskSettings(
        defaultLang: defaultLang ?? this.defaultLang,
        requireApproval: requireApproval ?? this.requireApproval,
        useCloudAi: useCloudAi ?? this.useCloudAi,
        capturePhoto: capturePhoto ?? this.capturePhoto,
        askVehicle: askVehicle ?? this.askVehicle,
        exitPin: exitPin ?? this.exitPin,
      );

  Map<String, Object> toJson() => {
        'defaultLang': defaultLang.id,
        'requireApproval': requireApproval,
        'useCloudAi': useCloudAi,
        'capturePhoto': capturePhoto,
        'askVehicle': askVehicle,
        'exitPin': exitPin,
      };

  /// `{ ...DEFAULT_KIOSK_SETTINGS, ...parsed }` — missing or malformed values keep the default.
  factory KioskSettings.fromJson(Object? json) {
    if (json is! Map) return kDefaultKioskSettings;
    const d = kDefaultKioskSettings;
    bool flag(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    final pin = json['exitPin'];
    return KioskSettings(
      defaultLang: KioskLang.fromId(json['defaultLang']) ?? d.defaultLang,
      requireApproval: flag('requireApproval', d.requireApproval),
      useCloudAi: flag('useCloudAi', d.useCloudAi),
      capturePhoto: flag('capturePhoto', d.capturePhoto),
      askVehicle: flag('askVehicle', d.askVehicle),
      exitPin: pin is String ? pin : (pin is num ? '$pin' : d.exitPin),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KioskSettings &&
      other.defaultLang == defaultLang &&
      other.requireApproval == requireApproval &&
      other.useCloudAi == useCloudAi &&
      other.capturePhoto == capturePhoto &&
      other.askVehicle == askVehicle &&
      other.exitPin == exitPin;

  @override
  int get hashCode => Object.hash(defaultLang, requireApproval, useCloudAi, capturePhoto, askVehicle, exitPin);
}

/// Web `DEFAULT_KIOSK_SETTINGS`.
const KioskSettings kDefaultKioskSettings = KioskSettings();
