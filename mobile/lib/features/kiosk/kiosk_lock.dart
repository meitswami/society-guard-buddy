import 'package:flutter/foundation.dart';

/// True while the AI kiosk is running (web `setKioskLocked` / `isKioskLocked`).
/// The running kiosk is its own full-screen route that blocks Android back, but a
/// shell with its own back handling (e.g. "back → dashboard") should also check this.
final ValueNotifier<bool> kioskLockedListenable = ValueNotifier<bool>(false);

bool isKioskLocked() => kioskLockedListenable.value;

void setKioskLocked(bool on) => kioskLockedListenable.value = on;
