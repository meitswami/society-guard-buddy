import 'dart:async';

import '../../../core/supabase/db.dart';
import '../logic/kiosk_conversation.dart';
import '../logic/kiosk_parsers.dart';

/// Society data the kiosk needs — the web reads these from the zustand store
/// (`flats`, `visitors`, `blacklist`, `addVisitor`); the app queries the same tables.
class KioskRepository {
  KioskRepository(this.societyId);

  final String societyId;

  List<String> _flatNumbers = const [];
  List<({String? phone, String? vehicle})> _blacklist = const [];

  /// Flat numbers of the society (web `useStore.flats.map(f => f.flatNumber)`).
  List<String> get flatNumbers => _flatNumbers;

  /// `societies.name` (web `KioskRunner` effect).
  Future<String?> loadSocietyName() async {
    if (!dbReady) return null;
    try {
      final row = await db.from('societies').select('name').eq('id', societyId).maybeSingle();
      final name = row?['name'];
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }

  /// Web `loadFlats` + `loadBlacklist` (refreshed at every kiosk session).
  Future<void> refresh() async {
    if (!dbReady) return;
    await Future.wait([_loadFlats(), _loadBlacklist()]);
  }

  Future<void> _loadFlats() async {
    try {
      final rows = rowsOf(await db.from('flats').select('flat_number').eq('society_id', societyId).order('flat_number', ascending: true));
      _flatNumbers = [
        for (final r in rows)
          if (r['flat_number'] is String && (r['flat_number'] as String).isNotEmpty) r['flat_number'] as String,
      ];
    } catch (_) {
      // Keep the last list (offline).
    }
  }

  Future<void> _loadBlacklist() async {
    try {
      final rows = rowsOf(await db
          .from('blacklist')
          .select('phone, vehicle_number')
          .eq('society_id', societyId)
          .order('added_at', ascending: false));
      _blacklist = [for (final r in rows) (phone: r['phone'] as String?, vehicle: r['vehicle_number'] as String?)];
    } catch (_) {
      // Keep the last list (offline).
    }
  }

  /// Web `isBlacklisted(phone, vehicle)`: exact match on phone or vehicle number.
  /// Checks the live table first (the kiosk runs for hours), the cached list offline.
  Future<bool> isBlacklisted(String? phone, String? vehicle) async {
    final p = (phone ?? '').trim();
    final v = (vehicle ?? '').trim();
    if (p.isEmpty && v.isEmpty) return false;
    bool cached() => _blacklist.any((e) => (p.isNotEmpty && e.phone == p) || (v.isNotEmpty && e.vehicle == v));
    if (!dbReady) return cached();
    try {
      // Phone is digits only and the vehicle is [A-Z0-9] (parsed), so the filter is safe.
      final safeV = v.replaceAll(RegExp('[^A-Za-z0-9]'), '');
      final safeP = p.replaceAll(RegExp(r'[^0-9+]'), '');
      final ors = [
        if (safeP.isNotEmpty) 'phone.eq.$safeP',
        if (safeV.isNotEmpty) 'vehicle_number.eq.$safeV',
      ];
      if (ors.isEmpty) return cached();
      final rows = rowsOf(await db
          .from('blacklist')
          .select('id')
          .eq('society_id', societyId)
          .or(ors.join(','))
          .limit(1)
          .timeout(const Duration(seconds: 5)));
      return rows.isNotEmpty || cached();
    } catch (_) {
      return cached();
    }
  }

  /// Latest visit by this phone (web `visitors.find(x => x.phone === phone)` on the
  /// list ordered by `entry_time desc`).
  Future<KioskPreviousVisit?> findPreviousVisit(String phone) async {
    if (!dbReady || phone.isEmpty) return null;
    try {
      final rows = rowsOf(await db
          .from('visitors')
          .select('name, flat_number')
          .eq('society_id', societyId)
          .eq('phone', phone)
          .order('entry_time', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 5)));
      if (rows.isEmpty) return null;
      return KioskPreviousVisit(name: '${rows.first['name'] ?? ''}', flatNumber: '${rows.first['flat_number'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  /// Web `addVisitor` with the kiosk's `Visitor` object (KioskPage `saveEntry`).
  /// Returns false when the insert failed.
  Future<bool> saveEntry(
    KioskDraft d, {
    required String guardId,
    required String guardName,
    required bool capsEntry,
  }) async {
    if (!dbReady) return false;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final vehicle = d.vehicle ?? '';
    final photo = d.photo ?? '';
    final company = d.company ?? '';
    try {
      await db.from('visitors').insert({
        'society_id': societyId,
        // normalizeEntryValue(d.name, { field: 'name' })
        'name': capsEntry ? d.name.toUpperCase() : d.name,
        'phone': d.phone,
        'document_type': 'other',
        'document_number': null,
        'document_photo': null,
        'visitor_photos': photo.isEmpty ? <String>[] : [photo],
        'flat_number': d.flat,
        'purpose': (d.purpose ?? KioskPurpose.other).label,
        'entry_time': nowIso,
        'guard_id': guardId,
        'guard_name': guardName,
        'category': d.purpose == KioskPurpose.delivery ? 'delivery' : 'visitor',
        'company': company.isEmpty ? null : company,
        'vehicle_number': vehicle.isEmpty ? null : vehicle,
        'vehicle_entry_time': vehicle.isEmpty ? null : nowIso,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
