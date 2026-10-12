/// Society flat layout helpers — port of web `src/lib/flatFloor.ts`,
/// `src/lib/societyFlatRangeTrim.ts` and the planning part of
/// `src/lib/societyFlatsFromLayout.ts`.
///
/// Numbering model (common in India): each residential tier advances by +100,
/// e.g. range 101–105 over 3 floors → 101–105, 201–205, 301–305.
library;

/// JavaScript `parseInt(s, 10)`: leading optional sign + digits after trimming,
/// ignoring any trailing junk (`'101A'` → 101). Returns null for `NaN`.
int? jsParseInt(String? input) {
  if (input == null) return null;
  final m = RegExp(r'^[+-]?\d+').firstMatch(input.trim());
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

/// Maps 3-digit flat numbers like 101–199 → 1st Floor, … 601–699 → 6th Floor
/// (first digit = floor index). Returns null if the pattern does not apply.
String? floorLabelFromFlatNumber(String flatNumber) {
  final raw = flatNumber.trim();
  if (raw.isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^[1-6]\d{2}$').hasMatch(digits)) return null;
  final n = int.parse(digits[0]);
  const labels = {
    1: '1st Floor',
    2: '2nd Floor',
    3: '3rd Floor',
    4: '4th Floor',
    5: '5th Floor',
    6: '6th Floor',
  };
  return labels[n];
}

/// Wing comparison key (`trim().toUpperCase()`).
String wingKey(String? wing) => (wing ?? '').trim().toUpperCase();

/// Society row fields used to derive expected numeric flat numbers (web `SocietyFlatRangeInput`).
class SocietyFlatRangeInput {
  const SocietyFlatRangeInput({
    required this.totalFloors,
    required this.flatSeriesStart,
    required this.flatSeriesEnd,
    this.blockNames,
  });

  final int? totalFloors;
  final String? flatSeriesStart;
  final String? flatSeriesEnd;
  final List<String>? blockNames;

  factory SocietyFlatRangeInput.fromRow(Map<String, dynamic> row) {
    final blocks = row['block_names'];
    final floors = row['total_floors'];
    return SocietyFlatRangeInput(
      totalFloors: floors is int
          ? floors
          : (floors is num ? floors.toInt() : int.tryParse('${floors ?? ''}')),
      flatSeriesStart: row['flat_series_start']?.toString(),
      flatSeriesEnd: row['flat_series_end']?.toString(),
      blockNames: blocks is List ? blocks.map((e) => '$e').toList() : null,
    );
  }

  Map<String, dynamic> toRow() => {
        'total_floors': totalFloors,
        'flat_series_start': flatSeriesStart,
        'flat_series_end': flatSeriesEnd,
        'block_names': blockNames,
      };
}

/// Web `BuiltFlatRange`.
class BuiltFlatRange {
  const BuiltFlatRange({
    required this.valid,
    required this.floorBase,
    required this.floors,
    this.uStart = 0,
    this.nUnits = 0,
    this.maxTrimUnit = 0,
  });

  final Set<String> valid;
  final int floorBase;
  final int floors;
  final int uStart;
  final int nUnits;
  final int maxTrimUnit;

  /// Flat numbers sorted numerically (`parseInt(a) - parseInt(b)`).
  List<String> get sortedNumbers =>
      valid.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
}

/// Builds the set of valid flat numbers (e.g. 101–105 on tier 1, 201–205 on tier 2, …).
/// Assumes each residential tier advances by +100.
BuiltFlatRange? buildValidFlatNumberSet({
  required int totalFloors,
  required String flatSeriesStart,
  required String flatSeriesEnd,
}) {
  final start = jsParseInt(flatSeriesStart);
  final end = jsParseInt(flatSeriesEnd);
  final floors = totalFloors;
  if (start == null || end == null || end < start || floors < 1) return null;

  final floorBase = (start / 100).floor();
  final endFloorBase = (end / 100).floor();
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

  final maxTrimUnit = uStart + nUnits + 3;
  return BuiltFlatRange(
    valid: valid,
    floorBase: floorBase,
    floors: floors,
    uStart: uStart,
    nUnits: nUnits,
    maxTrimUnit: maxTrimUnit,
  );
}

bool _wingAllowedForTrim(String? wing, List<String>? blockNames) {
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

bool _isResidentialFlatType(String? flatType) =>
    (flatType ?? 'residential') == 'residential';

/// True if this flat row should be removed: on a configured tier, unit looks like a mistaken
/// extra in the same band (e.g. 106 when range is 101–105), but not odd numbers like shop 150.
bool flatRowShouldTrim({
  required String flatNumber,
  required String? wing,
  required String? flatType,
  required BuiltFlatRange range,
  required List<String>? blockNames,
}) {
  if (!_isResidentialFlatType(flatType)) return false;
  if (!_wingAllowedForTrim(wing, blockNames)) return false;

  final raw = flatNumber.trim();
  if (!RegExp(r'^\d+$').hasMatch(raw)) return false;

  final n = int.tryParse(raw);
  if (n == null) return false;

  if (range.valid.contains('$n')) return false;

  final floorPrefix = (n / 100).floor();
  if (floorPrefix < range.floorBase ||
      floorPrefix > range.floorBase + range.floors - 1) {
    return false;
  }

  final unit = n - floorPrefix * 100;
  if (unit < range.uStart || unit > range.maxTrimUnit) return false;

  return true;
}

/// Web `canTrimFlatsFromSocietyRow`.
BuiltFlatRange? canTrimFlatsFromSocietyRow(SocietyFlatRangeInput row) {
  final floors = row.totalFloors;
  if (floors == null || floors < 1) return null;
  final start = row.flatSeriesStart?.trim() ?? '';
  final end = row.flatSeriesEnd?.trim() ?? '';
  if (start.isEmpty || end.isEmpty) return null;
  return buildValidFlatNumberSet(
    totalFloors: floors,
    flatSeriesStart: row.flatSeriesStart!,
    flatSeriesEnd: row.flatSeriesEnd!,
  );
}

/// Back-compat helper for raw `societies` rows.
BuiltFlatRange? layoutFromSocietyRow(Map<String, dynamic> row) =>
    canTrimFlatsFromSocietyRow(SocietyFlatRangeInput.fromRow(row));

/// Wings to generate for (`block_names` upper-cased, or a single tower `null`).
List<String?> layoutWings(List<String>? blockNames) {
  if (blockNames != null && blockNames.isNotEmpty) {
    return blockNames
        .map((w) => w.trim().toUpperCase())
        .where((w) => w.isNotEmpty)
        .toList();
  }
  return const [null];
}

/// Minimal existing flat row used for planning.
class ExistingFlatKey {
  const ExistingFlatKey(this.flatNumber, this.wing);

  final String flatNumber;
  final String? wing;
}

/// Result of [planFlatsFromLayout] — rows to insert, skipped count, or an error message.
class FlatGenerationPlan {
  const FlatGenerationPlan(
      {required this.rows, required this.skipped, this.error});

  final List<Map<String, dynamic>> rows;
  final int skipped;
  final String? error;
}

const kInvalidLayoutError =
    'Invalid flat layout (need total floors ≥ 1 and a valid flat series on one hundred-band, e.g. 101–111).';
const kWingModeConflictError =
    'Flat generation halted to avoid duplicates: existing flats use a different wing mode (single tower vs A/B wings). Clean old rows for this society first, then save again.';

/// Pure planning step of web `upsertSocietyFlatsFromLayout`: which `flats` rows are
/// missing for the layout (idempotent: skips flat_number+wing pairs already present).
FlatGenerationPlan planFlatsFromLayout({
  required String societyId,
  required SocietyFlatRangeInput row,
  required List<ExistingFlatKey> existing,
}) {
  if (societyId.isEmpty)
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: 'Missing society id');

  final range = canTrimFlatsFromSocietyRow(row);
  if (range == null)
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: kInvalidLayoutError);

  final wings = layoutWings(row.blockNames);
  final sortedNumbers = range.sortedNumbers;

  // Guard against accidental double-generation when switching between single-tower
  // mode (no wing) and multi-wing mode (A/B/...) without cleaning old rows first.
  final hasExistingWinged = existing.any((r) => wingKey(r.wing).isNotEmpty);
  final hasExistingUnwinged = existing.any((r) => wingKey(r.wing).isEmpty);
  final wantsWinged = wings.any((w) => wingKey(w).isNotEmpty);
  final wantsUnwinged = wings.any((w) => wingKey(w).isEmpty);
  if ((hasExistingWinged && wantsUnwinged) ||
      (hasExistingUnwinged && wantsWinged)) {
    return const FlatGenerationPlan(
        rows: [], skipped: 0, error: kWingModeConflictError);
  }

  final taken = <String>{};
  for (final r in existing) {
    taken.add('${r.flatNumber.trim()}|${wingKey(r.wing)}');
  }

  final rows = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final wing in wings) {
    final k = wingKey(wing);
    final wStored = k.isEmpty ? null : k;
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

/// Parse a blocks CSV the same way as the superadmin form (`split(/[,;]+/)`).
List<String> parseBlockNamesCsv(String csv) => csv
    .split(RegExp(r'[,;]+'))
    .map((x) => x.trim())
    .where((x) => x.isNotEmpty)
    .toList();
