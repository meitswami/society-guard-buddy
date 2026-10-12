import '../core/config/env.dart';
import '../core/supabase/db.dart';
import '../features/gate/data/gate_models.dart';

/// Lightweight visitor row (legacy API kept for existing callers).
class VisitorEntry {
  const VisitorEntry({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.category,
    required this.entryTime,
    this.exitTime,
    this.vehicleNumber,
  });

  final String id;
  final String name;
  final String phone;
  final String flatNumber;
  final String category;
  final String entryTime;
  final String? exitTime;
  final String? vehicleNumber;

  bool get isInside => exitTime == null || exitTime!.isEmpty;
}

/// `visitors` table access — same queries as web `useStore` (`loadVisitors`, `addVisitor`, `markExit`).
class VisitorService {
  /// Every column the gate screens read. `document_photo` / `vehicle_photo` are never shown by
  /// the guard screens, so they are not downloaded with the full society log.
  static const listColumns = 'id, society_id, name, phone, document_type, document_number, visitor_photos, '
      'flat_number, purpose, entry_time, exit_time, guard_id, guard_name, category, company, vehicle_number, '
      'vehicle_entry_time, vehicle_exit_time, is_blacklisted';

  /// Web `loadVisitors`: all visitors of the society, newest first.
  Future<List<GateVisitor>> fetchAll(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await db.from('visitors').select(listColumns).eq('society_id', societyId).order('entry_time', ascending: false);
    return rowsOf(rows).map(GateVisitor.fromRow).toList();
  }

  /// Web `addVisitor` insert. Throws on failure.
  Future<void> insert(String societyId, GateVisitor visitor) async {
    if (!Env.isConfigured) return;
    await db.from('visitors').insert(visitor.toInsertRow(societyId));
  }

  /// Web `markExit`: exit time, plus the vehicle exit time when the visit had a vehicle.
  Future<String> markExitFor({required String societyId, required String visitorId, required bool hadVehicle}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (!Env.isConfigured) return now;
    await db
        .from('visitors')
        .update({'exit_time': now, 'vehicle_exit_time': hadVehicle ? now : null})
        .eq('id', visitorId)
        .eq('society_id', societyId);
    return now;
  }

  /// Today's visitors (local day), newest first. Legacy helper.
  Future<List<VisitorEntry>> fetchToday(String societyId) async {
    if (!Env.isConfigured) return const [];
    final now = DateTime.now();
    final startUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final rows = await db
        .from('visitors')
        .select('id, name, phone, flat_number, category, entry_time, exit_time, vehicle_number')
        .eq('society_id', societyId)
        .gte('entry_time', startUtc)
        .order('entry_time', ascending: false)
        .limit(200);
    return rowsOf(rows)
        .map((m) => VisitorEntry(
              id: m['id'] as String,
              name: m['name'] as String? ?? 'Unknown',
              phone: m['phone'] as String? ?? '',
              flatNumber: m['flat_number'] as String? ?? '',
              category: m['category'] as String? ?? 'visitor',
              entryTime: m['entry_time'] as String? ?? '',
              exitTime: m['exit_time'] as String?,
              vehicleNumber: m['vehicle_number'] as String?,
            ))
        .toList();
  }

  /// Legacy exit helper (no society / vehicle handling). Prefer [markExitFor].
  Future<void> markExit(String visitorId) async {
    if (!Env.isConfigured) return;
    await db.from('visitors').update({'exit_time': DateTime.now().toUtc().toIso8601String()}).eq('id', visitorId);
  }
}
