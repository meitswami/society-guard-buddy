import 'package:flutter/widgets.dart';

import '../../core/i18n/extra/superadmin_strings.dart';
import '../../core/i18n/i18n.dart';

/// Superadmin copy: web keys via `context.t`, and the module's own `sa.*` keys from
/// [kSuperadminStrings] (works before and after the lead merges the map into
/// `kExtraStrings`).
extension SuperadminText on BuildContext {
  String st(String key, [Map<String, Object?>? vars]) {
    final v = t(key, vars);
    if (v != key) return v;
    final row = kSuperadminStrings[key];
    if (row == null) return key;
    final raw = (lang == AppLang.hi ? row['hi'] : row['en']) ?? row['en'] ?? key;
    return applyVars(raw.isEmpty ? (row['en'] ?? key) : raw, vars);
  }
}
