class SocietyMeeting {
  const SocietyMeeting({
    required this.id,
    required this.title,
    required this.meetingAt,
    required this.status,
    required this.published,
    this.description,
    this.location,
    this.minutesSummary,
    this.meetingKind = 'general',
  });

  final String id;
  final String title;
  final String meetingAt;
  final String status;
  final bool published;
  final String? description;
  final String? location;
  final String? minutesSummary;
  final String meetingKind;

  factory SocietyMeeting.fromRow(Map<String, dynamic> row) => SocietyMeeting(
        id: row['id'] as String,
        title: row['title'] as String,
        meetingAt: row['meeting_at'] as String,
        status: row['status'] as String? ?? 'scheduled',
        published: row['published'] as bool? ?? false,
        description: row['description'] as String?,
        location: row['location'] as String?,
        minutesSummary: row['minutes_summary'] as String?,
        meetingKind: row['meeting_kind'] as String? ?? 'general',
      );
}
