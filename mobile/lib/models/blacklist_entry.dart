class BlacklistEntry {
  const BlacklistEntry({
    required this.id,
    required this.type,
    required this.reason,
    required this.addedAt,
    required this.addedBy,
    this.name,
    this.phone,
    this.vehicleNumber,
  });

  final String id;
  final String type;
  final String reason;
  final String addedAt;
  final String addedBy;
  final String? name;
  final String? phone;
  final String? vehicleNumber;

  factory BlacklistEntry.fromRow(Map<String, dynamic> row) => BlacklistEntry(
        id: row['id'] as String,
        type: row['type'] as String? ?? 'visitor',
        reason: row['reason'] as String,
        addedAt: row['added_at'] as String? ?? row['created_at'] as String? ?? '',
        addedBy: row['added_by'] as String? ?? 'Unknown',
        name: row['name'] as String?,
        phone: row['phone'] as String?,
        vehicleNumber: row['vehicle_number'] as String?,
      );
}
