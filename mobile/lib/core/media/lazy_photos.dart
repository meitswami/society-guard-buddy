import 'dart:async';

import '../supabase/db.dart';

/// Loads photos stored in the database (as `data:image…` text or URLs) only for the rows
/// actually shown on screen, in small batches, and keeps them in memory.
///
/// Society-wide lists (directory, residents, meetings, gate data) must not select photo
/// columns: with base64 photos those responses run to tens of megabytes, which stalls the
/// app on mobile data and blocks every other request behind it.
class LazyPhotoLoader {
  LazyPhotoLoader._(this.table, this.column);

  /// `members.photo` (face photo).
  static final members = LazyPhotoLoader._('members', 'photo');

  /// `members.id_photo_front` / `members.id_photo_back` (photo ID images).
  static final memberIdFront = LazyPhotoLoader._('members', 'id_photo_front');
  static final memberIdBack = LazyPhotoLoader._('members', 'id_photo_back');

  /// First entry of `visitors.visitor_photos`.
  static final visitors = LazyPhotoLoader._('visitors', 'visitor_photos');

  final String table;
  final String column;

  static const _batch = 20;
  static const _delay = Duration(milliseconds: 40);

  final Map<String, String?> _cache = {};
  final Map<String, Completer<String?>> _pending = {};
  Timer? _timer;

  /// Cached value, if this id was loaded before (null when unknown or no photo).
  String? cached(String id) => _cache[id];

  bool isCached(String id) => _cache.containsKey(id);

  /// Photo for [id] (null when none). Requests made in the same frame share one query.
  Future<String?> get(String id) {
    if (id.isEmpty || !dbReady) return Future.value(null);
    if (_cache.containsKey(id)) return Future.value(_cache[id]);
    final existing = _pending[id];
    if (existing != null) return existing.future;
    final c = Completer<String?>();
    _pending[id] = c;
    _timer ??= Timer(_delay, _flush);
    return c.future;
  }

  /// Seed or replace a value after the app saved a new photo.
  void put(String id, String? photo) => _cache[id] = _clean(photo);

  void invalidate(String id) => _cache.remove(id);

  Future<void> _flush() async {
    _timer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    final ids = batch.keys.toList();
    for (var i = 0; i < ids.length; i += _batch) {
      final part = ids.sublist(i, i + _batch > ids.length ? ids.length : i + _batch);
      try {
        final rows = rowsOf(await db.from(table).select('id, $column').inFilter('id', part));
        final found = <String, String?>{for (final r in rows) '${r['id']}': _clean(r[column])};
        for (final id in part) {
          final v = found[id];
          _cache[id] = v;
          batch[id]!.complete(v);
        }
      } catch (_) {
        // Leave uncached so a later rebuild can retry; show the initial meanwhile.
        for (final id in part) {
          batch[id]!.complete(null);
        }
      }
    }
  }

  static String? _clean(Object? v) {
    if (v is List) v = v.isEmpty ? null : v.first;
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
}
