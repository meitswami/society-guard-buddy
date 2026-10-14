import 'package:flutter/widgets.dart';

import '../../../core/i18n/extra/kiosk_strings.dart';
import '../../../core/i18n/i18n.dart';

/// `context.t(key)` with a fallback to [kKioskStrings] until the lead merges the
/// kiosk map into `kExtraStrings` (keys never render raw).
String kioskT(BuildContext context, String key, [Map<String, Object?>? vars]) {
  final v = context.t(key, vars);
  if (v != key) return v;
  final row = kKioskStrings[key];
  if (row == null) return key;
  final text = context.lang == AppLang.hi ? (row['hi'] ?? row['en'] ?? key) : (row['en'] ?? key);
  return applyVars(text, vars);
}
