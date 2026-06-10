class SocietyPoll {
  const SocietyPoll({
    required this.id,
    required this.question,
    required this.isActive,
    this.description,
    this.pollKind = 'standard',
    this.endDate,
  });

  final String id;
  final String question;
  final bool isActive;
  final String? description;
  final String pollKind;
  final String? endDate;

  bool get isElection => pollKind == 'election';

  factory SocietyPoll.fromRow(Map<String, dynamic> row) => SocietyPoll(
        id: row['id'] as String,
        question: row['question'] as String,
        isActive: row['is_active'] as bool? ?? false,
        description: row['description'] as String?,
        pollKind: row['poll_kind'] as String? ?? 'standard',
        endDate: row['end_date'] as String?,
      );
}

class PollOption {
  const PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    this.votesCount = 0,
  });

  final String id;
  final String pollId;
  final String optionText;
  final int votesCount;

  factory PollOption.fromRow(Map<String, dynamic> row) => PollOption(
        id: row['id'] as String,
        pollId: row['poll_id'] as String,
        optionText: row['option_text'] as String,
        votesCount: row['votes_count'] as int? ?? 0,
      );
}
