import 'package:flutter/foundation.dart';

import '../../../models/blacklist_entry.dart';
import '../../../services/blacklist_service.dart';
import '../../../services/visitor_service.dart';
import 'gate_directory_service.dart';
import 'gate_logic.dart';
import 'gate_models.dart';

/// Society gate data shared by the guard tabs (and the admin gate modules) — the mobile
/// counterpart of the web zustand store slices `visitors`, `residentVehicles`, `blacklist`,
/// `flats` and `members` (`src/store/useStore.ts`). One instance per society.
class GateStore extends ChangeNotifier {
  GateStore._(this.societyId);

  final String societyId;

  static final Map<String, GateStore> _stores = {};

  /// The store of [societyId] (created on first use).
  static GateStore of(String societyId) =>
      _stores.putIfAbsent(societyId, () => GateStore._(societyId));

  /// Drops cached data of a society (logout) — web `setSocietyId(null)`.
  static void clear(String societyId) => _stores.remove(societyId)?._reset();

  final _visitorService = VisitorService();
  final _blacklistService = BlacklistService();
  final _directory = const GateDirectoryService();
  final _vehicleService = const GateVehicleService();

  List<GateVisitor> visitors = const [];
  List<GateResidentVehicle> residentVehicles = const [];
  List<BlacklistEntry> blacklist = const [];
  List<GateFlat> flats = const [];
  List<GateMember> members = const [];

  bool visitorsLoaded = false;
  bool vehiclesLoaded = false;
  bool blacklistLoaded = false;
  bool flatsLoaded = false;
  bool membersLoaded = false;

  /// Last load error per collection (null when the last load succeeded).
  Object? visitorsError;
  Object? vehiclesError;
  Object? blacklistError;
  Object? directoryError;

  DateTime? visitorsLoadedAt;
  Future<void>? _initial;
  bool _disposed = false;

  // Latest-request-wins counters: a reload started after a write supersedes older loads.
  int _visitorsSeq = 0;
  int _vehiclesSeq = 0;
  int _blacklistSeq = 0;
  int _directorySeq = 0;

  bool get directoryLoaded => flatsLoaded && membersLoaded;

  /// Loads everything once (web: on guard login `loadVisitors/loadResidentVehicles/loadBlacklist/loadFlats/loadMembers`).
  Future<void> ensureLoaded() => _initial ??= loadAll();

  Future<void> loadAll() async {
    await Future.wait([
      loadVisitors(),
      loadResidentVehicles(),
      loadBlacklist(),
      loadDirectory()
    ]);
  }

  /// Reload visitors when the cached copy is older than [maxAge] (app resume / tab return).
  Future<void> refreshVisitorsIfStale(
      {Duration maxAge = const Duration(seconds: 60)}) async {
    final at = visitorsLoadedAt;
    if (at == null || DateTime.now().difference(at) > maxAge) {
      await loadVisitors();
    }
  }

  Future<void> loadVisitors() async {
    final seq = ++_visitorsSeq;
    try {
      final rows = await _visitorService.fetchAll(societyId);
      if (seq != _visitorsSeq) return;
      visitors = rows;
      visitorsError = null;
      visitorsLoadedAt = DateTime.now();
    } catch (e) {
      if (seq != _visitorsSeq) return;
      visitorsError = e;
    }
    visitorsLoaded = true;
    _notify();
  }

  Future<void> loadResidentVehicles() async {
    final seq = ++_vehiclesSeq;
    try {
      final rows = await _vehicleService.fetchAll(societyId);
      if (seq != _vehiclesSeq) return;
      residentVehicles = rows;
      vehiclesError = null;
    } catch (e) {
      if (seq != _vehiclesSeq) return;
      vehiclesError = e;
    }
    vehiclesLoaded = true;
    _notify();
  }

  Future<void> loadBlacklist() async {
    final seq = ++_blacklistSeq;
    try {
      final rows = await _blacklistService.fetchAll(societyId);
      if (seq != _blacklistSeq) return;
      blacklist = rows;
      blacklistError = null;
    } catch (e) {
      if (seq != _blacklistSeq) return;
      blacklistError = e;
    }
    blacklistLoaded = true;
    _notify();
  }

  /// Flats then members of those flats (web `loadFlats` + `loadMembers`).
  Future<void> loadDirectory() async {
    final seq = ++_directorySeq;
    try {
      final f = await _directory.fetchFlats(societyId);
      final m = await _directory.fetchMembers(f.map((x) => x.id).toList());
      if (seq != _directorySeq) return;
      flats = f;
      members = m;
      directoryError = null;
    } catch (e) {
      if (seq != _directorySeq) return;
      directoryError = e;
    }
    flatsLoaded = true;
    membersLoaded = true;
    _notify();
  }

  // ---------------------------------------------------------------- visitors

  /// Web `addVisitor`: insert, then reload the log. Throws when the insert fails.
  Future<void> addVisitor(GateVisitor visitor) async {
    await _visitorService.insert(societyId, visitor);
    await loadVisitors();
  }

  /// Web `markExit`: stamps the exit (and vehicle exit) time, patches the cached row.
  Future<void> markExit(String visitorId) async {
    GateVisitor? visitor;
    for (final v in visitors) {
      if (v.id == visitorId) {
        visitor = v;
        break;
      }
    }
    final hadVehicle = visitor?.hasVehicle ?? false;
    final now = await _visitorService.markExitFor(
        societyId: societyId, visitorId: visitorId, hadVehicle: hadVehicle);
    visitors = [
      for (final v in visitors)
        if (v.id == visitorId)
          v.copyWith(
              exitTime: now,
              vehicleExitTime: v.hasVehicle ? now : null,
              clearVehicleExit: !v.hasVehicle)
        else
          v,
    ];
    _notify();
  }

  // ---------------------------------------------------------------- blacklist

  /// Web `isBlacklisted(phone, vehicleNumber)`.
  bool isBlacklisted({String? phone, String? vehicleNumber}) =>
      isBlacklistedIn(blacklist, phone: phone, vehicleNumber: vehicleNumber);

  Future<void> addToBlacklist({
    required String type,
    required String reason,
    required String addedBy,
    String? name,
    String? phone,
    String? vehicleNumber,
  }) async {
    await _blacklistService.addEntry(
      societyId: societyId,
      type: type,
      reason: reason,
      addedBy: addedBy,
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
    );
    await loadBlacklist();
  }

  Future<void> removeFromBlacklist(String id) async {
    await _blacklistService.removeEntry(societyId, id);
    blacklist = blacklist.where((e) => e.id != id).toList();
    _notify();
  }

  // ---------------------------------------------------------------- vehicles

  Future<void> addResidentVehicle({
    required String flatNumber,
    required String residentName,
    required String vehicleNumber,
    required String vehicleType,
    String? flatId,
  }) async {
    await _vehicleService.add(
      societyId: societyId,
      flatNumber: flatNumber,
      residentName: residentName,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      flatId: flatId,
    );
    await loadResidentVehicles();
  }

  Future<void> removeResidentVehicle(String id) async {
    await _vehicleService.remove(societyId: societyId, id: id);
    residentVehicles = residentVehicles.where((v) => v.id != id).toList();
    _notify();
  }

  // ---------------------------------------------------------------- internals

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _reset() {
    // Invalidate loads still in flight so they cannot repopulate a logged-out store.
    _visitorsSeq++;
    _vehiclesSeq++;
    _blacklistSeq++;
    _directorySeq++;
    visitors = const [];
    residentVehicles = const [];
    blacklist = const [];
    flats = const [];
    members = const [];
    visitorsLoaded =
        vehiclesLoaded = blacklistLoaded = flatsLoaded = membersLoaded = false;
    _initial = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
