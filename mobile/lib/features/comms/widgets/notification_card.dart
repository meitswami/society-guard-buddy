import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/notification_audience.dart';
import '../data/notification_models.dart';

/// One row of the notification list (web `NotificationCenter` list button).
class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, required this.isResident, required this.onTap});

  final AppNotification notification;
  final bool isResident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = notification;
    final unread = !n.isRead;
    final target = isResident
        ? null
        : notificationTargetTag(targetType: n.targetType, targetId: n.targetId, flatWord: context.t('common.flat'));
    return CardSection(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: unread ? AppTokens.tint(t.primary, 0.3) : null,
      color: unread ? Color.alphaBlend(AppTokens.tint(t.primary, 0.05), t.card) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notificationTypeIcon(n.type), style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(n.title, style: AppText.sectionTitle(context)),
                    if (unread && isResident)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(999)),
                        child: Text(context.ct('comms.inbox.new'),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.primaryForeground)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption(context)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(context.ct(notificationTypeLabelKey(n.type)),
                        style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w500)),
                    Text(Fmt.dateTimeFull(n.createdAt), style: AppText.tiny(context)),
                    if (isResident && (n.createdBy ?? '').isNotEmpty) Text('· ${n.createdBy}', style: AppText.tiny(context)),
                    if (target != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(target, style: TextStyle(fontSize: 10, color: t.primary)),
                      ),
                    NotificationMediaBadge(count: n.media.length),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isResident ? context.ct('comms.inbox.tapToOpen') : context.ct('comms.notif.tapToViewAdmin'),
                  style: TextStyle(fontSize: 10, color: AppTokens.tint(t.primary, 0.8)),
                ),
              ],
            ),
          ),
          if (unread && !isResident)
            Container(
              margin: const EdgeInsets.only(top: 8, left: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

/// Web `NotificationMediaBadges`.
class NotificationMediaBadge extends StatelessWidget {
  const NotificationMediaBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.primary, 0.05),
        border: Border.all(color: AppTokens.tint(t.primary, 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 12, color: t.primary),
          const SizedBox(width: 4),
          Text(
            context.ct(count == 1 ? 'comms.notif.attachmentOne' : 'comms.notif.attachmentMany', {'count': count}),
            style: TextStyle(fontSize: 10, color: t.primary),
          ),
        ],
      ),
    );
  }
}
