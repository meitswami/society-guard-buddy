/// Port of web `src/lib/notificationAudience.ts` (`notificationVisibleToResident`) plus the
/// society guard of `ResidentDashboard.notificationRowForResident`.
library;

/// Whether a notification row is visible to a resident (flat / person / society-wide).
bool notificationVisibleToResident({
  required String? targetType,
  required String? targetId,
  required String residentId,
  required String residentName,
  required String flatNumber,
}) {
  final type = targetType ?? '';
  final id = (targetId ?? '').trim();
  if (type == 'all') return true;
  if (type == 'flat') {
    if (id == flatNumber) return true;
    if (id.contains(',')) return id.split(',').map((s) => s.trim()).contains(flatNumber);
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

/// Realtime insert filter used by the resident shell toast.
bool notificationRowForResident(
  Map<String, dynamic> row, {
  required String societyId,
  required String residentId,
  required String residentName,
  required String flatNumber,
}) {
  final rowSociety = row['society_id']?.toString() ?? '';
  if (societyId.isNotEmpty && rowSociety.isNotEmpty && rowSociety != societyId) return false;
  return notificationVisibleToResident(
    targetType: row['target_type']?.toString(),
    targetId: row['target_id']?.toString(),
    residentId: residentId,
    residentName: residentName,
    flatNumber: flatNumber,
  );
}
