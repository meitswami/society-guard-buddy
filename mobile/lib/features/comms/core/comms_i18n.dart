import 'package:flutter/widgets.dart';

import '../../../core/i18n/extra/comms_strings.dart';
import '../../../core/i18n/i18n.dart';

/// Resolves COMMS-only strings (`comms.*`, from [kCommsStrings]) in the current language,
/// falling back to the shared translator for web keys. Works before and after the lead
/// merges [kCommsStrings] into `kExtraStrings`.
extension CommsI18n on BuildContext {
  String ct(String key, [Map<String, Object?>? vars]) {
    final row = kCommsStrings[key];
    if (row == null) return t(key, vars);
    final l = lang == AppLang.hi ? 'hi' : 'en';
    final v = row[l];
    final raw = (v == null || v.isEmpty) ? (row['en'] ?? key) : v;
    return applyVars(raw, vars);
  }
}
