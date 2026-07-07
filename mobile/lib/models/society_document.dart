class SocietyDocument {
  const SocietyDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.storagePath,
    required this.fileName,
    required this.createdAt,
    this.description,
    this.mimeType,
    this.memberRevealUntil,
  });

  final String id;
  final String title;
  final String category;
  final String storagePath;
  final String fileName;
  final String createdAt;
  final String? description;
  final String? mimeType;
  final String? memberRevealUntil;

  bool isRevealActive(DateTime now) {
    if (memberRevealUntil == null || memberRevealUntil!.isEmpty) return false;
    final until = DateTime.tryParse(memberRevealUntil!);
    if (until == null) return false;
    return until.isAfter(now);
  }

  int revealSecondsLeft(DateTime now) {
    if (memberRevealUntil == null || memberRevealUntil!.isEmpty) return 0;
    final until = DateTime.tryParse(memberRevealUntil!);
    if (until == null) return 0;
    final left = until.difference(now).inSeconds;
    return left > 0 ? left : 0;
  }

  bool get isImage {
    if (mimeType != null && mimeType!.startsWith('image/')) return true;
    return RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(fileName);
  }

  bool get isPdf {
    if (mimeType == 'application/pdf') return true;
    return fileName.toLowerCase().endsWith('.pdf');
  }

  factory SocietyDocument.fromRow(Map<String, dynamic> row) => SocietyDocument(
        id: row['id'] as String,
        title: row['title'] as String,
        category: row['category'] as String? ?? 'other',
        storagePath: row['storage_path'] as String,
        fileName: row['file_name'] as String,
        createdAt: row['created_at'] as String,
        description: row['description'] as String?,
        mimeType: row['mime_type'] as String?,
        memberRevealUntil: row['member_reveal_until'] as String?,
      );

  SocietyDocument copyWith({String? memberRevealUntil}) => SocietyDocument(
        id: id,
        title: title,
        category: category,
        storagePath: storagePath,
        fileName: fileName,
        createdAt: createdAt,
        description: description,
        mimeType: mimeType,
        memberRevealUntil: memberRevealUntil ?? this.memberRevealUntil,
      );
}

const societyDocumentCategories = <String, String>{
  'bylaws': 'Bylaws & rules',
  'minutes': 'Meeting minutes',
  'notices': 'Notices & circulars',
  'reports': 'Reports',
  'forms': 'Forms',
  'other': 'Other',
};
