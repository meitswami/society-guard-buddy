import '../../../core/supabase/db.dart';
import 'directory_models.dart';

/// Runs `select … in(column, ids)` in chunks (long id lists would overflow the URL);
/// [build] receives each chunk's filter builder and may add ordering.
Future<List<Map<String, dynamic>>> selectInChunks({
  required String table,
  required String columns,
  required String column,
  required List<String> ids,
  int chunk = 120,
  Object Function(dynamic query)? build,
}) async {
  final unique = ids.toSet().toList();
  if (unique.isEmpty) return const [];
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < unique.length; i += chunk) {
    final part = unique.sublist(
        i, i + chunk > unique.length ? unique.length : i + chunk);
    final q = db.from(table).select(columns).inFilter(column, part);
    final res = build == null ? await q : await (build(q) as Future<Object?>);
    out.addAll(rowsOf(res));
  }
  return out;
}

/// Everything the shared directory renders.
class DirectoryData {
  const DirectoryData({
    required this.flats,
    required this.members,
    required this.vehicles,
    this.visitors = const [],
  });

  final List<PeopleFlat> flats;
  final List<PeopleMember> members;
  final List<PeopleVehicle> vehicles;
  final List<DirectoryVisitor> visitors;

  static const empty = DirectoryData(flats: [], members: [], vehicles: []);
}

/// Loads the society directory the same way as the web store
/// (`loadFlats` / `loadMembers` / `loadResidentVehicles` / `loadVisitors`) and the resident
/// dashboard (`loadDirectory`).
class DirectoryService {
  /// `flats` of the society ordered by flat number (web `loadFlats`).
  Future<List<PeopleFlat>> loadFlats(String societyId) async {
    if (!dbReady) return const [];
    final rows = await db
        .from('flats')
        .select('*')
        .eq('society_id', societyId)
        .order('flat_number', ascending: true);
    return rowsOf(rows).map(PeopleFlat.fromJson).toList();
  }

  /// Members of the given flats, primary first (web `loadMembers`).
  Future<List<PeopleMember>> loadMembers(List<String> flatIds,
      {String columns = '*'}) async {
    if (!dbReady || flatIds.isEmpty) return const [];
    final rows = await selectInChunks(
      table: 'members',
      columns: columns,
      column: 'flat_id',
      ids: flatIds,
      build: (q) => q.order('is_primary', ascending: false),
    );
    final list = rows.map(PeopleMember.fromJson).toList();
    // Keep the global "primary first" order across chunks (stable).
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final p = (b.value.isPrimary ? 1 : 0) - (a.value.isPrimary ? 1 : 0);
        return p != 0 ? p : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  /// `resident_vehicles` of the society (web `loadResidentVehicles`).
  Future<List<PeopleVehicle>> loadVehicles(String societyId) async {
    if (!dbReady) return const [];
    final rows = await db
        .from('resident_vehicles')
        .select('*')
        .eq('society_id', societyId);
    return rowsOf(rows).map(PeopleVehicle.fromJson).toList();
  }

  /// Gate visitors, newest first (web `loadVisitors`; PostgREST caps responses at 1000 rows).
  Future<List<DirectoryVisitor>> loadVisitors(String societyId) async {
    if (!dbReady) return const [];
    final rows = await db
        .from('visitors')
        .select(
          'id, name, phone, visitor_photos, flat_number, category, document_type, document_number, purpose, vehicle_number, entry_time',
        )
        .eq('society_id', societyId)
        .order('entry_time', ascending: false)
        .limit(1000);
    return rowsOf(rows).map(DirectoryVisitor.fromJson).toList();
  }

  /// Guard / admin directory (flats, members, vehicles, visitors).
  Future<DirectoryData> loadStaffDirectory(String societyId) async {
    if (!dbReady) return DirectoryData.empty;
    final flats = await loadFlats(societyId);
    final results = await Future.wait<Object>([
      loadMembers(flats.map((f) => f.id).toList()),
      loadVehicles(societyId),
      loadVisitors(societyId),
    ]);
    return DirectoryData(
      flats: flats,
      members: results[0] as List<PeopleMember>,
      vehicles: results[1] as List<PeopleVehicle>,
      visitors: results[2] as List<DirectoryVisitor>,
    );
  }

  /// Resident directory tab (web `ResidentDashboard.loadDirectory`): vehicles are the
  /// rows of the society's flats whose flat number matches a society flat.
  Future<DirectoryData> loadResidentDirectory(String societyId) async {
    if (!dbReady) return DirectoryData.empty;
    final flats = await loadFlats(societyId);
    final flatIds = flats.map((f) => f.id).toList();
    final flatNumbers = flats.map((f) => f.flatNumber).toSet();
    final results = await Future.wait<Object>([
      loadMembers(flatIds,
          columns:
              'id, flat_id, name, phone, relation, age, gender, photo, is_primary, created_at'),
      selectInChunks(
          table: 'resident_vehicles',
          columns: '*',
          column: 'flat_id',
          ids: flatIds),
    ]);
    final vehicles = (results[1] as List<Map<String, dynamic>>)
        .map(PeopleVehicle.fromJson)
        .where((v) => flatNumbers.contains(v.flatNumber))
        .toList();
    return DirectoryData(
        flats: flats,
        members: results[0] as List<PeopleMember>,
        vehicles: vehicles);
  }
}
