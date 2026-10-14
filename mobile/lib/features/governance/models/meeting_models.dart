import '../logic/meeting_logic.dart';

String? _s(Object? v) => v == null ? null : '$v';
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Row of `meetings`.
class MeetingRow {
  const MeetingRow({
    required this.id,
    required this.societyId,
    required this.title,
    required this.meetingAt,
    required this.meetingKind,
    required this.status,
    required this.published,
    this.description,
    this.location,
    this.discussionNotes,
    this.minutesSummary,
    this.executivesPresent,
    this.audioRecordingUrl,
    this.createdBy,
  });

  final String id;
  final String societyId;
  final String title;
  final String? description;
  final String meetingAt;
  final String? location;
  final MeetingKind meetingKind;
  final String status;
  final bool published;
  final String? discussionNotes;
  final String? minutesSummary;
  final String? executivesPresent;
  final String? audioRecordingUrl;
  final String? createdBy;

  factory MeetingRow.fromJson(Map<String, dynamic> j) => MeetingRow(
        id: '${j['id']}',
        societyId: '${j['society_id'] ?? ''}',
        title: (j['title'] ?? '').toString(),
        description: _s(j['description']),
        meetingAt: (j['meeting_at'] ?? '').toString(),
        location: _s(j['location']),
        meetingKind: normalizeMeetingKind(j['meeting_kind']),
        status: (j['status'] ?? 'scheduled').toString(),
        published: j['published'] == true,
        discussionNotes: _s(j['discussion_notes']),
        minutesSummary: _s(j['minutes_summary']),
        executivesPresent: _s(j['executives_present']),
        audioRecordingUrl: _s(j['audio_recording_url']),
        createdBy: _s(j['created_by']),
      );
}

/// Row of `meeting_attendees`.
class AttendeeRow {
  const AttendeeRow({
    required this.id,
    required this.meetingId,
    required this.displayName,
    required this.attendeeRole,
    required this.isPresent,
    this.memberId,
    this.flatNumber,
    this.guestName,
  });

  final String id;
  final String meetingId;
  final String? memberId;
  final String? flatNumber;
  final String displayName;
  final String? guestName;
  final String attendeeRole;
  final bool isPresent;

  factory AttendeeRow.fromJson(Map<String, dynamic> j) => AttendeeRow(
        id: '${j['id']}',
        meetingId: '${j['meeting_id']}',
        memberId: _s(j['member_id']),
        flatNumber: _s(j['flat_number']),
        displayName: (j['display_name'] ?? '').toString(),
        guestName: _s(j['guest_name']),
        attendeeRole: (j['attendee_role'] ?? 'member').toString(),
        isPresent: j['is_present'] == true,
      );
}

/// Row of `meeting_decisions`.
class DecisionRow {
  const DecisionRow(
      {required this.id,
      required this.meetingId,
      required this.decisionText,
      required this.sortOrder});

  final String id;
  final String meetingId;
  final String decisionText;
  final int sortOrder;

  factory DecisionRow.fromJson(Map<String, dynamic> j) => DecisionRow(
        id: '${j['id']}',
        meetingId: '${j['meeting_id']}',
        decisionText: (j['decision_text'] ?? '').toString(),
        sortOrder: _i(j['sort_order']),
      );
}

/// Row of `meeting_documents`.
class MeetingDocRow {
  const MeetingDocRow({
    required this.id,
    required this.meetingId,
    required this.title,
    required this.fileUrl,
    this.fileName,
    this.mimeType,
    this.sortOrder,
    this.createdAt,
  });

  final String id;
  final String meetingId;
  final String title;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final int? sortOrder;
  final String? createdAt;

  bool get isPdf =>
      (fileName ?? '').toLowerCase().endsWith('.pdf') ||
      mimeType == 'application/pdf';

  MeetingDocOrder get order =>
      MeetingDocOrder(id: id, sortOrder: sortOrder, createdAt: createdAt);

  factory MeetingDocRow.fromJson(Map<String, dynamic> j) => MeetingDocRow(
        id: '${j['id']}',
        meetingId: '${j['meeting_id']}',
        title: (j['title'] ?? '').toString(),
        fileUrl: (j['file_url'] ?? '').toString(),
        fileName: _s(j['file_name']),
        mimeType: _s(j['mime_type']),
        sortOrder:
            j['sort_order'] is num ? (j['sort_order'] as num).toInt() : null,
        createdAt: _s(j['created_at']),
      );
}

/// Row of `meeting_document_signatures`.
class SignatureRow {
  const SignatureRow({
    required this.id,
    required this.meetingDocumentId,
    required this.meetingAttendeeId,
    required this.signatureImageUrl,
    required this.signedAt,
    this.signerLabel,
  });

  final String id;
  final String meetingDocumentId;
  final String meetingAttendeeId;
  final String signatureImageUrl;
  final String signedAt;
  final String? signerLabel;

  factory SignatureRow.fromJson(Map<String, dynamic> j) => SignatureRow(
        id: '${j['id']}',
        meetingDocumentId: '${j['meeting_document_id']}',
        meetingAttendeeId: '${j['meeting_attendee_id']}',
        signatureImageUrl: (j['signature_image_url'] ?? '').toString(),
        signedAt: (j['signed_at'] ?? '').toString(),
        signerLabel: _s(j['signer_label']),
      );
}

/// Row of `meeting_agenda_items`.
class AgendaItemRow {
  const AgendaItemRow({
    required this.id,
    required this.meetingId,
    required this.title,
    required this.sortOrder,
    required this.source,
    required this.status,
    this.details,
    this.proposedByMemberId,
    this.proposedByName,
    this.proposedByFlat,
  });

  final String id;
  final String meetingId;
  final String title;
  final String? details;
  final int sortOrder;

  /// `admin` | `resident`
  final String source;

  /// `proposed` | `accepted` | `rejected` | `deferred`
  final String status;
  final String? proposedByMemberId;
  final String? proposedByName;
  final String? proposedByFlat;

  factory AgendaItemRow.fromJson(Map<String, dynamic> j) => AgendaItemRow(
        id: '${j['id']}',
        meetingId: '${j['meeting_id']}',
        title: (j['title'] ?? '').toString(),
        details: _s(j['details']),
        sortOrder: _i(j['sort_order']),
        source: (j['source'] ?? 'admin').toString(),
        status: (j['status'] ?? 'accepted').toString(),
        proposedByMemberId: _s(j['proposed_by_member_id']),
        proposedByName: _s(j['proposed_by_name']),
        proposedByFlat: _s(j['proposed_by_flat']),
      );
}

String agendaStatusLabel(String status, {bool hi = false}) => switch (status) {
      'proposed' => hi ? 'प्रस्तावित' : 'proposed',
      'accepted' => hi ? 'स्वीकृत' : 'accepted',
      'rejected' => hi ? 'अस्वीकृत' : 'rejected',
      'deferred' => hi ? 'स्थगित' : 'deferred',
      _ => status,
    };

/// Row of `meeting_suggestions`.
class SuggestionRow {
  const SuggestionRow({
    required this.id,
    required this.meetingId,
    required this.authorName,
    required this.suggestionText,
    required this.createdAt,
    this.memberId,
    this.flatNumber,
  });

  final String id;
  final String meetingId;
  final String? memberId;
  final String authorName;
  final String? flatNumber;
  final String suggestionText;
  final String createdAt;

  factory SuggestionRow.fromJson(Map<String, dynamic> j) => SuggestionRow(
        id: '${j['id']}',
        meetingId: '${j['meeting_id']}',
        memberId: _s(j['member_id']),
        authorName: (j['author_name'] ?? '').toString(),
        flatNumber: _s(j['flat_number']),
        suggestionText: (j['suggestion_text'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

/// Society member offered in attendance pickers.
class MemberPick {
  const MemberPick(
      {required this.id,
      required this.name,
      required this.flatId,
      required this.flatNumber,
      this.photo});

  final String id;
  final String name;
  final String flatId;
  final String flatNumber;
  final String? photo;
}

/// Flat with its members (attendance grid).
class FlatWithMembers {
  const FlatWithMembers(
      {required this.id,
      required this.flatNumber,
      this.ownerName,
      required this.members});

  final String id;
  final String flatNumber;
  final String? ownerName;
  final List<({String id, String name})> members;
}

/// Everything loaded for one open meeting (web `loadDetail`).
class MeetingDetail {
  const MeetingDetail({
    this.attendees = const [],
    this.decisions = const [],
    this.documents = const [],
    this.signatures = const [],
    this.agendaItems = const [],
    this.suggestions = const [],
  });

  final List<AttendeeRow> attendees;
  final List<DecisionRow> decisions;
  final List<MeetingDocRow> documents;
  final List<SignatureRow> signatures;
  final List<AgendaItemRow> agendaItems;
  final List<SuggestionRow> suggestions;
}
