import 'package:flutter/widgets.dart';

import '../../../core/i18n/extra/resident_strings.dart';
import '../../../core/i18n/i18n.dart';

extension ResidentStringsX on BuildContext {
  /// `context.t(key)` that also resolves `kResidentStrings` before the lead merges them
  /// into `kExtraStrings`.
  String rt(String key, [Map<String, Object?>? vars]) {
    final v = t(key, vars);
    if (v != key) return v;
    final row = kResidentStrings[key];
    if (row == null) return key;
    final text = (lang == AppLang.hi ? row['hi'] : row['en']) ?? row['en'] ?? key;
    return applyVars(text, vars);
  }
}
