class ResidentVehicle {
  const ResidentVehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.residentName,
    required this.flatNumber,
    this.flatId,
    this.memberId,
  });

  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String residentName;
  final String flatNumber;
  final String? flatId;
  final String? memberId;

  factory ResidentVehicle.fromRow(Map<String, dynamic> row) => ResidentVehicle(
        id: row['id'] as String,
        vehicleNumber: row['vehicle_number'] as String,
        vehicleType: row['vehicle_type'] as String? ?? 'car',
        residentName: row['resident_name'] as String,
        flatNumber: row['flat_number'] as String,
        flatId: row['flat_id'] as String?,
        memberId: row['member_id'] as String?,
      );
}
