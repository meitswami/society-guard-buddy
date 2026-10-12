import '../core/supabase/db.dart';
import '../features/comms/data/notification_audience.dart';
import '../features/comms/data/notification_repository.dart';
import '../features/home/models/announcement.dart';

/// Legacy resident feed API (home cards / unread badge). Uses the COMMS queries and the
/// web `notificationVisibleToResident` rules; dismissed alerts are hidden.
class NotificationService {
  final _repo = const NotificationRepository();

  bool _visible(Map<String, dynamic> row, String residentId,
          String residentName, String flatNumber) =>
      notificationRowVisibleToResident(row,
          residentId: residentId,
          residentName: residentName,
          flatNumber: flatNumber);

  Future<List<Announcement>> fetchRecentForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
    int limit = 5,
  }) async {
    if (!dbReady) return const [];
    final dismissed = await _repo.loadDismissedIds(residentId);
    final rows = rowsOf(await db
        .from('notifications')
        .select(
            'id, title, message, type, created_at, target_type, target_id, society_id')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(150));
    return rows
        .where((r) =>
            !dismissed.contains(r['id']?.toString()) &&
            _visible(r, residentId, residentName, flatNumber))
        .take(limit)
        .map(_mapRow)
        .toList();
  }

  Future<int> countUnreadForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
  }) async {
    if (!dbReady) return 0;
    final dismissed = await _repo.loadDismissedIds(residentId);
    final rows = rowsOf(await db
        .from('notifications')
        .select('id, target_type, target_id, society_id, is_read')
        .eq('society_id', societyId)
        .eq('is_read', false));
    return rows
        .where((r) =>
            !dismissed.contains(r['id']?.toString()) &&
            _visible(r, residentId, residentName, flatNumber))
        .length;
  }

  /// Web "Clear till date" for one resident (dismissals only — other residents unaffected).
  Future<int> clearTillDateForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
    required DateTime tillDateInclusive,
  }) async {
    if (!dbReady) return 0;
    final dismissed = await _repo.loadDismissedIds(residentId);
    final rows = await _repo.loadForClear(
        societyId, endOfLocalDay(tillDateInclusive).toUtc().toIso8601String());
    final ids = idsToDismiss(rows,
        alreadyDismissed: dismissed,
        residentId: residentId,
        residentName: residentName,
        flatNumber: flatNumber);
    await _repo.dismiss(ids, residentId);
    return ids.length;
  }

  Announcement _mapRow(Map<String, dynamic> row) {
    final type = row['type']?.toString() ?? '';
    return Announcement(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Announcement',
      subtitle: row['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      category: type.contains('event') || type.contains('meeting')
          ? AnnouncementCategory.community
          : (type.contains('maintenance') ||
                  type.contains('payment') ||
                  type.contains('finance'))
              ? AnnouncementCategory.maintenance
              : AnnouncementCategory.general,
    );
  }
}
