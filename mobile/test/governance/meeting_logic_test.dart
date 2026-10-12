import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/meeting_logic.dart';
import 'package:kutumbika_mobile/features/governance/logic/text_compare.dart';

class _Doc {
  const _Doc(this.id, this.sortOrder, this.createdAt);

  final String id;
  final int? sortOrder;
  final String? createdAt;
}

MeetingDocOrder _key(_Doc d) => MeetingDocOrder(id: d.id, sortOrder: d.sortOrder, createdAt: d.createdAt);

void main() {
  group('meeting kinds', () {
    test('normalize unknown kinds to other', () {
      expect(normalizeMeetingKind('annual'), MeetingKind.annual);
      expect(normalizeMeetingKind('general'), MeetingKind.other);
      expect(normalizeMeetingKind(null), MeetingKind.other);
      expect(meetingKindLabel('general_body'), 'General body meeting');
      expect(meetingKindShort('executive_committee'), 'EC');
      expect(MeetingKind.values.map((k) => k.value), ['general_body', 'annual', 'executive_committee', 'other']);
    });

    test('status labels', () {
      expect(meetingStatuses, ['draft', 'scheduled', 'completed', 'cancelled']);
      expect(meetingStatusLabel('completed'), 'Completed');
      expect(meetingStatusLabel('weird'), 'weird');
    });
  });

  group('date / time inputs', () {
    test('round trip local date + time', () {
      final iso = combineDateAndTimeToIso('2026-10-12', '18:45');
      expect(toDateInput(iso), '2026-10-12');
      expect(toTimeInput(iso), '18:45');
      expect(iso.endsWith('Z'), isTrue);
    });

    test('defaults to today 09:00', () {
      final now = DateTime(2026, 3, 4, 15);
      final iso = combineDateAndTimeToIso('', '', now: now);
      expect(toDateInput(iso), '2026-03-04');
      expect(toTimeInput(iso), '09:00');
    });

    test('invalid inputs give empty strings', () {
      expect(toDateInput('nope'), '');
      expect(toTimeInput(null), '');
    });

    test('session unlocks on the meeting day', () {
      final ref = DateTime(2026, 10, 12, 8);
      expect(isSessionDayOrPast(DateTime(2026, 10, 12, 18).toUtc().toIso8601String(), ref), isTrue);
      expect(isSessionDayOrPast(DateTime(2026, 10, 1).toUtc().toIso8601String(), ref), isTrue);
      expect(isSessionDayOrPast(DateTime(2026, 10, 13, 0, 5).toUtc().toIso8601String(), ref), isFalse);
      expect(isSessionDayOrPast('bad', ref), isFalse);
    });

    test('sameInstant ignores string formatting', () {
      expect(sameInstant('2026-10-12T09:00:00+00:00', '2026-10-12T09:00:00.000Z'), isTrue);
      expect(sameInstant('2026-10-12T09:00:00+00:00', '2026-10-12T09:01:00.000Z'), isFalse);
    });
  });

  group('attachments', () {
    test('only images and PDFs', () {
      expect(isAllowedMeetingAttachment(mimeType: 'image/heic', fileName: 'x.heic'), isTrue);
      expect(isAllowedMeetingAttachment(mimeType: 'application/x-pdf', fileName: 'x'), isTrue);
      expect(isAllowedMeetingAttachment(mimeType: '', fileName: 'Minutes.PDF'), isTrue);
      expect(isAllowedMeetingAttachment(mimeType: 'text/plain', fileName: 'a.txt'), isFalse);
    });

    test('mime from extension', () {
      expect(mimeFromFileName('a.JPG'), 'image/jpeg');
      expect(mimeFromFileName('a.pdf'), 'application/pdf');
      expect(mimeFromFileName('a.m4a'), 'audio/mp4');
      expect(mimeFromFileName('noext'), isNull);
    });

    test('file name helpers', () {
      expect(sanitizeStorageFileName('My file (1).pdf'), 'My_file__1_.pdf');
      expect(sanitizeStorageFileName('बैठक.pdf'), '____.pdf');
      expect(stripExtension('notice.final.pdf'), 'notice.final');
      expect(stripExtension('.pdf'), '');
    });
  });

  group('agenda + notes', () {
    test('parseAgendaLines strips bullets and numbering', () {
      expect(parseAgendaLines('1. Maintenance arrears\n - Parking allocation\n\n• AGM date\n2) '), [
        'Maintenance arrears',
        'Parking allocation',
        'AGM date',
      ]);
    });

    test('normText', () {
      expect(normText('  '), isNull);
      expect(normText(null), isNull);
      expect(normText(' a '), 'a');
    });

    test('notification bodies', () {
      expect(
        meetingCreateNoticeBody(purpose: 'AGM', when: '12/10/2026 18:00:00', venue: 'Hall'),
        'AGM\n\nWhen: 12/10/2026 18:00:00\nVenue: Hall\nOpen Meetings in the app for agenda and documents.',
      );
      expect(
        meetingPublishNoticeBody(purpose: 'AGM', when: 'w', location: ''),
        'AGM\n\nWhen: w\nVenue: —\nOpen Meetings for agenda and documents.',
      );
      expect(meetingPublishNoticeBody(purpose: 'x' * 1200, when: 'w', location: 'v').length, 900);
      expect(meetingMinutesNoticeBody(''), 'Published minutes are available. Open the Meetings tab in the app.');
      final long = meetingMinutesNoticeBody('m' * 950);
      expect(long.startsWith('m' * 900), isTrue);
      expect(long.endsWith('… Open the Meetings tab in the app.'), isTrue);
    });
  });

  group('documents order', () {
    const docs = [
      _Doc('b', 1, '2026-01-02'),
      _Doc('a', 0, '2026-01-03'),
      _Doc('c', 1, '2026-01-01'),
    ];

    test('sorted by sort_order then created_at', () {
      expect(sortMeetingDocs(docs, _key).map((d) => d.id), ['a', 'c', 'b']);
    });

    test('move up / down swaps neighbours', () {
      expect(moveMeetingDoc(docs, 'b', up: true, key: _key)!.map((d) => d.id), ['a', 'b', 'c']);
      expect(moveMeetingDoc(docs, 'a', up: false, key: _key)!.map((d) => d.id), ['c', 'a', 'b']);
      expect(moveMeetingDoc(docs, 'a', up: true, key: _key), isNull);
      expect(moveMeetingDoc(docs, 'zz', up: true, key: _key), isNull);
    });

    test('next order', () {
      expect(nextMeetingDocOrder(const []), 0);
      expect(nextMeetingDocOrder(const [0, 4, null]), 5);
    });
  });

  group('attendance helpers', () {
    test('flat present only when every member is present', () {
      expect(isFlatMarkedPresent(const [], const {}), isFalse);
      expect(isFlatMarkedPresent(const ['m1', 'm2'], const {'m1': true, 'm2': true}), isTrue);
      expect(isFlatMarkedPresent(const ['m1', 'm2'], const {'m1': true, 'm2': false}), isFalse);
      expect(isFlatMarkedPresent(const ['m1', 'm2'], const {'m1': true}), isFalse);
    });

    test('member picker order is natural by flat then name', () {
      final rows = [('A-10', 'Zed'), ('A-2', 'Bob'), ('A-2', 'amy'), ('B-1', 'Cy')];
      rows.sort((x, y) => compareMemberPick(x.$1, x.$2, y.$1, y.$2));
      expect(rows.map((r) => '${r.$1}/${r.$2}'), ['A-2/amy', 'A-2/Bob', 'A-10/Zed', 'B-1/Cy']);
    });

    test('naturalCompare', () {
      expect(naturalCompare('101', '99') > 0, isTrue);
      expect(naturalCompare('A-2', 'A-10') < 0, isTrue);
      expect(naturalCompare('a', 'A') < 0, isTrue);
      expect(naturalCompare('A', 'A'), 0);
    });
  });
}
