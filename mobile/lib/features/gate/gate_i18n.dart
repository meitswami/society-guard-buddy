import 'package:flutter/widgets.dart';

import '../../core/i18n/extra/gate_strings.dart';
import '../../core/i18n/i18n.dart';

extension GateI18nX on BuildContext {
  /// Translates a `gate.*` key: shared translator first (society overrides, merged extras),
  /// then [kGateStrings] directly so the module works before the lead merges the file.
  String gt(String key, [Map<String, Object?>? vars]) {
    final v = t(key, vars);
    if (v != key) return v;
    final row = kGateStrings[key];
    if (row == null) return key;
    final text =
        (lang == AppLang.hi ? row['hi'] : row['en']) ?? row['en'] ?? key;
    return applyVars(text, vars);
  }
}
