import 'js_compat.dart';

/// Pure ports of `src/lib/societyFlatRangeTrim.ts`, `src/lib/societyFlatsFromLayout.ts`
/// and `src/lib/flatFloor.ts` used when the Superadmin saves a society layout.

/// Society row fields used to derive expected numeric flat numbers (101–105, 201–205, …).
class SocietyLayoutInput {
  const SocietyLayoutInput({
    required this.totalFloors,
    required this.flatSeriesStart,
    required this.flatSeriesEnd,
    required this.blockNames,
  });

  final int? totalFloors;
  final String? flatSeriesStart;
  final String? flatSeriesEnd;
  final List<String>? blockNames;
}

class BuiltFlatRange {
  const BuiltFlatRange({
    required this.valid,
    required this.floorBase,
    required this.floors,
    required this.uStart,
    required this.nUnits,
    required this.maxTrimUnit,
  });

  final Set<String> valid;
  final int floorBase;
  final int floors;
  final int uStart;
  final int nUnits;
  final int maxTrimUnit;
}

int _floorDiv100(int n) => (n / 100).floor();

/// Web `buildValidFlatNumberSet` — every tier advances by +100 (Indian numbering).
BuiltFlatRange? buildValidFlatNumberSet({
  required int totalFloors,
  required String flatSeriesStart,
  required String flatSeriesEnd,
}) {
  final start = jsParseInt(flatSeriesStart.trim());
  final end = jsParseInt(flatSeriesEnd.trim());
  final floors = totalFloors;
  if (start == null || end == null || end < start || floors < 1) return null;

  final floorBase = _floorDiv100(start);
  final endFloorBase = _floorDiv100(end);
  if (endFloorBase != floorBase) return null;

  final uStart = start - floorBase * 100;
  final nUnits = end - start + 1;
  if (nUnits < 1) return null;

  final valid = <String>{};
  for (var i = 0; i < floors; i++) {
    final prefix = floorBase + i;
    for (var j = 0; j < nUnits; j++) {
      valid.add('${prefix * 100 + uStart + j}');
    }
  }
  return BuiltFlatRange(
    valid: valid,
    floorBase: floorBase,
    floors: floors,
    uStart: uStart,
    nUnits: nUnits,
    maxTrimUnit: uStart + nUnits + 3,
  );
}

bool wingAllowedForTrim(String? wing, List<String>? blockNames) {
  if (blockNames == null || blockNames.isEmpty) return true;
  final set = blockNames
      .map((b) => b.trim().toLowerCase())
      .where((b) => b.isNotEmpty)
      .toSet();
  final w = (wing ?? '').trim().toLowerCase();
  if (w.isNotEmpty && set.contains(w)) return true;
  if (w.isEmpty && set.length == 1) return true;
  return false;
}

bool isResidentialFlatType(String? flatType) =>
    (flatType ?? 'residential') == 'residential';

/// Web `flatRowShouldTrim`: on a configured tier, the unit looks like a mistaken extra in
/// the same band (e.g. 106 when the range is 101–105) — but not odd numbers like shop 150.
bool flatRowShouldTrim({
  required String flatNumber,
  required String? wing,
  required String? flatType,
  required BuiltFlatRange range,
  required List<String>? blockNames,
}) {
  if (!isResidentialFlatType(flatType)) return false;
  if (!wingAllowedForTrim(wing, blockNames)) return false;

  final raw = flatNumber.trim();
  if (!RegExp(r'^\d+$').hasMatch(raw)) return false;
  final n = int.tryParse(raw);
  if (n == null) return false;
  if (range.valid.contains('$n')) return false;

  final floorPrefix = _floorDiv100(n);
  if (floorPrefix < range.floorBase ||
      floorPrefix > range.floorBase + range.floors - 1) {
    return false;
  }

  final unit = n - floorPrefix * 100;
  if (unit < range.uStart || unit > range.maxTrimUnit) return false;
  return true;
}

/// Web `canTrimFlatsFromSocietyRow`.
BuiltFlatRange? canTrimFlatsFromSocietyRow(SocietyLayoutInput row) {
  final floors = row.totalFloors;
  if (floors == null || floors < 1) return null;
  final start = row.flatSeriesStart?.trim() ?? '';
  final end = row.flatSeriesEnd?.trim() ?? '';
  if (start.isEmpty || end.isEmpty) return null;
  return buildValidFlatNumberSet(
      totalFloors: floors, flatSeriesStart: start, flatSeriesEnd: end);
}

/// A `flats` row as read for trimming / generation.
class ExistingFlat {
  const ExistingFlat(
      {this.id, required this.flatNumber, this.wing, this.flatType});

  final String? id;
  final String flatNumber;
  final String? wing;
  final String? flatType;
}

/// Ids of flats `trimSocietyFlatsToConfiguredRange` deletes (empty when the layout is unusable).
List<String> flatIdsToTrim(SocietyLayoutInput row, List<ExistingFlat> flats) {
  final range = canTrimFlatsFromSocietyRow(row);
  if (range == null) return const [];
  return [
    for (final f in flats)
      if (f.id != null &&
          flatRowShouldTrim(
            flatNumber: f.flatNumber,
            wing: f.wing,
            flatType: f.flatType,
            range: range,
            blockNames: row.blockNames,
          ))
        f.id!,
  ];
}

/// Web `floorLabelFromFlatNumber`: 101–199 → "1st Floor" … 601–699 → "6th Floor".
String? floorLabelFromFlatNumber(String flatNumber) {
  final raw = flatNumber.trim();
  if (raw.isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^[1-6]\d{2}$').hasMatch(digits)) return null;
  const labels = {
    1: '1st Floor',
    2: '2nd Floor',
    3: '3rd Floor',
    4: '4th Floor',
    5: '5th Floor',
    6: '6th Floor',
  };
  return labels[int.parse(digits[0])];
}

String wingKey(String? wing) => (wing ?? '').trim().toUpperCase();

const String kInvalidFlatLayoutError =
    'Invalid flat layout (need total floors ≥ 1 and a valid flat series on one hundred-band, e.g. 101–111).';
const String kWingModeConflictError =
    'Flat generation halted to avoid duplicates: existing flats use a different wing mode (single tower vs A/B wings). Clean old rows for this society first, then save again.';

/// Result of planning `upsertSocietyFlatsFromLayout` (inserts happen in the repository).
class FlatGenerationPlan {
  const FlatGenerationPlan(
      {required this.rows, required this.skipped, this.error});

  final List<Map<String, dynamic>> rows;
  final int skipped;
  final String? error;
}

/// Web `upsertSocietyFlatsFromLayout` minus the DB calls: which `flats` rows to insert.
FlatGenerationPlan planFlatsFromLayout(
    String societyId, SocietyLayoutInput row, List<ExistingFlat> existing) {
  if (societyId.isEmpty) {
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: 'Missing society id');
  }
  final range = canTrimFlatsFromSocietyRow(row);
  if (range == null) {
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: kInvalidFlatLayoutError);
  }

  final blocks = row.blockNames;
  final List<String?> wings = (blocks != null && blocks.isNotEmpty)
      ? blocks
          .map((w) => w.trim().toUpperCase())
          .where((w) => w.isNotEmpty)
          .toList()
      : <String?>[null];

  final sortedNumbers = range.valid.toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

  final hasExistingWinged = existing.any((r) => wingKey(r.wing).isNotEmpty);
  final hasExistingUnwinged = existing.any((r) => wingKey(r.wing).isEmpty);
  final wantsWinged = wings.any((w) => wingKey(w).isNotEmpty);
  final wantsUnwinged = wings.any((w) => wingKey(w).isEmpty);
  if ((hasExistingWinged && wantsUnwinged) ||
      (hasExistingUnwinged && wantsWinged)) {
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: kWingModeConflictError);
  }

  final taken = <String>{
    for (final r in existing) '${r.flatNumber.trim()}|${wingKey(r.wing)}'
  };
  final rows = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final wing in wings) {
    final k = wingKey(wing);
    final String? wStored = k.isEmpty ? null : k;
    for (final num in sortedNumbers) {
      final key = '$num|${wStored ?? ''}';
      if (taken.contains(key)) {
        skipped++;
        continue;
      }
      taken.add(key);
      rows.add({
        'society_id': societyId,
        'flat_number': num,
        'wing': wStored,
        'floor': floorLabelFromFlatNumber(num),
        'flat_type': 'residential',
        'is_occupied': false,
      });
    }
  }
  return FlatGenerationPlan(rows: rows, skipped: skipped);
}

/// Splits a list into chunks (web inserts 250 / deletes 200 per request).
List<List<T>> chunked<T>(List<T> items, int size) => [
      for (var i = 0; i < items.length; i += size)
        items.sublist(i, i + size > items.length ? items.length : i + size),
    ];
