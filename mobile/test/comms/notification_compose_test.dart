import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_compose.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_models.dart';

void main() {
  const media = [NotificationMediaItem(url: 'https://cdn/x.jpg', kind: 'image')];

  group('validateCompose', () {
    String? v({
      String title = 'T',
      String message = 'M',
      NotificationTargetMode mode = NotificationTargetMode.all,
      int flats = 0,
      int residents = 0,
      String sound = 'digital',
      String? url,
    }) =>
        validateCompose(
          title: title,
          message: message,
          mode: mode,
          selectedFlats: flats,
          selectedResidents: residents,
          alertSoundKey: sound,
          societyCustomSoundUrl: url,
        );

    test('title and message are required', () {
      expect(v(title: ''), 'comms.notif.fillTitleMessage');
      expect(v(message: ''), 'comms.notif.fillTitleMessage');
      expect(v(), isNull);
    });

    test('flat / person modes need a selection', () {
      expect(v(mode: NotificationTargetMode.flat), 'comms.notif.selectOneFlat');
      expect(v(mode: NotificationTargetMode.flat, flats: 2), isNull);
      expect(v(mode: NotificationTargetMode.user), 'comms.notif.selectOneResident');
      expect(v(mode: NotificationTargetMode.user, residents: 1), isNull);
    });

    test('custom sound needs an uploaded society sound', () {
      expect(v(sound: 'custom'), 'comms.notif.customSoundMissing');
      expect(v(sound: 'custom', url: '   '), 'comms.notif.customSoundMissing');
      expect(v(sound: 'custom', url: 'https://s/a.mp3'), isNull);
    });
  });

  group('buildNotificationSendPlan', () {
    test('society-wide: one row, push target_type all', () {
      final plan = buildNotificationSendPlan(
        title: 'Water',
        message: 'No water 10-12',
        type: 'general',
        adminName: 'SECRETARY',
        societyId: 's1',
        mode: NotificationTargetMode.all,
        selectedFlats: const [],
        selectedResidents: const [],
        media: media,
        alertSoundKey: 'chime',
      );
      expect(plan.rows, hasLength(1));
      expect(plan.rows.single['target_type'], 'all');
      expect(plan.rows.single['target_id'], isNull);
      expect(plan.rows.single['sound_key'], 'chime');
      expect(plan.rows.single['sound_custom_url'], isNull);
      expect(plan.rows.single['created_by'], 'SECRETARY');
      expect(plan.rows.single['media_items'], [
        {'url': 'https://cdn/x.jpg', 'kind': 'image'}
      ]);
      expect(plan.pushBody['target_type'], 'all');
      expect(plan.pushBody['sound_custom_url'], '');
      expect(plan.pushBody['target_flat_numbers'], isEmpty);
    });

    test('flats: one row per flat, push carries all flat numbers', () {
      final plan = buildNotificationSendPlan(
        title: 'Lift',
        message: 'Lift service',
        type: 'alert',
        adminName: 'A',
        societyId: 's1',
        mode: NotificationTargetMode.flat,
        selectedFlats: const ['101', '102'],
        selectedResidents: const [],
        media: const [],
        alertSoundKey: 'digital',
      );
      expect(plan.rows.map((r) => r['target_id']), ['101', '102']);
      expect(plan.rows.every((r) => r['target_type'] == 'flat'), isTrue);
      expect(plan.pushBody['target_type'], 'flat');
      expect(plan.pushBody['target_flat_numbers'], ['101', '102']);
      expect(plan.targetFlatNumbers, ['101', '102']);
    });

    test('persons: names in target_id, ids in push target_ids', () {
      final plan = buildNotificationSendPlan(
        title: 'Hi',
        message: 'Msg',
        type: 'event',
        adminName: 'A',
        societyId: 's1',
        mode: NotificationTargetMode.user,
        selectedFlats: const [],
        selectedResidents: const [
          SelectedResident(id: 'r1', name: 'ASHA', flatNumber: '101'),
          SelectedResident(id: 'r2', name: 'RAVI', flatNumber: '102'),
        ],
        media: const [],
        alertSoundKey: 'bell',
      );
      expect(plan.rows.single['target_type'], 'user');
      expect(plan.rows.single['target_id'], 'ASHA,RAVI');
      expect(plan.pushBody['target_type'], 'user');
      expect(plan.pushBody['target_ids'], ['r1', 'r2']);
    });

    test('a society custom sound always wins over the chosen preset (web)', () {
      final plan = buildNotificationSendPlan(
        title: 'T',
        message: 'M',
        type: 'general',
        adminName: 'A',
        societyId: 's1',
        mode: NotificationTargetMode.all,
        selectedFlats: const [],
        selectedResidents: const [],
        media: const [],
        alertSoundKey: 'siren',
        societyCustomSoundUrl: ' https://s/tune.mp3 ',
      );
      expect(plan.effectiveSoundKey, 'custom');
      expect(plan.rows.single['sound_key'], 'custom');
      expect(plan.rows.single['sound_custom_url'], 'https://s/tune.mp3');
      expect(plan.pushBody['sound_custom_url'], 'https://s/tune.mp3');
    });
  });

  group('media rules', () {
    test('kind from MIME, with extension fallback', () {
      expect(fileMediaKind(mimeType: 'image/png', fileName: 'x'), 'image');
      expect(fileMediaKind(mimeType: 'video/mp4', fileName: 'x'), 'video');
      expect(fileMediaKind(fileName: 'IMG_1.HEIC'), 'image');
      expect(fileMediaKind(fileName: 'clip.mov'), 'video');
      expect(fileMediaKind(fileName: 'notes.pdf'), isNull);
      expect(fileMediaKind(mimeType: 'application/pdf', fileName: 'a.pdf'), isNull);
    });

    test('size limits: 12 MB images, 50 MB videos', () {
      expect(mediaSizeViolation('image', 12 * 1024 * 1024), isNull);
      expect(mediaSizeViolation('image', 12 * 1024 * 1024 + 1), 'image');
      expect(mediaSizeViolation('video', 50 * 1024 * 1024), isNull);
      expect(mediaSizeViolation('video', 50 * 1024 * 1024 + 1), 'video');
    });

    test('audio detection and chip label', () {
      expect(isAudioFile(mimeType: 'audio/mpeg', fileName: 'x'), isTrue);
      expect(isAudioFile(fileName: 'tune.ogg'), isTrue);
      expect(isAudioFile(fileName: 'tune.jpg'), isFalse);
      expect(attachmentChipLabel('short.jpg'), 'short.jpg');
      expect(attachmentChipLabel('a-very-long-file-name.jpeg'), 'a-very-long-file-n…');
    });
  });

  group('adminRecordNotifications', () {
    test('mediaItemsFromReceiptUrl skips PDFs', () {
      expect(mediaItemsFromReceiptUrl(null), isNull);
      expect(mediaItemsFromReceiptUrl('https://x/bill.PDF?token=1'), isNull);
      expect(mediaItemsFromReceiptUrl('https://x/bill.png?x=1')!.single.kind, 'image');
      expect(mediaItemsFromReceiptUrl('https://x/bill')!.single.url, 'https://x/bill');
    });

    test('selected flats are de-duplicated, one row each', () {
      final plan = buildRecordNotificationPlan(
        societyId: 's1',
        adminName: 'A',
        audience: RecordNotifyAudience.selectedFlats,
        selectedFlatNumbers: const ['101', '', '101', '205'],
        title: 'Receipt',
        message: 'Paid',
        notificationType: 'payment_reminder',
        billUrl: null,
        soundKey: 'digital',
      )!;
      expect(plan.rows.map((r) => r['target_id']), ['101', '205']);
      expect(plan.pushBody['target_flat_numbers'], ['101', '205']);
    });

    test('audience none sends nothing', () {
      expect(
        buildRecordNotificationPlan(
          societyId: 's1',
          adminName: 'A',
          audience: RecordNotifyAudience.none,
          selectedFlatNumbers: const [],
          title: 't',
          message: 'm',
          notificationType: 'general',
          billUrl: null,
          soundKey: 'digital',
        ),
        isNull,
      );
    });
  });
}
