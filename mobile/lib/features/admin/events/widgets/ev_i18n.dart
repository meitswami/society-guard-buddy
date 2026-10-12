import 'package:flutter/widgets.dart';

import '../../../../core/i18n/extra/events_strings.dart';
import '../../../../core/i18n/i18n.dart';

/// Strings of the Events & food / splitter / donations screens.
///
/// Looks the key up in [kEventsStrings] first (works before the lead merges the map into
/// `kExtraStrings`), then falls back to the app translator (web keys such as `common.cancel`).
extension EventsI18nX on BuildContext {
  String ev(String key, [Map<String, Object?>? vars]) {
    final row = kEventsStrings[key];
    if (row == null) return t(key, vars);
    final code = lang == AppLang.hi ? 'hi' : 'en';
    final v = row[code];
    final raw = (v != null && v.trim().isNotEmpty) ? v : (row['en'] ?? key);
    return applyVars(raw, vars);
  }
}
