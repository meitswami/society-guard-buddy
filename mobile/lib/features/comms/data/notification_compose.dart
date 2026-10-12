/// Pure port of the compose / send rules in `NotificationCenter.tsx` (`sendNotification`,
/// `onPickFiles`, `uploadNotificationMedia`) and `adminRecordNotifications.ts`.
library;

import 'notification_models.dart';

enum NotificationTargetMode { all, flat, user }

/// Web `MAX_ATTACHMENTS`, `MAX_IMAGE_BYTES`, `MAX_VIDEO_BYTES`.
const int kMaxNotificationAttachments = 8;
const int kMaxNotificationImageBytes = 12 * 1024 * 1024;
const int kMaxNotificationVideoBytes = 50 * 1024 * 1024;

/// Society alert sound upload limit (web: 2 MB, `audio/*`).
const int kMaxSocietySoundBytes = 2 * 1024 * 1024;

const _imageExt = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'svg'
};
const _videoExt = {'mp4', 'webm', 'mov', 'm4v', '3gp', 'mkv', 'avi', 'qt'};
const _audioExt = {
  'mp3',
  'wav',
  'ogg',
  'oga',
  'm4a',
  'aac',
  'flac',
  'opus',
  'amr',
  'weba'
};

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

/// Web `fileMediaKind`: `image/*` → image, `video/*` → video. On mobile the picker may not
/// report a MIME type, so the file extension is used as a fallback.
String? fileMediaKind({String? mimeType, required String fileName}) {
  final m = (mimeType ?? '').toLowerCase();
  if (m.startsWith('image/')) return 'image';
  if (m.startsWith('video/')) return 'video';
  final e = _ext(fileName);
  if (_imageExt.contains(e)) return 'image';
  if (_videoExt.contains(e)) return 'video';
  return null;
}

bool isAudioFile({String? mimeType, required String fileName}) {
  final m = (mimeType ?? '').toLowerCase();
  if (m.startsWith('audio/')) return true;
  return _audioExt.contains(_ext(fileName));
}

/// Best-effort content type for uploads (web passes `file.type`).
String? guessContentType(String fileName, {String? mimeType}) {
  if (mimeType != null && mimeType.isNotEmpty) return mimeType;
  switch (_ext(fileName)) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'bmp':
      return 'image/bmp';
    case 'svg':
      return 'image/svg+xml';
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'webm':
      return 'video/webm';
    case 'mov':
    case 'qt':
      return 'video/quicktime';
    case '3gp':
      return 'video/3gpp';
    case 'mkv':
      return 'video/x-matroska';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';
    case 'opus':
      return 'audio/opus';
    case 'amr':
      return 'audio/amr';
    case 'pdf':
      return 'application/pdf';
    default:
      return null;
  }
}

/// Size check before upload (web `uploadNotificationMedia`): returns null when ok, else
/// `image` / `video` for the limit that was exceeded.
String? mediaSizeViolation(String kind, int bytes) {
  if (kind == 'image' && bytes > kMaxNotificationImageBytes) return 'image';
  if (kind == 'video' && bytes > kMaxNotificationVideoBytes) return 'video';
  return null;
}

/// Name shown on attachment chips: first 18 characters + `…` (web).
String attachmentChipLabel(String name, {int max = 18}) =>
    name.length > max ? '${name.substring(0, max)}…' : name;

/// Web compose validation. Returns a comms string key for the error, or null when ok.
String? validateCompose({
  required String title,
  required String message,
  required NotificationTargetMode mode,
  required int selectedFlats,
  required int selectedResidents,
  required String alertSoundKey,
  String? societyCustomSoundUrl,
}) {
  if (title.isEmpty || message.isEmpty) return 'comms.notif.fillTitleMessage';
  if (mode == NotificationTargetMode.flat && selectedFlats == 0) {
    return 'comms.notif.selectOneFlat';
  }
  if (mode == NotificationTargetMode.user && selectedResidents == 0) {
    return 'comms.notif.selectOneResident';
  }
  if (alertSoundKey == 'custom' &&
      (societyCustomSoundUrl ?? '').trim().isEmpty) {
    return 'comms.notif.customSoundMissing';
  }
  return null;
}

class SelectedResident {
  const SelectedResident(
      {required this.id, required this.name, required this.flatNumber});

  final String id;
  final String name;
  final String flatNumber;
}

/// Rows to insert into `notifications` + the `send-push-notification` body.
class NotificationSendPlan {
  const NotificationSendPlan({
    required this.rows,
    required this.pushBody,
    required this.targetFlatNumbers,
    required this.targetUserIds,
    required this.effectiveSoundKey,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> pushBody;
  final List<String> targetFlatNumbers;
  final List<String> targetUserIds;
  final String effectiveSoundKey;
}

/// Exact port of the row / push mapping in `sendNotification`.
NotificationSendPlan buildNotificationSendPlan({
  required String title,
  required String message,
  required String type,
  required String adminName,
  required String? societyId,
  required NotificationTargetMode mode,
  required List<String> selectedFlats,
  required List<SelectedResident> selectedResidents,
  required List<NotificationMediaItem> media,
  required String alertSoundKey,
  String? societyCustomSoundUrl,
}) {
  var targetType = 'all';
  String? targetId;
  var flats = <String>[];
  var userIds = <String>[];

  if (mode == NotificationTargetMode.flat && selectedFlats.isNotEmpty) {
    targetType = 'flat';
    flats = List.of(selectedFlats);
    targetId = selectedFlats.join(',');
  } else if (mode == NotificationTargetMode.user &&
      selectedResidents.isNotEmpty) {
    targetType = 'user';
    userIds = selectedResidents.map((r) => r.id).toList();
    targetId = selectedResidents.map((r) => r.name).join(',');
  }

  final trimmed = societyCustomSoundUrl?.trim() ?? '';
  final soundCustomUrl = trimmed.isEmpty ? null : trimmed;
  final effectiveSoundKey = soundCustomUrl != null ? 'custom' : alertSoundKey;
  final mediaJson = media.map((m) => m.toJson()).toList();

  final rowBase = <String, dynamic>{
    'title': title,
    'message': message,
    'type': type,
    'created_by': adminName,
    'media_items': mediaJson,
    'society_id': societyId,
    'sound_key': effectiveSoundKey,
    'sound_custom_url': effectiveSoundKey == 'custom' ? soundCustomUrl : null,
  };

  final rows = <Map<String, dynamic>>[];
  if (mode == NotificationTargetMode.flat) {
    for (final flat in selectedFlats) {
      rows.add({...rowBase, 'target_type': 'flat', 'target_id': flat});
    }
  } else {
    rows.add({...rowBase, 'target_type': targetType, 'target_id': targetId});
  }

  final pushBody = <String, dynamic>{
    'title': title,
    'message': message,
    'target_type': mode.name,
    'target_flat_numbers': flats,
    'target_ids': userIds,
    'media_items': mediaJson,
    'society_id': societyId,
    'sound_key': effectiveSoundKey,
    'sound_custom_url':
        (effectiveSoundKey == 'custom' ? soundCustomUrl : null) ?? '',
  };

  return NotificationSendPlan(
    rows: rows,
    pushBody: pushBody,
    targetFlatNumbers: flats,
    targetUserIds: userIds,
    effectiveSoundKey: effectiveSoundKey,
  );
}

/// Directory despatch target (web `dispatchDirectoryChannels` `target`).
Map<String, dynamic> directoryTargetFields(NotificationTargetMode mode,
    {List<String> flats = const [], List<String> userIds = const []}) {
  return {
    'target_type': mode.name,
    'target_flat_numbers':
        mode == NotificationTargetMode.flat ? flats : const <String>[],
    'target_ids':
        mode == NotificationTargetMode.user ? userIds : const <String>[],
  };
}

/// Web `mediaItemsFromReceiptUrl` (`adminRecordNotifications.ts`): PDFs are not attached,
/// anything else is attached as an image.
List<NotificationMediaItem>? mediaItemsFromReceiptUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final u = url.split('?').first.toLowerCase();
  if (u.endsWith('.pdf')) return null;
  return [NotificationMediaItem(url: url, kind: 'image')];
}

/// Web `notifyResidentsOfRecord` audience.
enum RecordNotifyAudience { none, selectedFlats, all }

/// Rows + push body for `notifyResidentsOfRecord` (one row per unique flat for `selectedFlats`).
NotificationSendPlan? buildRecordNotificationPlan({
  required String societyId,
  required String adminName,
  required RecordNotifyAudience audience,
  required List<String> selectedFlatNumbers,
  required String title,
  required String message,
  required String notificationType,
  required String? billUrl,
  required String soundKey,
  String? soundCustomUrl,
}) {
  if (audience == RecordNotifyAudience.none) return null;
  final media = (mediaItemsFromReceiptUrl(billUrl) ?? const [])
      .map((m) => m.toJson())
      .toList();
  final rowBase = <String, dynamic>{
    'title': title,
    'message': message,
    'type': notificationType,
    'created_by': adminName,
    'society_id': societyId,
    'sound_key': soundKey,
    'sound_custom_url': soundCustomUrl,
    'media_items': media,
  };
  if (audience == RecordNotifyAudience.all) {
    return NotificationSendPlan(
      rows: [
        {...rowBase, 'target_type': 'all', 'target_id': null},
      ],
      pushBody: {
        'title': title,
        'message': message,
        'target_type': 'all',
        'target_flat_numbers': const <String>[],
        'target_ids': const <String>[],
        'media_items': media,
        'society_id': societyId,
        'sound_key': soundKey,
        'sound_custom_url': soundCustomUrl ?? '',
      },
      targetFlatNumbers: const [],
      targetUserIds: const [],
      effectiveSoundKey: soundKey,
    );
  }
  final flats = <String>[];
  for (final f in selectedFlatNumbers) {
    if (f.isNotEmpty && !flats.contains(f)) flats.add(f);
  }
  if (flats.isEmpty) {
    return const NotificationSendPlan(
        rows: [],
        pushBody: {},
        targetFlatNumbers: [],
        targetUserIds: [],
        effectiveSoundKey: 'digital');
  }
  return NotificationSendPlan(
    rows: [
      for (final flat in flats)
        {...rowBase, 'target_type': 'flat', 'target_id': flat},
    ],
    pushBody: {
      'title': title,
      'message': message,
      'target_type': 'flat',
      'target_flat_numbers': flats,
      'target_ids': const <String>[],
      'media_items': media,
      'society_id': societyId,
      'sound_key': soundKey,
      'sound_custom_url': soundCustomUrl ?? '',
    },
    targetFlatNumbers: flats,
    targetUserIds: const [],
    effectiveSoundKey: soundKey,
  );
}
