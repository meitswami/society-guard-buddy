import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_contacts.dart';
import 'package:kutumbika_mobile/features/shared/directory/directory_dispatch.dart';

void main() {
  group('normalizeWhatsAppPhone', () {
    test('adds 91 to 10-digit numbers and strips symbols', () {
      expect(normalizeWhatsAppPhone('98765 43210'), '919876543210');
      expect(normalizeWhatsAppPhone('+91-98765-43210'), '919876543210');
      expect(normalizeWhatsAppPhone('447911123456'), '447911123456');
    });

    test('rejects empty / too short / too long', () {
      expect(normalizeWhatsAppPhone(null), isNull);
      expect(normalizeWhatsAppPhone('  '), isNull);
      expect(normalizeWhatsAppPhone('12345'), isNull);
      expect(normalizeWhatsAppPhone('1234567890123456'), isNull);
    });
  });

  test('normalizeEmail', () {
    expect(normalizeEmail('  Asha@Example.COM '), 'asha@example.com');
    expect(normalizeEmail('bad@'), isNull);
    expect(normalizeEmail('a b@c.d'), isNull);
    expect(normalizeEmail(null), isNull);
  });

  test('resolveMemberChannelTargets: primary first, opt-outs, dedupe', () {
    final r = resolveMemberChannelTargets(const [
      DirectoryMemberContact(
          name: 'Kid', phone: '9000000001', email: 'kid@x.com'),
      DirectoryMemberContact(
          name: 'Owner',
          phone: '9000000002',
          whatsappPhone: '9000000009',
          email: 'o@x.com',
          isPrimary: true),
      DirectoryMemberContact(
          name: 'Muted',
          phone: '9000000003',
          email: 'm@x.com',
          notifyWhatsapp: false,
          notifyEmail: false),
      DirectoryMemberContact(
          name: 'Dup', phone: '9000000001', email: 'KID@x.com'),
    ]);
    expect(r.whatsapp, ['919000000009', '919000000001']);
    expect(r.emails, ['o@x.com', 'kid@x.com']);

    final waOnly = resolveMemberChannelTargets(
        const [DirectoryMemberContact(phone: '9000000001', email: 'k@x.com')],
        email: false);
    expect(waOnly.emails, isEmpty);
    expect(waOnly.whatsapp, ['919000000001']);
  });

  test('dispatch body matches the edge function contract', () {
    final body = directoryDispatchBody(
      societyId: 's1',
      title: 'T',
      message: 'M',
      channels: const DirectoryDispatchChannels(whatsapp: true),
      target: const DirectoryDispatchTarget.flats(['101']),
    );
    expect(body, {
      'society_id': 's1',
      'title': 'T',
      'message': 'M',
      'channels': {'whatsapp': true, 'email': false},
      'target_type': 'flat',
      'target_flat_numbers': ['101'],
      'target_ids': <String>[],
      'image_url': null,
    });
    final users = directoryDispatchBody(
      societyId: 's1',
      title: 'T',
      message: 'M',
      channels: const DirectoryDispatchChannels(email: true),
      target: const DirectoryDispatchTarget.users(['u1']),
      imageUrl: 'https://x/y.jpg',
    );
    expect(users['target_type'], 'user');
    expect(users['target_ids'], ['u1']);
    expect(users['target_flat_numbers'], isEmpty);
    expect(users['image_url'], 'https://x/y.jpg');
    expect(
        directoryDispatchBody(
            societyId: 's',
            title: 't',
            message: 'm',
            channels: const DirectoryDispatchChannels())['target_type'],
        'all');
  });

  test('no channel → no call', () async {
    expect(
      await dispatchDirectoryChannels(
          societyId: 's',
          title: 't',
          message: 'm',
          channels: const DirectoryDispatchChannels()),
      isNull,
    );
  });

  test('result parsing', () {
    final r = DirectoryDispatchResult.fromJson({
      'success': true,
      'whatsapp_recipients': 3,
      'whatsapp_sent': 2,
      'whatsapp_failed': 1,
      'whatsapp_configured': true,
      'email_recipients': 0,
      'email_sent': 0,
      'email_failed': 0,
      'email_configured': false,
    });
    expect(r.whatsappSent, 2);
    expect(r.whatsappFailed, 1);
    expect(r.emailConfigured, isFalse);
    expect(r.whatsappRecipients, 3);
  });
}
