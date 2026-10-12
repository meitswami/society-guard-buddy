import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_audience.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_models.dart';

void main() {
  bool visible(String? type, String? id, {String rid = 'r-1', String name = 'ASHA', String flat = '101'}) =>
      notificationVisibleToResident(targetType: type, targetId: id, residentId: rid, residentName: name, flatNumber: flat);

  group('notificationVisibleToResident (web notificationAudience.ts)', () {
    test('society-wide rows are visible to everyone', () {
      expect(visible('all', null), isTrue);
      expect(visible('all', 'anything'), isTrue);
    });

    test('flat rows match the exact flat or a comma list', () {
      expect(visible('flat', '101'), isTrue);
      expect(visible('flat', ' 101 '), isTrue, reason: 'target_id is trimmed');
      expect(visible('flat', '102'), isFalse);
      expect(visible('flat', '102, 101 ,103'), isTrue);
      expect(visible('flat', '102,103'), isFalse);
      expect(visible('flat', '1010'), isFalse);
    });

    test('person rows match resident id or name (also in comma lists)', () {
      expect(visible('user', 'r-1'), isTrue);
      expect(visible('user', 'ASHA'), isTrue);
      expect(visible('user', 'RAVI, ASHA'), isTrue);
      expect(visible('user', 'x-9, r-1'), isTrue);
      expect(visible('user', 'RAVI'), isFalse);
      expect(visible('user', 'asha'), isFalse, reason: 'names compare case-sensitively like the web');
    });

    test('unknown or missing target types are hidden', () {
      expect(visible(null, null), isFalse);
      expect(visible('guard', 'r-1'), isFalse);
      expect(visible('', '101'), isFalse);
    });

    test('a resident without a flat sees flat rows with an empty target (web quirk)', () {
      expect(visible('flat', null, flat: ''), isTrue);
      expect(visible('flat', '101', flat: ''), isFalse);
    });

    test('row helper reads target_type / target_id', () {
      expect(
        notificationRowVisibleToResident({'target_type': 'flat', 'target_id': '101,205'},
            residentId: 'a', residentName: 'b', flatNumber: '205'),
        isTrue,
      );
    });
  });

  group('type icons and labels', () {
    test('known types map to the web icons, others fall back to 📢', () {
      expect(notificationTypeIcon('general'), '📢');
      expect(notificationTypeIcon('payment_reminder'), '💰');
      expect(notificationTypeIcon('event'), '🎉');
      expect(notificationTypeIcon('event_reminder'), '🔔');
      expect(notificationTypeIcon('poll'), '📊');
      expect(notificationTypeIcon('alert'), '⚠️');
      expect(notificationTypeIcon('maintenance'), '📢');
    });

    test('labels follow NOTIFICATION_TYPE_LABELS with Notice fallback', () {
      expect(notificationTypeLabelKey('general'), 'comms.type.notice');
      expect(notificationTypeLabelKey('payment_reminder'), 'comms.type.payment');
      expect(notificationTypeLabelKey('event_reminder'), 'comms.type.reminder');
      expect(notificationTypeLabelKey('poll'), 'comms.type.poll');
      expect(notificationTypeLabelKey('alert'), 'comms.type.alert');
      expect(notificationTypeLabelKey('whatever'), 'comms.type.notice');
    });

    test('admin target tag', () {
      expect(notificationTargetTag(targetType: 'all', targetId: null, flatWord: 'Flat'), isNull);
      expect(notificationTargetTag(targetType: 'flat', targetId: '101', flatWord: 'Flat'), '→ Flat 101');
      expect(notificationTargetTag(targetType: 'user', targetId: 'ASHA,RAVI', flatWord: 'Flat'), '→ ASHA,RAVI');
    });
  });

  group('clear till date', () {
    test('end of local day', () {
      final e = endOfLocalDay(DateTime(2026, 3, 9, 8, 15));
      expect(e, DateTime(2026, 3, 9, 23, 59, 59, 999));
    });

    test('only visible, not-yet-dismissed ids are dismissed', () {
      final rows = [
        {'id': 'n1', 'target_type': 'all', 'target_id': null},
        {'id': 'n2', 'target_type': 'flat', 'target_id': '102'},
        {'id': 'n3', 'target_type': 'flat', 'target_id': '101'},
        {'id': 'n4', 'target_type': 'user', 'target_id': 'ASHA'},
      ];
      final ids = idsToDismiss(rows, alreadyDismissed: {'n3'}, residentId: 'r-1', residentName: 'ASHA', flatNumber: '101');
      expect(ids, ['n1', 'n4']);
    });
  });

  group('parseNotificationMedia', () {
    test('keeps only url + image/video entries', () {
      final media = parseNotificationMedia([
        {'url': 'https://x/a.jpg', 'kind': 'image'},
        {'url': 'https://x/b.mp4', 'kind': 'video'},
        {'url': 'https://x/c.pdf', 'kind': 'file'},
        {'kind': 'image'},
        {'url': 42, 'kind': 'image'},
        'junk',
      ]);
      expect(media, const [
        NotificationMediaItem(url: 'https://x/a.jpg', kind: 'image'),
        NotificationMediaItem(url: 'https://x/b.mp4', kind: 'video'),
      ]);
    });

    test('non-lists parse to empty', () {
      expect(parseNotificationMedia(null), isEmpty);
      expect(parseNotificationMedia({'url': 'x'}), isEmpty);
    });
  });

  group('buildCommentRow', () {
    test('resident comment', () {
      final row = buildCommentRow(
        notificationId: 'n1',
        body: 'When?',
        isResident: true,
        resident: const ResidentRef(id: 'r1', name: 'ASHA', flatNumber: '101'),
      );
      expect(row, {
        'notification_id': 'n1',
        'author_role': 'resident',
        'author_resident_id': 'r1',
        'author_name': 'ASHA',
        'author_flat_number': '101',
        'body': 'When?',
      });
    });

    test('admin comment', () {
      final row = buildCommentRow(notificationId: 'n1', body: 'Tomorrow', isResident: false, adminName: 'SECRETARY');
      expect(row['author_role'], 'admin');
      expect(row['author_resident_id'], isNull);
      expect(row['author_flat_number'], isNull);
      expect(row['author_name'], 'SECRETARY');
    });
  });
}
