class FlatMember {
  const FlatMember({
    required this.id,
    required this.name,
    required this.flatId,
    this.phone,
    this.relation,
    this.age,
    this.photo,
    this.isPrimary = false,
    this.householdGroup = 'family',
  });

  final String id;
  final String name;
  final String flatId;
  final String? phone;
  final String? relation;
  final int? age;
  final String? photo;
  final bool isPrimary;
  final String householdGroup;

  factory FlatMember.fromRow(Map<String, dynamic> row) => FlatMember(
        id: row['id'] as String,
        name: row['name'] as String,
        flatId: row['flat_id'] as String,
        phone: row['phone'] as String?,
        relation: row['relation'] as String?,
        age: row['age'] as int?,
        photo: row['photo'] as String?,
        isPrimary: row['is_primary'] as bool? ?? false,
        householdGroup: row['household_group'] as String? ?? 'family',
      );
}
