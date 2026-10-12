import '../logic/document_logic.dart';

String? _s(Object? v) => v == null ? null : '$v';

/// Row of `society_documents`.
class SocietyDocumentRow {
  const SocietyDocumentRow({
    required this.id,
    required this.societyId,
    required this.title,
    required this.category,
    required this.storagePath,
    required this.fileName,
    required this.published,
    required this.sortOrder,
    required this.createdAt,
    this.description,
    this.mimeType,
    this.memberRevealUntil,
    this.uploadedBy,
    this.updatedAt,
  });

  final String id;
  final String societyId;
  final String title;
  final String? description;
  final SocietyDocCategory category;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final bool published;
  final String? memberRevealUntil;
  final int sortOrder;
  final String? uploadedBy;
  final String createdAt;
  final String? updatedAt;

  bool get isImage => isImageDoc(mimeType: mimeType, fileName: fileName);

  bool revealActive(DateTime now) => isRevealActive(memberRevealUntil, now);

  int secondsLeft(DateTime now) => revealSecondsLeft(memberRevealUntil, now);

  factory SocietyDocumentRow.fromJson(Map<String, dynamic> j) =>
      SocietyDocumentRow(
        id: '${j['id']}',
        societyId: '${j['society_id'] ?? ''}',
        title: (j['title'] ?? '').toString(),
        description: _s(j['description']),
        category: SocietyDocCategory.parse(j['category']),
        storagePath: (j['storage_path'] ?? '').toString(),
        fileName: (j['file_name'] ?? '').toString(),
        mimeType: _s(j['mime_type']),
        published: j['published'] == true,
        memberRevealUntil: _s(j['member_reveal_until']),
        sortOrder:
            j['sort_order'] is num ? (j['sort_order'] as num).toInt() : 0,
        uploadedBy: _s(j['uploaded_by']),
        createdAt: (j['created_at'] ?? '').toString(),
        updatedAt: _s(j['updated_at']),
      );

  /// `{...d, ...updated}` from a realtime UPDATE payload.
  SocietyDocumentRow merge(Map<String, dynamic> patch) {
    final base = <String, dynamic>{
      'id': id,
      'society_id': societyId,
      'title': title,
      'description': description,
      'category': category.value,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'published': published,
      'member_reveal_until': memberRevealUntil,
      'sort_order': sortOrder,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    return SocietyDocumentRow.fromJson({...base, ...patch});
  }
}
