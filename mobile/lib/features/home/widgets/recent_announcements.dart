import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../models/announcement.dart';

class RecentAnnouncements extends StatelessWidget {
  const RecentAnnouncements({
    super.key,
    required this.items,
    this.title = 'Recent Announcements',
    this.onViewAll,
    this.onItemTap,
  });

  final List<Announcement> items;
  final String title;
  final VoidCallback? onViewAll;
  final void Function(Announcement item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All',
                style: TextStyle(
                  color: brand.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => _AnnouncementTile(
            item: item,
            onTap: () => onItemTap?.call(item),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item, this.onTap});

  final Announcement item;
  final VoidCallback? onTap;

  IconData get _icon {
    switch (item.category) {
      case AnnouncementCategory.maintenance:
        return Icons.description_outlined;
      case AnnouncementCategory.community:
        return Icons.groups_outlined;
      case AnnouncementCategory.general:
        return Icons.pool_outlined;
    }
  }

  Color get _iconColor {
    switch (item.category) {
      case AnnouncementCategory.maintenance:
        return KutumbikaColors.primary;
      case AnnouncementCategory.community:
        return KutumbikaColors.announcementBlue;
      case AnnouncementCategory.general:
        return KutumbikaColors.announcementTeal;
    }
  }

  String get _timeLabel {
    final now = DateTime.now();
    final diff = now.difference(item.createdAt);
    if (diff.inHours < 24 && item.createdAt.day == now.day) {
      return DateFormat.jm().format(item.createdAt);
    }
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('d MMM').format(item.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KutumbikaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: KutumbikaColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
