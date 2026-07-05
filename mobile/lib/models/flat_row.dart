class FlatRow {
  const FlatRow({required this.id, required this.flatNumber});

  final String id;
  final String flatNumber;

  factory FlatRow.fromRow(Map<String, dynamic> row) => FlatRow(
        id: row['id'] as String,
        flatNumber: row['flat_number'] as String? ?? '',
      );
}
