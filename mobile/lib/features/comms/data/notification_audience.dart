/// Port of `src/lib/notificationAudience.ts` plus the type icon / label maps used by
/// `NotificationCenter.tsx`. Pure Dart (unit-tested in `test/comms`).
library;

/// Whether a notification row is visible to a resident (flat / person / society-wide).
///
/// Mirrors the web rules exactly:
/// - `all` → everyone;
/// - `flat` → `target_id` equals the flat, or a comma list contains it;
/// - `user` → `target_id` equals the resident id or name, or a comma list contains either.
bool notificationVisibleToResident({
  required Object? targetType,
  required Object? targetId,
  required String residentId,
  required String residentName,
  required String flatNumber,
}) {
  final type = targetType?.toString() ?? '';
  final id = (targetId?.toString() ?? '').trim();
  if (type == 'all') return true;
  if (type == 'flat') {
    if (id == flatNumber) return true;
    if (id.contains(',')) {
      return id.split(',').map((s) => s.trim()).contains(flatNumber);
    }
  }
  if (type == 'user') {
    if (id == residentId) return true;
    if (id == residentName) return true;
    if (id.contains(',')) {
      final parts = id.split(',').map((s) => s.trim()).toList();
      return parts.contains(residentId) || parts.contains(residentName);
    }
  }
  return false;
}

/// Same as [notificationVisibleToResident] for a raw `notifications` row.
bool notificationRowVisibleToResident(
  Map<String, dynamic> row, {
  required String residentId,
  required String residentName,
  required String flatNumber,
}) =>
    notificationVisibleToResident(
      targetType: row['target_type'],
      targetId: row['target_id'],
      residentId: residentId,
      residentName: residentName,
      flatNumber: flatNumber,
    );

/// Web `typeIcons` in `NotificationCenter.tsx` (fallback 📢).
const Map<String, String> kNotificationTypeIcons = {
  'general': '📢',
  'payment_reminder': '💰',
  'event': '🎉',
  'event_reminder': '🔔',
  'poll': '📊',
  'alert': '⚠️',
};

String notificationTypeIcon(String type) =>
    kNotificationTypeIcons[type] ?? '📢';

/// Web `NOTIFICATION_TYPE_LABELS` → comms string keys (fallback "Notice").
const Map<String, String> kNotificationTypeLabelKeys = {
  'general': 'comms.type.notice',
  'payment_reminder': 'comms.type.payment',
  'event': 'comms.type.event',
  'event_reminder': 'comms.type.reminder',
  'poll': 'comms.type.poll',
  'alert': 'comms.type.alert',
};

String notificationTypeLabelKey(String type) =>
    kNotificationTypeLabelKeys[type] ?? 'comms.type.notice';

/// Types the admin can pick in the compose form (web `<select>` order).
const List<String> kComposeNotificationTypes = [
  'general',
  'alert',
  'event',
  'payment_reminder'
];

/// Admin list "→ target" tag: `Flat 101` for flat rows, the stored names for person rows.
/// Returns null for society-wide rows (no tag on the web).
String? notificationTargetTag(
    {required String targetType, String? targetId, required String flatWord}) {
  if (targetType == 'all') return null;
  final id = targetId ?? '';
  return targetType == 'flat' ? '→ $flatWord $id' : '→ $id';
}

/// End of the given local day (web `endOfDay(parse(date))`), used by "Clear till date".
DateTime endOfLocalDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Ids to dismiss for "Clear till date": rows visible to the resident and not yet dismissed.
List<String> idsToDismiss(
  List<Map<String, dynamic>> rows, {
  required Set<String> alreadyDismissed,
  required String residentId,
  required String residentName,
  required String flatNumber,
}) {
  return rows
      .where((r) => notificationRowVisibleToResident(r,
          residentId: residentId,
          residentName: residentName,
          flatNumber: flatNumber))
      .map((r) => r['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty && !alreadyDismissed.contains(id))
      .toList();
}
