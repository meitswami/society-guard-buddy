class BuiltFlatRange {
  const BuiltFlatRange({
    required this.valid,
    required this.floorBase,
    required this.floors,
  });

  final Set<String> valid;
  final int floorBase;
  final int floors;
}

BuiltFlatRange? buildValidFlatNumberSet({
  required int totalFloors,
  required String flatSeriesStart,
  required String flatSeriesEnd,
}) {
  final start = int.tryParse(flatSeriesStart.trim());
  final end = int.tryParse(flatSeriesEnd.trim());
  if (start == null || end == null || end < start || totalFloors < 1) return null;

  final floorBase = start ~/ 100;
  if (end ~/ 100 != floorBase) return null;

  final uStart = start - floorBase * 100;
  final nUnits = end - start + 1;
  if (nUnits < 1) return null;

  final valid = <String>{};
  for (var i = 0; i < totalFloors; i++) {
    final prefix = floorBase + i;
    for (var j = 0; j < nUnits; j++) {
      valid.add('${prefix * 100 + uStart + j}');
    }
  }
  return BuiltFlatRange(valid: valid, floorBase: floorBase, floors: totalFloors);
}

BuiltFlatRange? layoutFromSocietyRow(Map<String, dynamic> row) {
  final floors = row['total_floors'] as int?;
  final start = row['flat_series_start'] as String?;
  final end = row['flat_series_end'] as String?;
  if (floors == null || floors < 1 || start == null || end == null) return null;
  if (start.trim().isEmpty || end.trim().isEmpty) return null;
  return buildValidFlatNumberSet(
    totalFloors: floors,
    flatSeriesStart: start,
    flatSeriesEnd: end,
  );
}

String? floorLabelFromFlatNumber(String flatNumber) {
  final digits = flatNumber.trim().replaceAll(RegExp(r'\D'), '');
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

String wingKey(String? wing) => (wing ?? '').trim().toUpperCase();
