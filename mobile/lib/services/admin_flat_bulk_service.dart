import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../utils/society_flat_layout.dart';

class FlatGenerateResult {
  const FlatGenerateResult({
    required this.created,
    required this.skipped,
    this.error,
  });

  final int created;
  final int skipped;
  final String? error;

  bool get ok => error == null;
}

class SocietyLayout {
  const SocietyLayout({
    required this.totalFloors,
    required this.flatSeriesStart,
    required this.flatSeriesEnd,
    required this.blockNames,
  });

  final int? totalFloors;
  final String? flatSeriesStart;
  final String? flatSeriesEnd;
  final List<String> blockNames;
}

class AdminFlatBulkService {
  Future<SocietyLayout?> fetchLayout(String societyId) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('societies')
        .select('total_floors, flat_series_start, flat_series_end, block_names')
        .eq('id', societyId)
        .maybeSingle();
    if (row == null) return null;
    final blocks = row['block_names'];
    return SocietyLayout(
      totalFloors: row['total_floors'] as int?,
      flatSeriesStart: row['flat_series_start'] as String?,
      flatSeriesEnd: row['flat_series_end'] as String?,
      blockNames: blocks is List ? blocks.cast<String>() : const [],
    );
  }

  Future<void> saveLayout({
    required String societyId,
    required int totalFloors,
    required String flatSeriesStart,
    required String flatSeriesEnd,
    required List<String> blockNames,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('societies').update({
      'total_floors': totalFloors,
      'flat_series_start': flatSeriesStart.trim(),
      'flat_series_end': flatSeriesEnd.trim(),
      'block_names': blockNames.map((b) => b.trim().toUpperCase()).where((b) => b.isNotEmpty).toList(),
    }).eq('id', societyId);
  }

  Future<FlatGenerateResult> generateFromLayout(String societyId) async {
    if (!Env.isConfigured) {
      return const FlatGenerateResult(created: 0, skipped: 0, error: 'Not configured');
    }

    final row = await SupabaseBootstrap.client
        .from('societies')
        .select('total_floors, flat_series_start, flat_series_end, block_names')
        .eq('id', societyId)
        .maybeSingle();
    if (row == null) {
      return const FlatGenerateResult(created: 0, skipped: 0, error: 'Society not found');
    }

    final range = layoutFromSocietyRow(Map<String, dynamic>.from(row));
    if (range == null) {
      return const FlatGenerateResult(
        created: 0,
        skipped: 0,
        error: 'Invalid layout (need floors ≥ 1 and flat series e.g. 101–105)',
      );
    }

    final blockNames = row['block_names'];
    final wings = blockNames is List && blockNames.isNotEmpty
        ? blockNames.map((w) => wingKey(w as String?)).where((w) => w.isNotEmpty).toList()
        : <String>[];
    final wingList = wings.isEmpty ? <String?>[null] : wings.map<String?>((w) => w).toList();

    final existing = await SupabaseBootstrap.client
        .from('flats')
        .select('flat_number, wing')
        .eq('society_id', societyId);

    final existingRows = (existing as List).cast<Map<String, dynamic>>();
    final hasWinged = existingRows.any((r) => wingKey(r['wing'] as String?).isNotEmpty);
    final hasUnwinged = existingRows.any((r) => wingKey(r['wing'] as String?).isEmpty);
    final wantsWinged = wingList.any((w) => wingKey(w).isNotEmpty);
    final wantsUnwinged = wingList.any((w) => wingKey(w).isEmpty);
    if ((hasWinged && wantsUnwinged) || (hasUnwinged && wantsWinged)) {
      return const FlatGenerateResult(
        created: 0,
        skipped: 0,
        error: 'Wing mode conflict — clean old flats or align block names first',
      );
    }

    final taken = <String>{};
    for (final r in existingRows) {
      taken.add('${(r['flat_number'] as String).trim()}|${wingKey(r['wing'] as String?)}');
    }

    final sortedNumbers = range.valid.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    final inserts = <Map<String, dynamic>>[];
    var skipped = 0;

    for (final wing in wingList) {
      final wStored = wingKey(wing).isEmpty ? null : wingKey(wing);
      for (final num in sortedNumbers) {
        final key = '$num|${wStored ?? ''}';
        if (taken.contains(key)) {
          skipped++;
          continue;
        }
        taken.add(key);
        inserts.add({
          'society_id': societyId,
          'flat_number': num,
          'wing': wStored,
          'floor': floorLabelFromFlatNumber(num),
          'flat_type': 'residential',
          'is_occupied': false,
        });
      }
    }

    if (inserts.isEmpty) {
      return FlatGenerateResult(created: 0, skipped: skipped);
    }

    var created = 0;
    const chunk = 250;
    for (var i = 0; i < inserts.length; i += chunk) {
      final end = i + chunk < inserts.length ? i + chunk : inserts.length;
      final part = inserts.sublist(i, end);
      await SupabaseBootstrap.client.from('flats').insert(part);
      created += part.length;
    }

    return FlatGenerateResult(created: created, skipped: skipped);
  }
}
