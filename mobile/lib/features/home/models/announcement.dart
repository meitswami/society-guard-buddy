enum AnnouncementCategory { maintenance, community, general }

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.category,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final AnnouncementCategory category;
}
