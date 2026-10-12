/// Pure helpers ported from web `src/components/MeetingManager.tsx`.
library;

import 'election_governance.dart' show jsIsoString;
import 'text_compare.dart';

/// `meetings.meeting_kind` (web `MEETING_KIND_OPTIONS`).
enum MeetingKind {
  generalBody(
      'general_body', 'General body meeting', 'सामान्य सभा बैठक', 'GBM', 'GBM'),
  annual('annual', 'Annual meeting', 'वार्षिक बैठक', 'AGM', 'AGM'),
  executiveCommittee('executive_committee', 'Executive committee',
      'कार्यकारिणी समिति', 'EC', 'EC'),
  other('other', 'Other', 'अन्य', 'Other', 'अन्य');

  const MeetingKind(
      this.value, this.labelEn, this.labelHi, this.shortEn, this.shortHi);

  final String value;
  final String labelEn;
  final String labelHi;
  final String shortEn;
  final String shortHi;

  String label(bool hi) => hi ? labelHi : labelEn;
  String short(bool hi) => hi ? shortHi : shortEn;
}

MeetingKind normalizeMeetingKind(Object? v) {
  for (final k in MeetingKind.values) {
    if (k.value == v) return k;
  }
  return MeetingKind.other;
}

/// English label (used in printouts / notifications like the web).
String meetingKindLabel(Object? kind) => normalizeMeetingKind(kind).labelEn;

String meetingKindShort(Object? kind) => normalizeMeetingKind(kind).shortEn;

/// `meetings.status` values offered in the admin select.
const List<String> meetingStatuses = [
  'draft',
  'scheduled',
  'completed',
  'cancelled'
];

String meetingStatusLabel(String status, {bool hi = false}) => switch (status) {
      'draft' => hi ? 'ड्राफ़्ट' : 'Draft',
      'scheduled' => hi ? 'निर्धारित' : 'Scheduled',
      'completed' => hi ? 'संपन्न' : 'Completed',
      'cancelled' => hi ? 'रद्द' : 'Cancelled',
      _ => status,
    };

String _pad2(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` of an ISO instant in local time ('' when invalid).
String toDateInput(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
}

/// `HH:mm` of an ISO instant in local time ('' when invalid).
String toTimeInput(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${_pad2(d.hour)}:${_pad2(d.minute)}';
}

/// Local `yyyy-MM-dd` + `HH:mm` → UTC ISO string (defaults: today, 09:00).
String combineDateAndTimeToIso(String dateStr, String timeStr,
    {DateTime? now}) {
  final d = dateStr.isNotEmpty
      ? dateStr
      : toDateInput(jsIsoString(now ?? DateTime.now()));
  final t = timeStr.isNotEmpty ? timeStr : '09:00';
  final dp = d.split('-').map((s) => int.tryParse(s) ?? 0).toList();
  final tp = t.split(':').map((s) => int.tryParse(s) ?? 0).toList();
  if (dp.length < 3 || tp.length < 2) return jsIsoString(now ?? DateTime.now());
  final dt = DateTime(dp[0], dp[1], dp[2], tp[0], tp[1]);
  return jsIsoString(dt);
}

/// Session tools (attendance, minutes, recording…) unlock on/after the meeting calendar day.
bool isSessionDayOrPast(String meetingAtIso, [DateTime? ref]) {
  final meetingDay = toDateInput(meetingAtIso);
  final today = toDateInput(jsIsoString(ref ?? DateTime.now()));
  return meetingDay.isNotEmpty && meetingDay.compareTo(today) <= 0;
}

/// Same instant? (avoids rewriting `meeting_at` when only the string format differs).
bool sameInstant(String? a, String? b) {
  if (a == null || b == null) return a == b;
  final da = DateTime.tryParse(a);
  final db = DateTime.tryParse(b);
  if (da == null || db == null) return a == b;
  return da.isAtSameMomentAs(db);
}

const List<String> meetingDocExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'heic',
  'heif',
  'tif',
  'tiff',
];

/// Web `isAllowedMeetingAttachment` — images + PDFs.
bool isAllowedMeetingAttachment({String? mimeType, required String fileName}) {
  final t = (mimeType ?? '').toLowerCase();
  if (t.startsWith('image/')) return true;
  if (t == 'application/pdf' || t == 'application/x-pdf') return true;
  return fileName.toLowerCase().endsWith('.pdf');
}

/// Extension → MIME (browser `File.type` equivalent for the formats we accept).
String? mimeFromFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'tif' || 'tiff' => 'image/tiff',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt' => 'text/plain',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'ogg' || 'oga' => 'audio/ogg',
    'opus' => 'audio/opus',
    'webm' => 'audio/webm',
    'amr' => 'audio/amr',
    'flac' => 'audio/flac',
    '3gp' => 'video/3gpp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    _ => null,
  };
}

/// Web `sanitizeStorageFileName` (`[^\w.-]` → `_`).
String sanitizeStorageFileName(String name) =>
    name.replaceAll(RegExp(r'[^\w.-]'), '_');

/// `file.name.replace(/\.[^.]+$/, '')`.
String stripExtension(String name) =>
    name.replaceFirst(RegExp(r'\.[^.]+$'), '');

/// One agenda issue per line; strips leading bullets / numbers.
List<String> parseAgendaLines(String text) => text
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'^[\s\-*•\d.)]+'), '').trim())
    .where((l) => l.isNotEmpty)
    .toList();

/// `(x ?? '').trim() || null`.
String? normText(String? x) {
  final t = (x ?? '').trim();
  return t.isEmpty ? null : t;
}

/// Notification body when a meeting is created with "Bring to notice".
String meetingCreateNoticeBody(
        {required String purpose,
        required String when,
        required String venue}) =>
    '$purpose\n\nWhen: $when\nVenue: $venue\nOpen Meetings in the app for agenda and documents.';

/// Notification body for "Publish & notify" / "Re-notify" (sliced to 900 chars).
String meetingPublishNoticeBody(
    {required String purpose, required String when, required String location}) {
  final body =
      '$purpose\n\nWhen: $when\nVenue: ${location.isEmpty ? '—' : location}\nOpen Meetings for agenda and documents.';
  return body.length > 900 ? body.substring(0, 900) : body;
}

/// Notification body for "Publish minutes & notify all".
String meetingMinutesNoticeBody(String minutes) {
  final base =
      minutes.isNotEmpty ? minutes : 'Published minutes are available.';
  final sliced = base.length > 900 ? base.substring(0, 900) : base;
  return '$sliced${minutes.length > 900 ? '…' : ''} Open the Meetings tab in the app.';
}

/// Minimal shapes used by the pure helpers below.
class MeetingDocOrder {
  const MeetingDocOrder({required this.id, this.sortOrder, this.createdAt});

  final String id;
  final int? sortOrder;
  final String? createdAt;
}

/// Documents sorted by `sort_order`, then `created_at` (web `moveMeetingDocument`).
List<T> sortMeetingDocs<T>(List<T> docs, MeetingDocOrder Function(T) key) {
  final indexed = [for (var i = 0; i < docs.length; i++) (i, docs[i])];
  indexed.sort((a, b) {
    final ka = key(a.$2);
    final kb = key(b.$2);
    final sa = ka.sortOrder ?? 0;
    final sb = kb.sortOrder ?? 0;
    if (sa != sb) return sa - sb;
    final ta = ka.createdAt ?? '';
    final tb = kb.createdAt ?? '';
    final c = ta.compareTo(tb);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return indexed.map((e) => e.$2).toList();
}

/// New order after moving [id] one step; null when the move is not possible.
List<T>? moveMeetingDoc<T>(List<T> docs, String id,
    {required bool up, required MeetingDocOrder Function(T) key}) {
  final sorted = sortMeetingDocs(docs, key);
  final i = sorted.indexWhere((d) => key(d).id == id);
  if (i < 0) return null;
  final j = up ? i - 1 : i + 1;
  if (j < 0 || j >= sorted.length) return null;
  final out = [...sorted];
  final tmp = out[i];
  out[i] = out[j];
  out[j] = tmp;
  return out;
}

/// Next `sort_order` for appended attachments (`max(sort_order) + 1`, starting at 0).
int nextMeetingDocOrder(Iterable<int?> sortOrders) {
  var maxSo = -1;
  for (final s in sortOrders) {
    final v = s ?? 0;
    if (v > maxSo) maxSo = v;
  }
  return maxSo + 1;
}

/// A flat counts as "present" when every member has a present attendance row.
bool isFlatMarkedPresent(
    List<String> flatMemberIds, Map<String?, bool> presentByMemberId) {
  if (flatMemberIds.isEmpty) return false;
  return flatMemberIds.every((id) => presentByMemberId[id] == true);
}

/// Member picker order: flat (natural), then name.
int compareMemberPick(String flatA, String nameA, String flatB, String nameB) {
  final f = naturalCompare(flatA, flatB);
  if (f != 0) return f;
  return localeCompare(nameA, nameB);
}
