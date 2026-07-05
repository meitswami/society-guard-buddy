class ResidentUser {
  const ResidentUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatId,
    required this.flatNumber,
  });

  final String id;
  final String name;
  final String phone;
  final String flatId;
  final String flatNumber;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'flatId': flatId,
        'flatNumber': flatNumber,
      };

  factory ResidentUser.fromJson(Map<String, dynamic> json) => ResidentUser(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        flatId: json['flatId'] as String,
        flatNumber: json['flatNumber'] as String,
      );

  factory ResidentUser.fromRow(Map<String, dynamic> row) => ResidentUser(
        id: row['id'] as String,
        name: row['name'] as String,
        phone: row['phone'] as String,
        flatId: row['flat_id'] as String,
        flatNumber: row['flat_number'] as String,
      );
}
