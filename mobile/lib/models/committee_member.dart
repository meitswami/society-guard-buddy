class CommitteeMember {
  const CommitteeMember({
    required this.id,
    required this.name,
    required this.position,
    this.flatNumber,
    this.phone,
    this.photo,
    this.repName,
    this.repPhone,
    this.repPhoto,
    this.showRepresentative = false,
    this.termFrom,
    this.termTo,
  });

  final String id;
  final String name;
  final String position;
  final String? flatNumber;
  final String? phone;
  final String? photo;
  final String? repName;
  final String? repPhone;
  final String? repPhoto;
  final bool showRepresentative;
  final String? termFrom;
  final String? termTo;

  factory CommitteeMember.fromRow(Map<String, dynamic> row) => CommitteeMember(
        id: row['id'] as String,
        name: row['name'] as String,
        position: row['position'] as String,
        flatNumber: row['flat_number'] as String?,
        phone: row['phone'] as String?,
        photo: row['photo'] as String?,
        repName: row['rep_name'] as String?,
        repPhone: row['rep_phone'] as String?,
        repPhoto: row['rep_photo'] as String?,
        showRepresentative: row['show_representative'] as bool? ?? false,
        termFrom: row['term_from'] as String?,
        termTo: row['term_to'] as String?,
      );
}
