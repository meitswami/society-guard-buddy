/// Models for `notifications`, `notification_comments` and media items
/// (web `NotificationDetailModal.tsx` / `Tables<'notifications'>`).
library;

class NotificationMediaItem {
  const NotificationMediaItem({required this.url, required this.kind});

  final String url;

  /// `image` | `video`
  final String kind;

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';

  Map<String, String> toJson() => {'url': url, 'kind': kind};

  @override
  bool operator ==(Object other) => other is NotificationMediaItem && other.url == url && other.kind == kind;

  @override
  int get hashCode => Object.hash(url, kind);
}

/// Web `parseNotificationMedia`: keeps `{url: string, kind: 'image'|'video'}` entries only.
List<NotificationMediaItem> parseNotificationMedia(Object? raw) {
  if (raw is! List) return const [];
  final out = <NotificationMediaItem>[];
  for (final x in raw) {
    if (x is! Map) continue;
    final url = x['url'];
    final kind = x['kind'];
    if (url is! String) continue;
    if (kind != 'image' && kind != 'video') continue;
    out.add(NotificationMediaItem(url: url, kind: kind as String));
  }
  return out;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetType,
    required this.createdAt,
    this.targetId,
    this.createdBy,
    this.isRead = false,
    this.readAt,
    this.societyId,
    this.soundKey = 'digital',
    this.soundCustomUrl,
    this.media = const [],
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String targetType;
  final String? targetId;
  final String createdAt;
  final String? createdBy;
  final bool isRead;
  final String? readAt;
  final String? societyId;
  final String soundKey;
  final String? soundCustomUrl;
  final List<NotificationMediaItem> media;

  factory AppNotification.fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        message: r['message']?.toString() ?? '',
        type: r['type']?.toString() ?? 'general',
        targetType: r['target_type']?.toString() ?? 'all',
        targetId: r['target_id']?.toString(),
        createdAt: r['created_at']?.toString() ?? '',
        createdBy: r['created_by']?.toString(),
        isRead: r['is_read'] == true,
        readAt: r['read_at']?.toString(),
        societyId: r['society_id']?.toString(),
        soundKey: r['sound_key']?.toString() ?? 'digital',
        soundCustomUrl: r['sound_custom_url']?.toString(),
        media: parseNotificationMedia(r['media_items']),
      );

  AppNotification copyWith({bool? isRead, String? readAt}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        targetType: targetType,
        targetId: targetId,
        createdAt: createdAt,
        createdBy: createdBy,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        societyId: societyId,
        soundKey: soundKey,
        soundCustomUrl: soundCustomUrl,
        media: media,
      );
}

class NotificationComment {
  const NotificationComment({
    required this.id,
    required this.notificationId,
    required this.authorRole,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorResidentId,
    this.authorFlatNumber,
  });

  final String id;
  final String notificationId;

  /// `resident` | `admin`
  final String authorRole;
  final String? authorResidentId;
  final String authorName;
  final String? authorFlatNumber;
  final String body;
  final String createdAt;

  bool get isAdmin => authorRole == 'admin';

  factory NotificationComment.fromRow(Map<String, dynamic> r) => NotificationComment(
        id: r['id']?.toString() ?? '',
        notificationId: r['notification_id']?.toString() ?? '',
        authorRole: r['author_role']?.toString() ?? 'resident',
        authorResidentId: r['author_resident_id']?.toString(),
        authorName: r['author_name']?.toString() ?? '',
        authorFlatNumber: r['author_flat_number']?.toString(),
        body: r['body']?.toString() ?? '',
        createdAt: r['created_at']?.toString() ?? '',
      );
}

/// Who is reading a notification (web `ResidentRef`).
class ResidentRef {
  const ResidentRef({required this.id, required this.name, required this.flatNumber});

  final String id;
  final String name;
  final String flatNumber;
}

/// Insert payload for `notification_comments` (web `sendComment`).
Map<String, dynamic> buildCommentRow({
  required String notificationId,
  required String body,
  required bool isResident,
  ResidentRef? resident,
  String adminName = 'Admin',
}) {
  if (isResident) {
    return {
      'notification_id': notificationId,
      'author_role': 'resident',
      'author_resident_id': resident?.id,
      'author_name': resident?.name ?? '',
      'author_flat_number': resident?.flatNumber,
      'body': body,
    };
  }
  return {
    'notification_id': notificationId,
    'author_role': 'admin',
    'author_resident_id': null,
    'author_name': adminName,
    'author_flat_number': null,
    'body': body,
  };
}
