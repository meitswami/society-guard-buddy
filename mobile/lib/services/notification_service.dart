import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../features/home/models/announcement.dart';

/// Port of notification feed logic from `NotificationCenter.tsx` + resident filters.
class NotificationService {
  Future<Set<String>> _dismissedIds(String residentId) async {
    if (!Env.isConfigured) return {};

    final rows = await SupabaseBootstrap.client
        .from('notification_dismissals')
        .select('notification_id')
        .eq('resident_id', residentId);

    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['notification_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Announcement>> fetchRecentForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
    int limit = 5,
  }) async {
    if (!Env.isConfigured) return _demoAnnouncements();

    final dismissed = await _dismissedIds(residentId);

    final rows = await SupabaseBootstrap.client
        .from('notifications')
        .select('id, title, message, type, created_at, target_type, target_id, society_id')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(150);

    final filtered = (rows as List).where((row) {
      final map = row as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      if (dismissed.contains(id)) return false;
      return _rowVisibleToResident(
        row: map,
        residentId: residentId,
        residentName: residentName,
        flatNumber: flatNumber,
      );
    }).take(limit);

    return filtered
        .map((row) => _mapRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> countUnreadForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
  }) async {
    if (!Env.isConfigured) return 12;

    final dismissed = await _dismissedIds(residentId);

    final rows = await SupabaseBootstrap.client
        .from('notifications')
        .select('id, target_type, target_id, society_id, is_read')
        .eq('society_id', societyId)
        .eq('is_read', false);

    return (rows as List).where((row) {
      final map = row as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      if (dismissed.contains(id)) return false;
      return _rowVisibleToResident(
        row: map,
        residentId: residentId,
        residentName: residentName,
        flatNumber: flatNumber,
      );
    }).length;
  }

  Future<int> clearTillDateForResident({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
    required DateTime tillDateInclusive,
  }) async {
    if (!Env.isConfigured) return 0;

    final dismissed = await _dismissedIds(residentId);
    final cutoff = DateTime(
      tillDateInclusive.year,
      tillDateInclusive.month,
      tillDateInclusive.day,
      23,
      59,
      59,
      999,
    );

    final rows = await SupabaseBootstrap.client
        .from('notifications')
        .select('id, target_type, target_id, created_at')
        .eq('society_id', societyId)
        .lte('created_at', cutoff.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    final ids = (rows as List).where((row) {
      final map = row as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      if (dismissed.contains(id)) return false;
      return _rowVisibleToResident(
        row: map,
        residentId: residentId,
        residentName: residentName,
        flatNumber: flatNumber,
      );
    }).map((row) => (row as Map<String, dynamic>)['id']?.toString() ?? '').where((id) => id.isNotEmpty);

    final payload = ids.map((id) => {
      'notification_id': id,
      'resident_id': residentId,
    }).toList();

    if (payload.isEmpty) return 0;

    await SupabaseBootstrap.client
        .from('notification_dismissals')
        .upsert(payload, onConflict: 'notification_id,resident_id', ignoreDuplicates: true);

    return payload.length;
  }

  bool _rowVisibleToResident({
    required Map<String, dynamic> row,
    required String residentId,
    required String residentName,
    required String flatNumber,
  }) {
    final targetType = row['target_type']?.toString() ?? '';
    final targetId = row['target_id']?.toString().trim() ?? '';
    if (targetType == 'all') return true;
    if (targetType == 'flat') {
      if (targetId == flatNumber) return true;
      if (targetId.contains(',')) {
        return targetId.split(',').map((s) => s.trim()).contains(flatNumber);
      }
    }
    if (targetType == 'user') {
      if (targetId == residentId) return true;
      if (targetId == residentName) return true;
      if (targetId.contains(',')) {
        final parts = targetId.split(',').map((s) => s.trim());
        return parts.contains(residentId) || parts.contains(residentName);
      }
    }
    return false;
  }

  Announcement _mapRow(Map<String, dynamic> row) {
    final type = row['type']?.toString() ?? '';
    return Announcement(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Announcement',
      subtitle: row['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      category: _categoryFromType(type),
    );
  }

  AnnouncementCategory _categoryFromType(String type) {
    if (type.contains('event') || type.contains('meeting')) {
      return AnnouncementCategory.community;
    }
    if (type.contains('maintenance') || type.contains('finance')) {
      return AnnouncementCategory.maintenance;
    }
    return AnnouncementCategory.general;
  }

  List<Announcement> _demoAnnouncements() {
    return [
      Announcement(
        id: '1',
        title: 'Water supply maintenance',
        subtitle: 'Maintenance work on 12th May',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        category: AnnouncementCategory.maintenance,
      ),
      Announcement(
        id: '2',
        title: 'Annual General Meeting',
        subtitle: 'AGM on 19th May, 6:00 PM',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        category: AnnouncementCategory.community,
      ),
      Announcement(
        id: '3',
        title: 'Pool timing change',
        subtitle: 'New timing: 7 AM - 9 PM',
        createdAt: DateTime(2026, 5, 2),
        category: AnnouncementCategory.general,
      ),
    ];
  }
}
