import '../../../../core/supabase/db.dart';
import '../../../../utils/society_flat_layout.dart';

/// Web `GenerateFlatsResult`.
class GenerateFlatsResult {
  const GenerateFlatsResult(
      {required this.created, required this.skipped, this.error});

  final int created;
  final int skipped;
  final String? error;

  bool get ok => error == null;
}

/// Bulk flat generation from the society layout — port of web
/// `upsertSocietyFlatsFromLayout` / `trimSocietyFlatsToConfiguredRange` and the superadmin
/// "Reset flats from this layout" action. Usable by any module (superadmin society editor too).
class FlatLayoutService {
  /// Layout columns of `societies`.
  Future<SocietyFlatRangeInput?> fetchLayout(String societyId) async {
    if (!dbReady) return null;
    final row = await db
        .from('societies')
        .select('total_floors, flat_series_start, flat_series_end, block_names')
        .eq('id', societyId)
        .maybeSingle();
    return row == null ? null : SocietyFlatRangeInput.fromRow(row);
  }

  /// Persists the layout columns (block names upper-cased like the generator expects).
  Future<void> saveLayout(
      String societyId, SocietyFlatRangeInput layout) async {
    final blocks = (layout.blockNames ?? const [])
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    await db.from('societies').update({
      'total_floors': layout.totalFloors,
      'flat_series_start': (layout.flatSeriesStart ?? '').trim().isEmpty
          ? null
          : layout.flatSeriesStart!.trim(),
      'flat_series_end': (layout.flatSeriesEnd ?? '').trim().isEmpty
          ? null
          : layout.flatSeriesEnd!.trim(),
      'block_names': blocks.isEmpty ? null : blocks,
    }).eq('id', societyId);
  }

  /// Web `upsertSocietyFlatsFromLayout` (idempotent; inserts in chunks of 250).
  Future<GenerateFlatsResult> upsertFromLayout(
      String societyId, SocietyFlatRangeInput row) async {
    if (societyId.isEmpty) {
      return const GenerateFlatsResult(
          created: 0, skipped: 0, error: 'Missing society id');
    }
    if (canTrimFlatsFromSocietyRow(row) == null) {
      return const GenerateFlatsResult(
          created: 0, skipped: 0, error: kInvalidLayoutError);
    }
    List<Map<String, dynamic>> existing;
    try {
      existing = rowsOf(await db
          .from('flats')
          .select('flat_number, wing')
          .eq('society_id', societyId));
    } catch (e) {
      return GenerateFlatsResult(created: 0, skipped: 0, error: '$e');
    }
    final plan = planFlatsFromLayout(
      societyId: societyId,
      row: row,
      existing: [
        for (final r in existing)
          ExistingFlatKey('${r['flat_number']}', r['wing']?.toString())
      ],
    );
    if (plan.error != null) {
      return GenerateFlatsResult(
          created: 0, skipped: plan.skipped, error: plan.error);
    }
    if (plan.rows.isEmpty) {
      return GenerateFlatsResult(created: 0, skipped: plan.skipped);
    }

    const chunk = 250;
    var created = 0;
    for (var i = 0; i < plan.rows.length; i += chunk) {
      final part = plan.rows.sublist(
          i, i + chunk > plan.rows.length ? plan.rows.length : i + chunk);
      try {
        await db.from('flats').insert(part);
      } catch (e) {
        return GenerateFlatsResult(
            created: created, skipped: plan.skipped, error: '$e');
      }
      created += part.length;
    }
    return GenerateFlatsResult(created: created, skipped: plan.skipped);
  }

  /// Web `trimSocietyFlatsToConfiguredRange` — deletes residential flats outside the configured
  /// range (members cascade). Returns the number of removed flats.
  Future<int> trimToConfiguredRange(
      String societyId, SocietyFlatRangeInput row) async {
    final range = canTrimFlatsFromSocietyRow(row);
    if (range == null || !dbReady) return 0;
    List<Map<String, dynamic>> flats;
    try {
      flats = rowsOf(await db
          .from('flats')
          .select('id, flat_number, wing, flat_type')
          .eq('society_id', societyId));
    } catch (_) {
      return 0;
    }
    final ids = <String>[
      for (final f in flats)
        if (flatRowShouldTrim(
          flatNumber: '${f['flat_number']}',
          wing: f['wing']?.toString(),
          flatType: f['flat_type']?.toString(),
          range: range,
          blockNames: row.blockNames,
        ))
          '${f['id']}',
    ];
    if (ids.isEmpty) return 0;
    const chunk = 200;
    for (var i = 0; i < ids.length; i += chunk) {
      final part =
          ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      try {
        await db.from('flats').delete().inFilter('id', part);
      } catch (_) {
        return 0;
      }
    }
    return ids.length;
  }

  /// Superadmin "Reset flats from this layout": delete residential (or untyped) flats, then regenerate.
  Future<GenerateFlatsResult> resetAndRegenerate(
      String societyId, SocietyFlatRangeInput row) async {
    await db
        .from('flats')
        .delete()
        .eq('society_id', societyId)
        .or('flat_type.eq.residential,flat_type.is.null');
    return upsertFromLayout(societyId, row);
  }
}
